# Brief: DEMO-1 order status export (fixture)

## Intent
Operations staff export the orders of a date range, with their current status, as a CSV file from the admin UI.

## Settled scope
- In: a server endpoint that streams the CSV; an Export button on the admin orders page; the CSV column contract.
- Out: scheduled exports, email delivery, other entities.

## Human answers
- Q: Should the CSV include the customer email? A: yes, operations needs it for follow-up (human, grilling round 2).
- Q: Is a new CSV library acceptable? A: only if streaming without one is not workable; decide by spike (human, grilling round 3).
- Q: Who releases to production? A: a human, through the normal deploy (human, grilling round 4).

## Settled terms
- "status" = the order's latest status from `src/orders/status.json`.

## Open items
- none
