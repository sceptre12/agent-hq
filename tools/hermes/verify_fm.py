"""Frontmatter / footer / body checks for verify-import (imported by verify_import.py; layout of il_describe.render)."""
import hashlib, json, re
from il_describe import DESC_MAX, FOOTER_RE, NAME_MAX
from import_learnings import NAME_RE

KEY_RE = re.compile(r"^([A-Za-z0-9_-]+):")
ORIGIN_RE = re.compile(r"Origin: `([^`\n]+)@([0-9a-f]{40})`")
WANT_KEYS = ["description", "name"]


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def split_skill(raw):
    """(frontmatter text, body bytes, (origin path, sha) or None) or None. render() writes
    fm + text.rstrip("\\n") + "\\n\\n---\\n_Imported from hq..." (il_describe.py:107-109), fm ending "---\\n\\n"."""
    try:
        t = raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if not t.startswith("---\n") or "\n---\n\n" not in t:
        return None
    fm, rest = t[4:].split("\n---\n\n", 1)
    m = FOOTER_RE.search(rest)   # one footer definition: il_describe.FOOTER_RE (starts at the "\n_Imported" line)
    if m and rest[:m.start()].endswith("\n\n---"):
        o = ORIGIN_RE.search(m.group(0))
        return (fm, rest[:m.start() - 5].encode("utf-8"), (o.group(1), o.group(2)))
    return (fm, rest.encode("utf-8"), None)


def body_ok(raw, src):
    """body segment hash == source hash; the import writes text.rstrip("\\n") (il_describe.py:108)."""
    sp = split_skill(raw) if raw is not None else None
    return bool(sp) and sha256(sp[1]) == sha256(src.rstrip(b"\n"))


def check_frontmatter(exp, found, sha):
    """Problems per skill folder found: keys exactly {name, description}, valid name == folder, str description of
    1..DESC_MAX chars, no created_by, footer present with the expected path and the pinned sha."""
    bad = []
    for rel in sorted(found):
        if found[rel] is None:
            continue   # refused SKILL.md: already reported by the layout check
        sp = split_skill(found[rel])
        if not sp:
            bad.append(f"{rel}(no-frontmatter)")
            continue
        fm, _, foot = sp
        lines = fm.split("\n")
        keys = [m.group(1) if (m := KEY_RE.match(ln)) else None for ln in lines]
        if "created_by" in keys:
            bad.append(f"{rel}(created_by)")
        if None in keys or sorted(k for k in keys if k != "created_by") != WANT_KEYS:
            bad.append(f"{rel}(frontmatter-keys:{','.join(str(k) for k in keys)})")
        nm = next((ln[6:] for ln in lines if ln.startswith("name: ")), None)
        ds = next((ln[13:] for ln in lines if ln.startswith("description: ")), None)
        if nm is None or not NAME_RE.match(nm) or len(nm) > NAME_MAX:
            bad.append(f"{rel}(name-invalid)")
        elif nm != rel.split("/")[-1]:
            bad.append(f"{rel}(name!=folder)")
        if ds is None:
            bad.append(f"{rel}(no-description)")
        else:
            parsed = True
            try:
                d = json.loads(ds)
            except ValueError:   # importer always writes json.dumps(desc); Hermes would parse anything else as YAML
                parsed = False
                bad.append(f"{rel}(description-not-json)")
            if not parsed:
                pass
            elif not isinstance(d, str):   # a real JSON null lands here: description-type:NoneType
                bad.append(f"{rel}(description-type:{type(d).__name__})")
            elif not d or len(d) > DESC_MAX:
                bad.append(f"{rel}(description-length)")
            elif rel in exp and ds != json.dumps(exp[rel][2]):   # the exact line render() writes for this source
                bad.append(f"{rel}(description-mismatch)")
        p = exp[rel][0] if rel in exp else None
        if not foot:
            bad.append(f"{rel}(no-footer)")
        elif p is not None and foot[0] != p:
            bad.append(f"{rel}(footer-path)")
        elif foot[1] != sha:
            bad.append(f"{rel}(footer-sha)")
    return bad
