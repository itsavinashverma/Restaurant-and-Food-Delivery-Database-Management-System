# Restaurant and Food Delivery Database Management System

This SQL Server project models restaurants, customers, employees, menus, orders, delivery, feedback, payments, and food-wastage reporting. The repository scripts are a coursework/demo baseline and are not a production authentication, payment, or deployment platform.

## Requirements and installation

- SQL Server 2019 or later.
- SSMS in SQLCMD mode or `sqlcmd` from the repository root. `GO` and `:r` are client directives.
- Run `Migrations/001_InitialInstall.sql` once, then optionally run `Migrations/002_SeedDemoData.sql` once. The second script rejects a non-empty database and rolls back on an error.

For example, in PowerShell:

```powershell
sqlcmd -S .\SQLEXPRESS -E -i .\Migrations\001_InitialInstall.sql
sqlcmd -S .\SQLEXPRESS -E -i .\Migrations\002_SeedDemoData.sql
```

The equivalent manual order is `DMDD_DDLScript.sql`, `DMDD_Triggers.sql`, `DMDD_Views.sql`, `DMDD_SPs.sql`, `DMDD_Permissions.sql`, then `DMDD_DML.sql`. Install views and procedures before the seed because the seed calls the transactional order and delivery procedures. Do not run the baseline DDL against a populated legacy database; see [Migrations/README.md](Migrations/README.md).

The install creates `DMDDFinalProjectDB` only when it does not exist. It never drops a database or table. `dbo.SchemaVersion` records version 1. Future schema edits belong in numbered migrations; seed data remains separate.

## Model decisions

- A customer can use both dine-in and delivery. `Orders.ServiceType` records the channel for each order.
- Waiter assignment belongs to `DineInOrders`, so each visit can have its own waiter.
- Couriers are a shared platform fleet and may serve any restaurant. `Delivery` has one row per order and the restaurant is derived through `Orders`.
- Menu item codes are unique within a restaurant. Every order line stores the menu price accepted at order creation; a later menu price change does not change a historical bill.
- Order totals use exact decimal values. The total is calculated from the saved line prices, an explicit tax rate, and a nonnegative tip, with tax rounded to cents. No jurisdictional tax rate is configured in this demo; pass the applicable rate explicitly. The seed uses zero tax and zero tip because it has no historical tax/payment evidence.
- Order processing follows Pending → Preparing → Ready → In Transit → Fulfilled for delivery, and Pending → Preparing → Ready → Fulfilled for dine-in. Cancellation is allowed before dispatch. Status changes are recorded in `OrderStatusHistory`.
- Parent deletion is restricted by foreign keys. Restaurants, customers, and employees have `IsActive` flags for soft deactivation; orders and feedback are retained.
- Staff IDs are external HR identifiers. Restaurant, customer, and menu IDs are seeded explicitly only in the empty demo database. Order IDs come from a SQL Server sequence and are captured through output parameters.
- ZIP codes and phone numbers use a US-only sample format. An international deployment should store country with postal code and normalize phone numbers in its application layer.

## Business procedures

- `dbo.usp_CalculateAndDisplayFoodWastageByRestaurants` returns daily, monthly, half-yearly, or yearly totals and averages for an inclusive date range, plus the number of measured days. A known restaurant with no measurements returns no period rows; a measured zero remains a zero.
- `dbo.usp_CreateOrder` creates an order and its lines in one transaction, validates restaurant/menu availability, and snapshots prices. It requires a waiter for dine-in orders.
- `dbo.usp_CalculateTotalAmount` finalizes an order once. Supply `@TipAmount`, `@TaxRate`, and `@TotalAmount OUTPUT`; finalized order lines and amounts cannot be edited. Refunds and adjustments are separate payment/ledger operations.
- `dbo.usp_TopRestaurantsInArea` returns up to five distinct restaurants ranked by the mean of complete food and service ratings on a 1–5 scale, then by restaurant ID for ties. The result includes review count.
- `dbo.usp_CalculateFastestDelivery` ranks completed, valid deliveries by exact millisecond duration and returns the order, courier, and timestamps. Equal durations are resolved by order ID and courier ID.
- `dbo.usp_ListDeliveryViolations` accepts a minute threshold (default 60) and can include active overdue deliveries. A violation means elapsed time is strictly greater than the threshold; exactly 60 minutes is not late at the default.
- `dbo.usp_AssignDelivery`, `dbo.usp_StartDelivery`, and `dbo.usp_CompleteDelivery` update assignment, courier availability, timestamps, and order status through one lifecycle path. A filtered unique index prevents one courier from holding two active deliveries.

The `Payments` table stores order-specific payment attempts and validates method/status values. No payment processor or live payment credentials are included.

## Synthetic seed data

The optional seed contains 6 locations, 15 restaurants, 15 customers, 30 employees (10 per role), 47 menu items, 155 daily wastage records for restaurants 1–5 in January 2021, 15 fulfilled orders, 30 order lines, 12 completed deliveries, 3 dine-in visits, and 15 order-linked reviews. It creates 379 core rows including lookup rows and employee subtypes, before status-history entries. The wastage period is intentionally limited; reporting procedures accept other dates without fabricating observations.

Names and contact details are synthetic. Sample US phone numbers use the reserved 555-0100 through 555-0199 range. The seed has no restaurant accounts, passwords, payments, or real customer contacts. Two Spring Roll menu rows remain distinct products with separate menu codes because the source supplied different prices but no trustworthy variant description.

## Security notes

`RestaurantAccounts` is separate from restaurant profile data and stores an Argon2id PHC password hash, never a recoverable password. Enrollment/reset procedures accept only a precomputed hash. The application must generate and verify the hash with a vetted Argon2id library, enforce rate limits and account recovery rules, use TLS, audit authentication attempts, and protect backups. SQL Server is not the authentication service.

Run `DMDD_Permissions.sql` after installing the procedures and views. A DBA should assign only application service identities to `restaurant_app_role` and reporting service identities to `restaurant_reporting_role`. Credential enrollment, reset, and disable procedures are granted only to the separate `restaurant_account_admin_role`. These roles are not tenant-isolation boundaries: the application must authorize each restaurant action before calling a procedure, and restaurant users must not connect directly with these roles. None of these roles receive direct table grants; do not add ordinary users to `db_owner`, `db_datareader`, or `db_datawriter`.

`Encryption.sql` and `Decryption.sql` are optional demonstrations of SQL Server symmetric column encryption for one synthetic note bound to a row ID. This is not Transparent Data Encryption and is never used for password storage. For recoverable production data, a DBA must back up and protect the database master key and certificate, plan rotation, restrict key access, and secure database backups and exports.

## Views and Tableau

The SQL views expose a restaurant directory, daily wastage audit rows, lifetime wastage coverage summaries, restaurant rating averages, menu catalog, and limited order summary. The wastage summary reports the date coverage and measured-day count; it returns `NULL` total and zero measured days for a restaurant without observations.

The Tableau workbook is an optional snapshot report over restaurant, wastage, review, and customer-count data. It is not a live SQL Server dashboard and does not include order or delivery KPIs. A refresh requires the packaged, sanitized source extracts documented alongside the workbook. Compare dashboard metrics to the SQL views and procedures after changing seed data; the workbook is not part of the SQL install.

The revised design document, technical report, and dashboard report PDFs are included in the repository. `Documentation/build_project_pdfs.py` regenerates them from the current schema and snapshot data.
#   R e s t a u r a n t - a n d - F o o d - D e l i v e r y - D a t a b a s e - M a n a g e m e n t - S y s t e m 
 
 