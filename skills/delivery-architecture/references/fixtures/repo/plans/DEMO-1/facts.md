FACTS: 6 facts
measured: cat package.json -> name demo-shop, version 1.4.0, scripts test/lint/build
measured: cat src/orders/status.json -> 6 statuses: placed, paid, packed, shipped, delivered, cancelled
measured: cat src/orders/status.json -> 5 fields including customer_email
measured: ls docs/architecture -> orders.md (lists 4 statuses; last reviewed 2026-03-02)
measured: cat apps/admin/dev-server.json -> admin-ui fixed port 4300 on 127.0.0.1
measured: ls e2e playwright.config.ts -> No such file or directory (no e2e harness)
