"""Deterministic description / rendering / secret scan for import-learnings (no model, no network)."""
import hashlib, json, os, re, subprocess

NAME_MAX, DESC_MAX = 64, 1024                     # skill_manager_tool.py:108-109
# The four generic housekeeping files get a category prefix so the two READMEs, which would otherwise both become
# "readme", do not collide, and METHODOLOGY/_TEMPLATE stay recognisable (exact full-path match, case-sensitive).
# Brain default under R-q, owner may veto.
PREFIXED = {"learnings/README.md": "learnings-readme", "learnings/METHODOLOGY.md": "learnings-methodology",
            "retros/README.md": "retros-readme", "retros/_TEMPLATE.md": "retros-template"}
FOOTER_RE = re.compile(r"\n_Imported from hq\. Date: [^\n]*\. Origin: `[^`\n]+@[0-9a-f]{40}`\._\n\Z")
SECRET_RES = [re.compile(p) for p in (
    r"sk-ant-[A-Za-z0-9_-]{10,}", r"\bgh[pousr]_[A-Za-z0-9]{20,}", r"github_pat_[A-Za-z0-9_]{20,}",
    r"\bAKIA[0-9A-Z]{16}\b", r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"(?i)(token|secret|api[_-]?key|passw(or)?d)[\"']?\s*[=:]\s*[\"']?[A-Za-z0-9+/_=-]{24,}")]


def has_secret(text):
    return any(r.search(text) for r in SECRET_RES)


GIT_ENV_DROP = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES")


def git(repo, *args):
    env = {k: v for k, v in os.environ.items() if k not in GIT_ENV_DROP}   # --repo decides, not the caller's env
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, env=env)
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout


def skill_name(path):
    if path in PREFIXED:
        return PREFIXED[path]
    stem = os.path.splitext(os.path.basename(path))[0].lower()
    name = re.sub(r"-+", "-", re.sub(r"[^a-z0-9._-]", "-", stem)).strip("-._")
    if len(name) > NAME_MAX:
        name = name[:NAME_MAX - 9].rstrip("-._") + "-" + hashlib.sha1(path.encode()).hexdigest()[:8]
    return name


def category(path):
    parts = path.split("/")
    return parts[1] if parts[0] == "learnings" and len(parts) > 2 else parts[0]


def clean(s):
    """Strip markdown noise. Underscores inside identifiers (skill_manager_tool, HERMES_HOME) are kept."""
    s = re.sub(r"<!--.*?-->", "", s)
    s = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = re.sub(r"[`*]+", "", s)
    s = re.sub(r"(?<![A-Za-z0-9])_+|_+(?![A-Za-z0-9])", "", s)
    s = re.sub(r"<[^>]+>", "", s)
    return re.sub(r"\s+", " ", s).strip(" -|>#")


def cut(s, n):
    """At most n chars, ending on a sentence or word boundary."""
    if len(s) <= n:
        return s
    k = s.rfind(". ", 0, n)
    if k > n // 2:
        return s[:k + 1]
    return s[:max(n - 3, 0)].rsplit(" ", 1)[0].rstrip(",;:-") + "..."


def file_date(repo, sha, path, text):
    for pat, src in ((r"<!--\s*(\d{4}-\d{2}-\d{2})\s*-->", text.split("\n", 1)[0]),
                     (r"^(\d{4}-\d{2}-\d{2})", os.path.basename(path))):
        m = re.search(pat, src)
        if m:
            return m.group(1)
    return git(repo, "log", "-1", "--format=%cs", sha, "--", path).decode().strip() or "unknown"


def describe(path, text, fdate):
    """Layout: Title. [summary] [Sections: ...] Use when the task touches: X. (Kind, category, date).
    Title, Use-when and trailer are placed first in the budget; summary and Sections get what is left, so a long
    file never loses the trailer. Hermes cuts the prompt-index entry to 57 chars + '...' (agent/skill_utils.py:
    822,831-834), hence title first. Heuristic, no model."""
    heads, paras, cur, fence = [], [], [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if re.match(r"^#{1,6}\s", line):
            heads.append(clean(line))
            cur = [] if not cur else (paras.append(" ".join(cur)) or [])
        elif not line.strip():
            if cur:
                paras.append(" ".join(cur))
            cur = []
        elif not re.match(r"^\s*\|", line):
            cur.append(clean(line))
    if cur:
        paras.append(" ".join(cur))
    title = cut(heads[0] if heads else os.path.splitext(os.path.basename(path))[0].replace("-", " "), 220).rstrip(".")
    topics = "; ".join(h for h in heads[1:9] if h)
    head = f"{title}."
    when = f" Use when the task touches: {cut(topics or title, 220).rstrip('.')}."
    trail = f" ({'Retro' if path.startswith('retros/') else 'Learning'}, {category(path)}, {fdate})"
    left = DESC_MAX - 8 - len(head + when + trail)
    summary = cut(" ".join(p for p in paras if p)[:1500], min(480, left)) if left > 60 else ""
    left -= len(summary) + 1
    sections = f" Sections: {cut(topics, left - 12).rstrip('.')}." if topics and left > 60 else ""
    d = re.sub(r"\s+", " ", head + (f" {summary}" if summary else "") + sections + when + trail).strip()
    assert len(d) <= DESC_MAX, (path, len(d))
    return d


def render(repo, sha, path, text):
    fd = file_date(repo, sha, path, text)
    desc = describe(path, text, fd)
    fm = f"---\nname: {skill_name(path)}\ndescription: {json.dumps(desc)}\n---\n\n"
    foot = f"\n\n---\n_Imported from hq. Date: {fd}. Origin: `{path}@{sha}`._\n"
    return fm + text.rstrip("\n") + foot, desc
