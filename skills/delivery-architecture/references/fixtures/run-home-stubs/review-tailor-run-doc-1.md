RUNG: 2b seats: 7
correctness	review-seat	finds design-versus-brief drift the others cannot
contract	review-seat	finds CSV column and endpoint contract conflicts
security	review-seat	SECURITY_AUDIT=guidance; finds personal-data exposure in the export
test-adequacy	review-seat	finds AC without a test row and the e2e gap handling
release	review-seat	finds agent/human step errors in release-plan.md
fact-remeasurer	review-seat	re-measures facts.md rows cited by the doc
cold-implementer	review-seat	finds drafts a unit agent could not execute

mechanism: review-7-panel
tiers: seats verify, synthesizer verify, fixer design, fix-verifier verify, pre-round mechanical
budget: seats 10 min, synthesizer 10 min, fixer 20 min, verifier 10 min
dispatch: 11 per round (7 seats, synthesizer, fixer, fix-verifier, pre-round check); D57 freeze trigger: two consecutive rounds with no change to the core sections; G48 pre-round check before round 1 and after every fix
