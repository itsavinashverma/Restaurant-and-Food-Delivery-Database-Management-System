# Restaurant & Food Delivery DBMS — Design and Code Review Checklist


## Implementation status (25 November 2026)

- `[x]` means the finding was corrected in code or documentation, or its requested behavior was implemented.
- `[~]` means the item is an explicit scope decision, an optional seed scenario, or awaits runtime/performance/visual validation. The notes below identify why it remains.
- `[ ]` means work or runtime validation remains open.

The SQL schema, triggers, procedures, views, least-privilege permissions, seed data, migration entry points, Tableau snapshot package, README, and three PDFs were revised. The seed now contains 379 core rows plus 72 status-history rows; the 15 orders are complete for dashboard rating metrics. Synthetic phone numbers use the reserved 555 range. The Tableau package was rebuilt with four sanitized CSVs and a Hyper extract containing 155 wastage rows, 15 restaurants, 15 customers, and 15 reviews. Its workbook XML has no user-specific path or contact fields. All eight revised PDF pages were rendered and visually inspected.

Intentional scope choices remain at `[~]` items 3.4, 6.7, 7.15, 8.3, 18.13, 18.14, 18.16, and 19.12: US-only demo formats, one employer restaurant per staff member, shared couriers, no menu modifiers, focused fulfilled-order seed data, limited wastage coverage, and no minimum review-count rule. P3 performance items 11.7 and 15.1-15.6 need representative workloads. Tableau visual/reconciliation items 22.6 and 22.9, and the SQL Server 2019 baseline item 23.2, remain unverified in their target applications.

SQL Server services were stopped, so no SQL deployment, transaction/concurrency, permission, restore, or query-plan checks were run. Tableau Desktop was unavailable for an open/refresh check. Item 23.4 remains open because no automated SQL test harness was added; the unnumbered checks in Sections 16 and 25 are runtime validation work and were not run.

## Scope and priority

Expanded full-repository source review: all seven SQL scripts, README, and Tableau workbook XML. Sections 1–17 preserve the previous checklist; Sections 18–25 add newly audited seed data, procedures, views, encryption/decryption, dashboard, deployment and regression checks. This is a static review, not a tested migration or a complete production security audit. Sample scenarios are illustrative unless explicitly identified as repository seed records. The implementation has now been revised. The numbered findings below describe the original defects and include current status markers.

- **P0 — Critical:** incorrect records, broken setup, serious security or transaction integrity issues.
- **P1 — High:** incorrect business behaviour, financial inaccuracies or missing important constraints.
- **P2 — Medium:** maintainability, flexibility or operational improvements.
- **P3 — Evaluate:** performance/design trade-offs requiring measurement or business requirements.

The numbered issue text and diagnostic SQL preserve the original pre-revision review for traceability; line references and baseline counts refer to that version. Status markers now show whether each finding was corrected, intentionally retained, or remains open. Priorities are recommendations, not measured production severity.

## 1. Database setup and general schema

- [x] **1.1 — P0: Database creation is commented out.** `DMDD_DDLScript.sql` starts with `USE DMDDFinalProjectDB`, but `CREATE DATABASE` is commented out. A fresh SQL Server instance cannot run the script as-is. **Fix:** create the database explicitly if it does not exist, then select it in a separate batch. Avoid destructive `DROP DATABASE` commands in routine setup.
- [x] **1.2 — P0: Missing batch separators in trigger and procedure scripts.** SQL Server requires `CREATE TRIGGER` and `CREATE PROCEDURE` to start their respective batches. The trigger script contains a `USE` followed by two definitions without `GO`; the procedure script similarly mixes definitions and execution statements. **Fix:** separate database selection, each definition, and test calls using `GO` in SSMS/sqlcmd, or submit separate batches through a client driver. `GO` is a client batch separator, not a T-SQL statement.
- [x] **1.3 — P2: Setup instructions are incomplete.** README lists DDL, triggers, DML and encryption, but omits explicit installation of views and stored procedures. **Fix:** document a reproducible execution order: create database → DDL → triggers → sample DML → views/procedures → encryption demonstration → optional decryption/dashboard. Document prerequisites and which scripts are optional.
- [x] **1.4 — P2: Misspelled table and constraint names.** `RESTUARANTSWASTAGE`, `DeliveryEmployeeAVALABILITY_CHK` and `Feedback_FoodRatingRating_Index` are examples. **Fix:** standardize naming; rename only through a migration that also updates all dependent queries and reports.
- [x] **1.5 — P1: Important columns have no explicit nullability.** Many names, prices, ratings, quantities, foreign keys and status fields omit `NOT NULL`. Under usual nullable-column settings, NULL is permitted; actual default nullability can depend on SQL Server settings. **Fix:** explicitly declare `NULL` or `NOT NULL` according to business requirements. Clean existing data before adding constraints.
- [x] **1.6 — P2: Short string lengths and limited text representation.** Examples include customer/employee names limited to 20 characters, street addresses to 30, and restaurant names to 30. **Impact:** realistic data may be rejected or truncated by upstream applications. **Fix:** choose lengths from requirements, and consider `NVARCHAR` or an appropriate UTF-8 collation for international names.

## 2. Missing foreign keys and relationship integrity

The schema declares 18 foreign keys. Four additional relationships are intended but not enforced. Triggers alone do not replace foreign keys.

- [x] **2.1 — P0: DELIVERYEMPLOYEES → EMPLOYEES is missing.** A delivery employee can exist without a parent employee; fastest-delivery joins may silently omit such records. Add `FOREIGN KEY (DeliveryEmployeeID) REFERENCES EMPLOYEES(EmployeeID)`.
- [x] **2.2 — P0: DINEINCUSTOMERS → CUSTOMERS is missing.** A dine-in record can reference a nonexistent customer. Add `FOREIGN KEY (CustomerID) REFERENCES CUSTOMERS(CustomerID)`.
- [x] **2.3 — P0: DELIVERYCUSTOMERS → CUSTOMERS is missing.** Delivery customer records can become orphaned. Add the corresponding foreign key on `CustomerID`.
- [x] **2.4 — P0: FEEDBACK → RESTAURANTS is missing.** Feedback can reference nonexistent restaurants. Add `FOREIGN KEY (RestaurantID) REFERENCES RESTAURANTS(RestaurantID)`.
- [x] **2.5 — P1: Deletion lifecycle is undefined.** Existing foreign keys generally reject parent deletion when child records exist; missing foreign keys allow orphans. **Fix:** choose restrict, soft delete, archival or carefully scoped cascading actions per relationship. Do not blindly cascade deletion of orders, payments or historical feedback.

Example migration (after checking existing orphaned records):

```sql
ALTER TABLE dbo.DELIVERYEMPLOYEES WITH CHECK
ADD CONSTRAINT FK_DeliveryEmployees_Employees
FOREIGN KEY (DeliveryEmployeeID) REFERENCES dbo.EMPLOYEES(EmployeeID);

ALTER TABLE dbo.DINEINCUSTOMERS WITH CHECK
ADD CONSTRAINT FK_DineInCustomers_Customers
FOREIGN KEY (CustomerID) REFERENCES dbo.CUSTOMERS(CustomerID);

ALTER TABLE dbo.DELIVERYCUSTOMERS WITH CHECK
ADD CONSTRAINT FK_DeliveryCustomers_Customers
FOREIGN KEY (CustomerID) REFERENCES dbo.CUSTOMERS(CustomerID);

ALTER TABLE dbo.FEEDBACK WITH CHECK
ADD CONSTRAINT FK_Feedback_Restaurants
FOREIGN KEY (RestaurantID) REFERENCES dbo.RESTAURANTS(RestaurantID);
```

## 3. LOCATIONS and contact information

- [x] **3.1 — P1: ZIP code CHECK validates length only.** `CHECK (LEN(ZipCode) = 5)` accepts `ABCDE`. **Fix:** require five ASCII digits (use a suitable binary collation for strict character validation). Retain a string type to preserve leading zeros such as `02215`.
- [x] **3.2 — P2: City can be NULL.** If every location must have a city, use `City ... NOT NULL` and reject empty names.
- [x] **3.3 — P1: Phone number CHECK validates length only.** Applies to RESTAURANTS, CUSTOMERS and EMPLOYEES. A ten-letter value can pass; NULL can pass if permitted. **Fix:** validate requiredness and format. If international numbers are supported, use a longer string and application-level phone normalization rather than enforcing exactly ten digits universally.
- [~] **3.4 — P3: Five-character ZIP design is US-specific.** Appropriate for the sample Boston-based dataset, but not for an international platform. **Fix if required:** model country and postal code together. `CHAR(5)` is also reasonable for fixed-width US ZIPs; `VARCHAR(5)` is not itself a bug.

## 4. RESTAURANTS

- [x] **4.1 — P1: Restaurant name and location may be missing.** A restaurant without a name or ZIP may be unusable in search/reporting. **Fix:** add explicit required constraints where appropriate.
- [x] **4.2 — P1: Username uniqueness is not enforced.** Duplicate usernames can make authentication ambiguous. **Fix:** add a unique constraint/index and define case-sensitivity and NULL policy; enforce required usernames for active accounts.
- [x] **4.3 — P1: Password design is unsuitable for real authentication.** Passwords are reversibly encrypted rather than hashed. See Section 12 for details.

## 5. RESTUARANTSWASTAGE

- [x] **5.1 — P1: Negative wastage accepted.** `DECIMAL(5,2)` permits negative values. Add `CHECK (WastageQuantityInPounds >= 0)`.
- [x] **5.2 — P1: NULL wastage accepted under ordinary settings.** `SUM` and `AVG` ignore NULL, potentially hiding missing observations. **Fix:** use `NOT NULL` for submitted measurements; distinguish a measured zero from an unreported day.
- [x] **5.3 — P3: Wastage precision and daily granularity may be restrictive.** `DECIMAL(5,2)` caps the magnitude at 999.99 pounds and the composite key allows one record per restaurant per day. These are legitimate design choices for daily totals, not inherent bugs. If multiple measurements per day or larger amounts are required, change precision or introduce measurement records with a timestamp and aggregate by day.

Suggested column definition: `WastageQuantityInPounds DECIMAL(5,2) NOT NULL CHECK (WastageQuantityInPounds >= 0)`.

## 6. CUSTOMERS, EMPLOYEES and subtype design

- [x] **6.1 — P1: Nullable discriminator attributes.** `CustomerType IN ('DI','DC')` and `EmployeeType IN ('W','C','D')` reject invalid non-NULL values but permit UNKNOWN when the field is NULL. The trigger then creates no subtype. **Fix:** add `NOT NULL` if classification is mandatory.
- [x] **6.2 — P1: Customer is permanently classified as dine-in or delivery.** Real customers may use both channels. **Fix:** store service type on the order or visit rather than treating it as a permanent customer identity; alternatively model overlapping roles if required.
- [x] **6.3 — P1: Subtype classification is not fully enforced.** A chef can be manually inserted into WAITERS because its FK checks only parent existence. The same employee can exist in multiple subtype tables despite a single discriminator. **Fix:** use discriminator-aware constraints or a controlled transactional write path; restrict direct writes where necessary. Adding the missing FKs alone is insufficient.
- [x] **6.4 — P1: Employee salary uses FLOAT.** Binary floating-point is approximate and unsuitable for exact currency calculations. **Fix:** use an appropriately sized `DECIMAL(12,2)` or another exact monetary representation.
- [x] **6.5 — P1: Negative or missing salary can be accepted.** Add a nonnegative CHECK and explicit nullability based on employee compensation rules.
- [x] **6.6 — P2: EmployeeID and OrderID are manually supplied.** Not inherently incorrect, but concurrent applications need a reliable unique-ID allocation strategy. **Fix:** consider IDENTITY or SEQUENCE; retain externally assigned IDs if business requirements demand them. IDENTITY alone does not guarantee uniqueness or gap-free numbering.
- [~] **6.7 — P3: One employee can reference only one restaurant.** Appropriate for single-employer staffing, but not for shared staff or multi-branch work. If required, introduce an employee-restaurant junction table with assignment details.
- [x] **6.8 — P2: Availability represented as VARCHAR(3).** `Yes`/`No` is readable but less compact and allows NULL unless prohibited. For strictly binary availability, consider `BIT NOT NULL DEFAULT 1`. For richer states (busy, offline, on leave), use a status model instead.

## 7. MENUITEMS, ORDERS, OrderStatuses and ORDERLINE

- [x] **7.1 — P0: Menu price loses decimal places.** SQL Server `Price DECIMAL` defaults to `DECIMAL(18,0)`. A price like 12.75 can be rounded to 13. **Fix:** use `DECIMAL(10,2)` or appropriate currency precision. Previously lost fractional values must be recovered from original data, not inferred.
- [x] **7.2 — P1: Menu price can be negative or NULL.** Add `NOT NULL CHECK (Price >= 0)`; define whether zero-priced items are permitted.
- [x] **7.3 — P1: OrderAmount uses FLOAT.** Use exact decimal currency and explicit rounding rules to avoid financial precision errors.
- [x] **7.4 — P0: Historical purchase-time price is not stored.** ORDERLINE stores quantity but no unit price. The billing procedure joins current MENUITEMS prices. If Biryani changes from $12 to $15, recalculating a past two-unit order changes $24 into $30. **Fix:** snapshot `UnitPrice` on ORDERLINE when the order is accepted; use that snapshot for historical calculation. Add tax/discount snapshots where applicable. Do not backfill old prices blindly from current prices.
- [x] **7.5 — P0: Cross-restaurant menu items are allowed in an order.** ORDERS may reference restaurant 1 while an ORDERLINE references a menu item from restaurant 2. Both existing FKs pass independently. **Fix:** use compatible composite FKs (with appropriate unique referenced keys and non-null restaurant IDs) or transactional validation that checks all items belong to the order's restaurant.
- [x] **7.6 — P1: Invalid quantities accepted.** ORDERLINE permits zero, negative and potentially NULL quantities. **Fix:** `OrderQuantity INT NOT NULL CHECK (OrderQuantity > 0)`.
- [x] **7.7 — P1: Unavailable items can still be ordered.** MENUITEMS has an availability flag, but ORDERLINE does not consult it. **Fix:** validate availability in the order-creation transaction; prevent races with concurrent availability changes. Do not invalidate historical orders when items later become unavailable.
- [x] **7.8 — P1: Orders can lack customer, restaurant or status.** Foreign keys do not reject NULL unless NOT NULL is specified. **Fix:** require these relationships if every order must have them; define initial status and order timestamp explicitly.
- [x] **7.9 — P1: Orders can exist with no order lines.** A parent FK cannot enforce a minimum child count. **Fix:** create orders and lines atomically through a controlled procedure/application transaction; permit empty drafts only if intentionally supported.
- [x] **7.10 — P0: Multi-step order creation lacks demonstrated atomic business operation.** Creating order header, lines, and total separately can leave incomplete records on failure. **Fix:** use a transaction, `SET XACT_ABORT ON`, `TRY...CATCH`, rollback and `THROW`; define concurrency rules. This is an architectural improvement, not a claim that every existing INSERT fails.
- [x] **7.11 — P1: Stored OrderAmount can drift from line items.** It is denormalized for quick retrieval/final billing, but no mechanism guarantees synchronization after line edits. **Fix:** define whether it is an immutable finalized total or a recalculated draft total, and update it transactionally from price snapshots, tips, taxes and discounts.
- [x] **7.12 — P1: No valid order-status transition enforcement.** A valid status ID does not imply a valid transition; Delivered could become Preparing. **Fix:** implement a state machine and allowed transitions in a controlled write path, optionally with status history.
- [x] **7.13 — P2: Lookup descriptions can be NULL or duplicated.** Consider NOT NULL and UNIQUE on `OrderStatusDescription` if descriptions are intended as unique labels.
- [x] **7.14 — P2: DATETIME is a legacy type.** `DATETIME2` offers wider date range and configurable precision. Define time zone strategy (e.g., UTC or DATETIMEOFFSET). This is modernization rather than a current correctness failure.
- [~] **7.15 — P3: Composite ORDERLINE key prevents separate lines for the same item.** Correct for aggregating identical units, but insufficient if two instances have different customizations or prices. If required, add an OrderLineID and model variants/modifiers. Do not change the key without a real requirement.

## 8. DELIVERY

- [x] **8.1 — P0: Delivery restaurant may not match order restaurant.** DELIVERY references OrderID and RestaurantID independently. A valid order can be paired with a different valid restaurant. **Fix:** remove the redundant restaurant field and derive it from ORDERS, or enforce a composite FK to the matching order/restaurant pair.
- [x] **8.2 — P1: Composite delivery PK permits multiple restaurants for the same order.** `(OrderID, RestaurantID)` does not enforce one delivery per order. **Fix:** if one delivery per order is the business rule, use OrderID as the key/unique constraint. If multiple delivery attempts are needed, use DeliveryID and explicit attempt semantics.
- [~] **8.3 — P1: Delivery employee may be assigned across inconsistent restaurants.** Nothing ensures the employee's restaurant matches the order restaurant. **Fix:** enforce assignment consistency if couriers are restaurant-specific; shared delivery fleets may intentionally allow this.
- [x] **8.4 — P1: End time can precede start time.** Negative durations can be generated and even win the fastest-delivery ranking. Add a constraint requiring a valid start whenever an end is recorded and `DeliveryEndTime >= DeliveryStartTime`.
- [x] **8.5 — P1: Delivery availability is not automatically maintained.** The employee trigger initializes availability to Yes, but there is no demonstrated automatic update on assignment/completion. **Fix:** manage assignment and release transactionally; prevent double allocation if capacity is one active delivery per courier.
- [x] **8.6 — P2: DATEDIFF(minute) counts minute boundaries, not exact elapsed minutes.** Example: 14:00:59 to 14:01:00 gives 1 despite only one second elapsed. **Fix:** for precise SLA calculation, use seconds or compare end time against `DATEADD(minute, threshold, start)`; preserve the display column if useful.
- [x] **8.7 — P1: Delivery completion fields are not tied to order status.** A delivered order may have no end timestamp, or a pending order may have a completed delivery. **Fix:** define lifecycle invariants and update delivery/order status together. NULL end times are valid for ongoing deliveries, so do not simply make all timestamps NOT NULL.

## 9. DINEINCUSTOMERS and DELIVERYCUSTOMERS

- [x] **9.1 — P1: Waiter is assigned to a customer instead of a visit/order.** Repeat visits can have different waiters. **Fix:** put waiter assignment on a dine-in visit/order record or service-assignment table.
- [x] **9.2 — P1: Payment method stored at customer level.** A customer may pay cash on one order and by card on another. **Fix:** introduce an order-linked PAYMENTS table with payment ID, order ID, method, amount, status and optional attempt/refund tracking. A customer-level preferred method can remain separate.
- [x] **9.3 — P1: PaymentMode has no allowed-value validation.** Arbitrary strings and potentially NULL are accepted. **Fix:** use a lookup table or CHECK constraint and explicit requiredness when payment is recorded.
- [x] **9.4 — P2: Customer trigger hardcodes Cash.** This assumes a payment method before the customer actually pays. **Fix:** record an explicit chosen payment method at transaction time, or treat the default only as a preference.

## 10. FEEDBACK

- [x] **10.1 — P1: Ratings can be NULL.** CHECK constraints only reject invalid non-NULL ratings. NULLs can disappear from average calculations. **Fix:** require ratings if mandatory, or define how partially completed reviews are scored.
- [x] **10.2 — P1: Anyone with an existing CustomerID can review a restaurant without ordering.** No reference to an eligible completed order is required. **Fix:** link reviews to eligible completed orders and validate reviewer identity.
- [x] **10.3 — P3: Only one review per customer per restaurant.** Composite PK prevents repeated reviews. Correct if the product intends one editable review per restaurant; otherwise link to OrderID and enforce one review per eligible order.
- [x] **10.4 — P2: No feedback timestamp.** Cannot analyse ratings over time or distinguish recent and old reviews. **Fix:** add CreatedAt and optionally UpdatedAt with a consistent time zone policy.

## 11. Triggers — DMDD_Triggers.sql

- [x] **11.1 — P0: Multi-row insertion bug in BOTH triggers.** SQL Server fires a DML trigger once per statement. `INSERTED` can contain many rows, while scalar variables hold only one value. The two independent SELECT assignments are not guaranteed to pick the same row. **Impact:** missing or incorrectly classified subtype records. **Fix:** use set-based `INSERT INTO ... SELECT ... FROM INSERTED WHERE ...` statements for each subtype.
- [x] **11.2 — P1: Only INSERT events handled.** Updating EmployeeType or CustomerType leaves old subtype records unchanged. **Fix:** define whether type changes are permitted; if so, handle transitions atomically using INSERTED and DELETED or a dedicated procedure. Preserve dependent history.
- [x] **11.3 — P1: No defined subtype deletion handling.** Missing foreign keys allow orphans, while existing ones can block parent deletion. **Fix:** add missing FKs and define controlled deletion/soft-deletion policies; a DELETE trigger is not automatically necessary.
- [x] **11.4 — P1: NULL discriminator silently bypasses all IF branches.** Fix with explicit NOT NULL and business validation, or model an intentional unclassified state.
- [x] **11.5 — P2: INSERT statements omit target column lists.** `INSERT INTO WAITERS VALUES (...)` relies on table column order and can break after schema changes. **Fix:** always specify target columns.
- [x] **11.6 — P2: Trigger automation can be bypassed by direct subtype writes.** Use permissions, appropriate constraints and controlled writes; do not rely on hidden automation as the sole enforcement mechanism.
- [~] **11.7 — P3: Trigger overhead and debugging complexity.** Triggers execute inside the triggering transaction. Extra writes add latency and errors can roll back the original statement. **Fix:** keep trigger logic small and set-based, test batch operations, and measure overhead before optimizing.

### Proposed set-based trigger replacements

These are illustrative patches for the existing subtype insert logic, not a complete lifecycle enforcement solution.

```sql
CREATE OR ALTER TRIGGER dbo.Employees_INSERT
ON dbo.EMPLOYEES
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.WAITERS (WaiterID, Designation)
        SELECT EmployeeID, NULL FROM inserted WHERE EmployeeType = 'W';
    INSERT INTO dbo.CHEFS (ChefID, Designation)
        SELECT EmployeeID, NULL FROM inserted WHERE EmployeeType = 'C';
    INSERT INTO dbo.DELIVERYEMPLOYEES
        (DeliveryEmployeeID, IsDeliveryPartnerAvailable)
        SELECT EmployeeID, 'Yes' FROM inserted WHERE EmployeeType = 'D';
END;
GO

CREATE OR ALTER TRIGGER dbo.Customer_INSERT
ON dbo.CUSTOMERS
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.DINEINCUSTOMERS (CustomerID, WaiterID)
        SELECT CustomerID, NULL FROM inserted WHERE CustomerType = 'DI';
    INSERT INTO dbo.DELIVERYCUSTOMERS (CustomerID, PaymentMode)
        SELECT CustomerID, 'Cash' FROM inserted WHERE CustomerType = 'DC';
END;
GO
```

## 12. Encryption and authentication — Encryption.sql / Decryption.sql

- [x] **12.1 — P0: Reversible encryption for login passwords.** AES-256 is suitable for encrypting data that must be recovered, not the preferred storage method for authentication passwords. **Fix:** hash each password with a unique salt using a vetted password-hashing implementation (e.g., Argon2id, bcrypt or PBKDF2 as appropriate). Verify hashes rather than decrypt passwords.
- [x] **12.2 — P0: Shared sample password assigned to every restaurant.** Encryption.sql updates all restaurant accounts to the same demonstration password. This is unsafe outside a disposable demo. **Fix:** remove shared credentials, require unique account setup/reset, and never run the demo update against real accounts.
- [x] **12.3 — P0: Database master-key password is hardcoded in the script.** A repository-visible secret is not a safe key-management strategy. **Fix:** use secure secret injection and appropriate key backup/rotation and access controls. Do not publish actual secrets.
- [x] **12.4 — P2: Column-level encryption is mislabeled as TDE.** The script uses `EncryptByKey` with a symmetric key protected by a certificate. Transparent Data Encryption protects database files at rest and is a different feature. **Fix:** describe the actual feature accurately in documentation/interviews.
- [x] **12.5 — P1: Account credential initialization is a mass UPDATE.** Running the encryption script again can reset existing usernames and passwords; key creation may also fail if objects already exist. **Fix:** separate demo seeding from migrations, make deployment repeatable and scope account initialization to intended records.

## 13. Stored procedures — DMDD_SPs.sql

These were identified in the initial repository overview. Section 19 adds findings from the subsequent complete stored procedure source review.

- [x] **13.1 — P1: Food wastage procedure does not implement advertised time windows.** `sp_CalculateAndDisplayFoodWastageByRestaurants` filters a restaurant ID and calculates AVG over available records. README describes daily/monthly/half-yearly/annual analysis. **Fix:** accept start/end dates or reporting periods, define average versus total, and group by the requested period. `TOP 5` is redundant when filtering a unique restaurant ID.
- [x] **13.2 — P1: Bill procedure omits taxes described in README.** `sp_CalculateTotalAmount` computes `SUM(Price * OrderQuantity) + @tips` only. **Fix:** either correct documentation or implement explicit tax rates, tax basis, discounts and rounding. Use purchase-time prices as in 7.4.
- [x] **13.3 — P1: Billing input/output variables use FLOAT.** `@tips`, `@TotalAmount` and OrderAmount are approximate. **Fix:** use consistent exact numeric types across parameters, calculations and storage.
- [x] **13.4 — P1: Missing order or empty order can yield NULL total.** SUM returns NULL when no qualifying rows exist; nonexistent OrderID results in no update. NULL tips also propagate. Negative tips are not rejected. **Fix:** validate order existence, required lines and tip policy; return a meaningful error instead of silently storing NULL. Use COALESCE only when zero is semantically correct.
- [x] **13.5 — P1: Restaurant ranking does not calculate restaurant averages.** `TopRestaurantsinAnArea` sorts individual feedback rows by FoodRating + ServiceRating and takes TOP 5. A single restaurant can appear repeatedly, crowding out others. **Fix:** group by RestaurantID and calculate average score using decimal arithmetic; decide handling of unrated restaurants and add a deterministic tie-breaker.
- [x] **13.6 — P1: Fastest-delivery query may select unfinished or invalid deliveries.** `sp_CalculateFastestDelivery` orders ascending by DATEDIFF without excluding NULL or negative values; SQL Server sorts NULL first in ascending order. **Fix:** restrict to completed valid deliveries, sort by duration and deterministic key, optionally report all ties.
- [x] **13.7 — P1: Delivery violation threshold is hardcoded.** `sp_ListDeliveryViolations` uses `DeliveryTimeInMinutes > 60` even though README describes a configurable threshold. **Fix:** accept a positive threshold parameter with a default of 60, and define exact boundary behaviour. For exact elapsed SLA, use timestamp comparison rather than minute-boundary counts.
- [x] **13.8 — P2: In-progress overdue deliveries are not reported.** NULL durations are excluded by `> 60`. This is fine if only completed violations are intended; if operations need active alerts, separately compare current time with start time for unfinished deliveries.

### Example corrected restaurant-ranking query

```sql
SELECT TOP (5)
    r.RestaurantID, r.RestaurantName,
    AVG((f.FoodRating + f.ServiceRating) / 2.0) AS AverageRating
FROM dbo.RESTAURANTS AS r
JOIN dbo.FEEDBACK AS f ON f.RestaurantID = r.RestaurantID
WHERE r.ZipCode = @zipcode
  AND f.FoodRating IS NOT NULL
  AND f.ServiceRating IS NOT NULL
GROUP BY r.RestaurantID, r.RestaurantName
ORDER BY AverageRating DESC, r.RestaurantID ASC;
```

This example intentionally excludes restaurants without complete ratings; a different product policy may be appropriate.

## 14. Views — DMDD_Views.sql

- [x] **14.1 — P2: Restaurant_Incity hardcodes Boston.** Useful for a Boston-specific report, but not reusable for arbitrary cities. **Fix if needed:** expose an all-city view and filter externally, or use a parameterized stored procedure/inline table-valued function. A standard SQL Server view cannot accept parameters.
- [x] **14.2 — P1: Restaurant_Wastage groups by restaurant name only.** Two separate restaurants with the same name can be merged into one total. **Fix:** group by RestaurantID and RestaurantName.
- [x] **14.3 — P2: Restaurant_Wastage excludes restaurants without wastage records.** INNER JOIN omits unreported restaurants. If auditors need coverage, use LEFT JOIN and expose observation count. Distinguish no observations from actual zero wastage.
- [x] **14.4 — P2: View script lacks explicit database selection.** It depends on the current database context. **Fix:** document the required context or add `USE DMDDFinalProjectDB; GO` before the view batches.

## 15. Indexing and performance

These are hypotheses to test, not proven bottlenecks. More indexes are not automatically better.

- [~] **15.1 — P3: CustomerTypeIndex has low cardinality.** Only DI/DC non-NULL values. A query retrieving half the table may prefer a scan. **Fix:** compare actual execution plans and logical reads; retain if useful for selective, covering or skewed workloads.
- [~] **15.2 — P3: EmployeeTypeIndex has low cardinality.** Only W/C/D non-NULL values. Apply the same measurement-based approach.
- [~] **15.3 — P3: FoodRating and ServiceRating indexes have low cardinality.** Rating values 1–5 may not provide selective predicates. Evaluate whether they help actual queries before removing or replacing them.
- [~] **15.4 — P3: Existing indexes may not match common joins/aggregations.** Candidate: `FEEDBACK(RestaurantID) INCLUDE (FoodRating, ServiceRating)` for restaurant-wise ratings. Consider ORDERS(CustomerID), ORDERS(RestaurantID) and ORDERLINE(MenuItemID) based on workloads; SQL Server does not automatically index every foreign key. Measure write overhead, existing key prefixes and actual query plans before creating indexes.
- [~] **15.5 — P3: WastageQuantityIndex may not serve restaurant/date reporting.** The composite primary key already starts with RestaurantID and DateOfWastage. A quantity index may be useful for threshold filters, but not necessarily period aggregation. Measure both query shapes.
- [~] **15.6 — P3: Computed delivery duration is non-persisted.** Not a bug: it is calculated when needed. If duration filtering becomes expensive, evaluate an eligible indexed computed column or other indexing strategy; persistence alone does not guarantee faster filtering and adds write/storage cost.

## 16. Validation checklist before claiming fixes work

**Status:** These SQL Server runtime checks were not run during this revision because SQL Server services were stopped. No runtime pass is claimed.

- [ ] Run the full setup in a fresh test database using the documented batch order.
- [ ] Test valid and invalid ZIP/phone formats, NULLs, duplicate IDs and missing parent records.
- [ ] Insert multiple mixed employee roles in a single statement; verify every inserted employee has the correct subtype, and repeat for customers.
- [ ] Test subtype changes, direct subtype writes and parent deletion policies.
- [ ] Test fractional menu prices and exact monetary totals, including taxes, discounts and tips if supported.
- [ ] Change menu prices after an order is finalized; verify historical bills remain unchanged.
- [ ] Attempt an order containing another restaurant's item, unavailable items and invalid quantities; verify rejection.
- [ ] Simulate a failure between order header and line insertion; verify atomic rollback.
- [ ] Test invalid status transitions and missing delivery timestamps.
- [ ] Test incomplete deliveries, negative durations, exactly 60 minutes, slightly over 60 minutes, and tied fastest deliveries.
- [ ] Test feedback for missing restaurants, customers without completed orders and repeat purchases.
- [ ] Verify top-five results contain distinct restaurants ranked by their average ratings.
- [ ] Test wastage reports with two restaurants sharing a name, missing observations and different reporting periods.
- [ ] Verify passwords cannot be recovered from authentication storage and no real secrets are present in source code.
- [ ] Compare execution plans and logical reads on representative data before/after index changes; measure write overhead too.

## 17. Interview revision — highest-value issues

If time is limited, prioritize the multi-row trigger bug, four missing foreign keys, default DECIMAL scale, FLOAT currency, historical price snapshots, cross-restaurant orders, transaction atomicity, incorrect ranking aggregation, incomplete deliveries in fastest-delivery queries and password hashing versus encryption.

**How to explain the review:** The project demonstrates strong relational modelling fundamentals, but schema constraints alone do not enforce every business invariant. The next improvements would be set-based automation, stronger referential integrity, transactional order processing, exact financial data types, historical price snapshots and secure credential storage. Performance changes would be validated with actual execution plans rather than assumptions.

**Review update:** the remaining SQL scripts and dashboard workbook XML are now reviewed in Sections 18–25. See the final scope statement for remaining verification gaps.

## 18. DML seed data — DMDD_DML.sql (newly audited)

**Current seed snapshot:** the counts below describe rows declared by the revised seed script and were not confirmed by executing SQL Server. The seed runs only against an empty demo schema, is transactional, uses sequence output to map order IDs, and includes source-level assertions.

| Table | Seed rows |
|---|---:|
| Locations | 6 |
| OrderStatuses | 6 |
| Restaurants | 15 |
| Customers | 15 |
| Employees | 30 |
| Waiters / Chefs / DeliveryEmployees | 10 each |
| MenuItems | 47 |
| RestaurantWastage | 155 |
| Orders / OrderLines | 15 / 30 |
| Delivery / DineInOrders | 12 / 3 |
| Feedback | 15 |
| RestaurantAccounts / Payments / EncryptionDemo | 0 |
| **Core rows, including lookup and subtype rows** | **379** |
| OrderStatusHistory (created by status transitions) | 72 |

The 155 wastage rows intentionally cover January 2021 for five restaurants. The seed has no account credentials or payment attempts.

- [x] **18.1 — P0: Forty of 47 menu prices have a nonzero fractional part.** Lines 162–255 insert prices into `DECIMAL(18,0)`. Examples: 11.50, 18.95 and 21.95 cannot be stored accurately at scale zero. **Fix:** change the column to DECIMAL(10,2) before seeding; recover original prices from this source for the demonstration data. For a live migration, recover historical prices from trusted records rather than overwriting newer prices.
- [x] **18.2 — P1: All 10 delivery records assign a courier employed by a different restaurant.** Lines 903–922 versus employee lines 99–158. Example: order 1 belongs to restaurant 1, but employee 3 belongs to restaurant 2. **Fix:** decide whether couriers are restaurant-specific or shared; either correct assignments and seed appropriate couriers or explicitly model a shared delivery fleet. Do not merely reassign employees blindly.
- [x] **18.3 — P1: Seven delivery records belong to customers classified as dine-in.** Order IDs 1, 2, 4, 5, 7, 8, 10. **Fix:** add service type per order, or reconcile seed classifications with the original exclusive customer type rule. This is a concrete inconsistency under the intended exclusive-subtype interpretation.
- [x] **18.4 — P1: Delivered delivery-customer order 12 has no delivery record.** All 15 orders use status 4 (food delivered to customer); only 10 have delivery records. Of the five remaining orders, 12 belongs to a DC customer; 11, 13, 14, 15 are DI. **Fix:** seed a completed delivery for order 12 or change its status; define a separate dine-in fulfilled status or a channel-neutral completed status for dine-in orders.
- [x] **18.5 — P0: Order timestamps and delivery timestamps are inconsistent.** All order headers use GETDATE() at seed time; every delivery uses November 23, 2021. On a new installation today the delivery starts before the order exists. **Fix:** use fixed, coherent demonstration dates or derive delivery times from each order's timestamp. Validate OrderTime <= DeliveryStartTime <= DeliveryEndTime for completed deliveries.
- [x] **18.6 — P1: Six reviews do not match any seeded order by that customer at that restaurant.** Customer/restaurant pairs: (1,6), (2,4), (3,5), (4,3), (5,2), (6,1). Lines 260–276. **Fix:** link feedback to an eligible order and seed matching visits/orders or move the reviews to the proper restaurant. They might represent unrecorded historical visits; the current seed cannot demonstrate verified-purchase eligibility.
- [x] **18.7 — P1: All 15 orders omit OrderAmount.** Lines 787–895; the seed never calculates it. Under ordinary nullability settings every amount remains NULL until explicitly billed. **Fix:** calculate and store all finalized order amounts from order-line snapshots during seeding/checkout; keep draft amounts NULL only if explicitly designed that way.
- [x] **18.8 — P2: Two indistinguishable Spring Roll menu items exist for restaurant 6.** Lines 196 and 198 have different prices (12.04 and 10.04) but identical name and availability. **Fix:** establish whether they represent variants; add variant/SKU identity or correct the duplicate. Do not add a universal name UNIQUE constraint if distinct dishes can legitimately share a display name.
- [x] **18.9 — P1: Date strings are language/DATEFORMAT dependent.** Wastage lines 311–783 use M/D/YYYY strings. Under DMY, dates may be misread or invalid; the delivery date-time literals also use a locale-dependent form. **Fix:** use DATEFROMPARTS or YYYYMMDD for dates, and ISO 8601 YYYY-MM-DDTHH:mm:ss for datetime values. Test under multiple DATEFORMAT settings.
- [x] **18.10 — P0: Generated identity values are assumed to equal insertion order.** Restaurants, customers and menu items have IDENTITY keys; child rows hardcode IDs from a pristine run. A failed insert, reseed, or nonempty target can silently mislink records or cause FK failures. **Fix:** seed only an explicitly disposable empty database or capture identity mappings with OUTPUT inserted.ID and stable seed identifiers. Do not assume identity values are contiguous.
- [x] **18.11 — P0: Seed is not atomic and is unsafe to rerun.** No encompassing transaction or error handling; partial load can survive an error, and a rerun encounters duplicate PKs or new identity IDs. **Fix:** use a guarded fresh-demo seed or genuinely idempotent inserts, SET XACT_ABORT ON, TRY/CATCH, rollback and post-load checks. Keep production migration scripts separate from sample data.
- [x] **18.12 — P1: Seed depends on triggers being installed first.** Without the triggers, the delivery employee subtypes are missing and delivery insertions fail. **Fix:** assert both triggers exist and are enabled or use explicit controlled seeding of subtypes without double insertion. If changing to bulk INSERTs, first fix the original multi-row trigger bug.
- [~] **18.13 — P2: Seed lacks useful variety for order status testing.** Status IDs are 0,2,3,4,5,6; all 15 orders are status 4. Nonconsecutive status IDs are not a bug, but no examples test preparing, cancelled, walked-out, awaiting pickup or in-progress status. **Fix:** seed coherent examples for each supported state, and use actual status IDs in demonstrations rather than assuming they start at 1.
- [~] **18.14 — P2: Wastage data has limited temporal and restaurant coverage.** 155 records = 31 January 2021 dates for each of restaurants 1–5 only. No records for restaurants 6–15 and no other months. **Fix:** retain this for a simple demo but add zero, missing, multiple-month/year and leap-day cases to validate reporting.
- [x] **18.15 — P2: Dine-in subtype rows never receive waiter assignments.** Trigger creates NULL WaiterID; the DML has no assignment UPDATE. **Fix:** seed some valid per-visit waiter assignments and include unassigned cases intentionally. Reconcile with the proposed visit/order-level model.
- [~] **18.16 — P2: Seed never exercises unavailable menu items or busy couriers.** All 47 menu rows are Yes; courier availability is initialized to Yes. **Fix:** add unavailable items, active delivery and busy-courier scenarios; verify lifecycle constraints rather than changing historical availability blindly.
- [x] **18.17 — P2: Sample contact information resembles real personal/business data.** The repository contains names, phone numbers and addresses. **Fix:** verify data provenance or replace contacts with clearly fictional/anonymized values before distributing the project; keep sensitive production data out of sample exports. This is a precaution, not a finding that the contacts are real.
- [x] **18.18 — P2: Seed has no explicit correctness assertions.** Add expected row counts, orphan checks, cross-restaurant mismatch checks, price preservation checks and billing totals. Expected counts above apply to the original seed, before changing its data/model.
- [x] **18.19 - P1: Seeded feedback timestamp could predate its fulfilled order.** The first revision used the order creation timestamp as review creation time. **Resolution:** feedback now receives a post-fulfillment UTC timestamp, and a seed assertion rejects reviews dated before their order or completed delivery.

**Historical pre-revision positive checks:** Static parsing found no duplicate restaurant/date wastage keys and no cross-restaurant ORDERLINE items in the original 30 seeded lines. Those statements describe the old seed only; the revised seed is summarized above.

### Diagnostic queries (run on original schema before migration)

```sql
-- Delivery staff employed by another restaurant
SELECT d.OrderID, d.RestaurantID, d.DeliveryEmployeeID,
       e.RestaurantID AS EmployeeRestaurantID
FROM dbo.DELIVERY AS d
JOIN dbo.EMPLOYEES AS e ON e.EmployeeID = d.DeliveryEmployeeID
WHERE d.RestaurantID <> e.RestaurantID;

-- Delivery start before ordering
SELECT o.OrderID, o.OrderTime, d.DeliveryStartTime
FROM dbo.ORDERS AS o
JOIN dbo.DELIVERY AS d ON d.OrderID = o.OrderID
WHERE d.DeliveryStartTime < o.OrderTime;

-- Reviews without a matching recorded order (not necessarily invalid historically)
SELECT f.CustomerID, f.RestaurantID
FROM dbo.FEEDBACK AS f
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ORDERS AS o
    WHERE o.CustomerID = f.CustomerID
      AND o.RestaurantID = f.RestaurantID
);

-- Delivered DC orders without a delivery record, using original seed status IDs
SELECT o.OrderID
FROM dbo.ORDERS AS o
JOIN dbo.CUSTOMERS AS c ON c.CustomerID = o.CustomerID
WHERE c.CustomerType = 'DC' AND o.OrderStatusID = 4
  AND NOT EXISTS (SELECT 1 FROM dbo.DELIVERY AS d WHERE d.OrderID = o.OrderID);
```

## 19. Stored procedures — additional findings after full source review

These extend Section 13; fix both sections together rather than duplicating work. Source: `DMDD_SPs.sql`.

- [x] **19.1 — P0: Demo EXEC does not capture the OUTPUT parameter.** `exec sp_CalculateTotalAmount 2, 3.89, @TotalAmount = @TotalAmount;` omits `OUTPUT` at the call site. The caller's variable is not populated, even if the procedure updates the order. **Fix:** use `EXEC dbo.usp_CalculateTotalAmount @OrderID=2, @tips=3.89, @TotalAmount=@TotalAmount OUTPUT; SELECT @TotalAmount;` with a variable of the corrected exact type and the actual deployed procedure name.
- [x] **19.2 — P0: Demo execution embedded in deployment script.** The bill calculation example is uncommented, updates order 2, and is not separated from the procedure body by GO. As supplied, the script fails batch rules; simply adding separators in the wrong places may place the example inside the procedure definition. **Fix:** terminate each definition with GO, move examples to a separate test script, and never deploy business data changes accidentally.
- [x] **19.3 — P2: User-defined procedures use the `sp_` prefix.** SQL Server reserves this naming convention for system procedures and it can introduce name-resolution ambiguity. **Fix:** use schema-qualified names such as `dbo.usp_CalculateTotalAmount`; migrate consumers and documentation together. Not a current data correctness bug by itself.
- [x] **19.4 — P2: No explicit schema qualification for most tables/procedures.** Creation and name resolution depend on the executing user's default schema. **Fix:** qualify database objects with dbo (or another chosen schema) consistently, including seed and reporting queries.
- [x] **19.5 — P2: Procedures omit SET NOCOUNT ON.** UPDATE statements can produce row-count messages in addition to result sets. **Fix:** add NOCOUNT for a clean client interface, and document which result sets and output parameters are returned.
- [x] **19.6 — P1: Wastage procedure does not distinguish absent restaurants from missing measurements.** LEFT JOIN returns NULL AVG for a known restaurant without data; an unknown ID returns no rows. **Fix:** validate IDs, expose count of measured days, total and average, and preserve NULL for missing observations. Validate date range (start <= end) with well-defined inclusive/exclusive bounds.
- [x] **19.7 — P1: Billing recomputes from current mutable data and updates any order state.** Procedure has no guard against modifying a finalized or cancelled order, and no preserved breakdown of tip/tax/discount. **Fix:** use immutable price snapshots and finalized totals, restrict recalculation to allowed states, persist components, and define refunds/adjustments separately.
- [x] **19.8 — P1: Billing SELECT and UPDATE are separate statements without concurrency protection.** Lines, prices, or order status may change between calculating and saving. **Fix:** use an explicit transactional write path with suitable locking/isolation or optimistic version checks; ensure other writers obey the same rules. Test concurrent checkout and edits.
- [x] **19.9 — P1: Billing silently ignores NULL line values.** SUM ignores a NULL product when a line has NULL Price or Quantity, potentially underbilling an otherwise valid order. **Fix:** require validated prices and quantities and fail checkout if any line is invalid; check arithmetic range/rounding rather than coercing invalid values to zero.
- [x] **19.10 — P2: Billing returns SELECT *.** Output is coupled to future schema changes, can expose unnecessary fields and duplicates data supplied through OUTPUT. **Fix:** return an explicit documented result contract; include order ID and final total or a structured breakdown as required.
- [x] **19.11 — P1: Restaurant ranking has no explicit complete-rating or tie policy.** NULL component ratings yield NULL total; LEFT JOIN allows unrated rows to appear if fewer than five rated entries exist; ties have no deterministic order. **Fix:** choose how to treat partial/unrated feedback, include rating count and restaurant name, use AVG with exact arithmetic and deterministic tie-breaks; use WITH TIES only if returning >5 is intentional.
- [~] **19.12 — P3: Rating ranking based on a single review may be statistically misleading.** Even after correcting AVG, a restaurant with one perfect review can outrank one with hundreds. **Fix if required:** show review count, define minimum sample requirements or use a documented Bayesian/weighted score. Do not change the stated top-average business rule without agreement.
- [x] **19.13 — P1: Fastest delivery lacks order identity and deterministic tie-break.** TOP 1 selects only employee name and minutes; duplicate employee names and equal durations create ambiguous results. **Fix:** return OrderID, DeliveryEmployeeID, exact duration and timestamps; filter valid completed deliveries and define tie behaviour. Reuse one duration definition across reports.
- [x] **19.14 — P1: Delivery violation output has no explicit ordering or full timing context.** For operational action, include IDs, start/end timestamps, threshold and excess duration, and sort consistently. Distinguish completed and active overdue records; reject NULL/negative thresholds.
- [x] **19.15 — P2: Procedure error/result contracts are undefined.** Invalid ZIP, unknown restaurant, unknown order and no matching deliveries are not explicitly documented; parameter type conversions can hide malformed inputs. **Fix:** validate according to use case and define whether to return an empty result, explicit status, or THROW. Avoid treating a valid no-results report as an error unnecessarily.
- [x] **19.16 — P2: Stored procedure execution permissions not defined.** No deployment grants or least-privilege roles. **Fix:** allow app/reporting roles to execute only required procedures, restrict direct table writes and credential access, and review ownership chains. Do not grant db_owner to ordinary users.

### Suggested test cases for the five procedures

| Procedure | Test and expected behaviour after fix |
|---|---|
| Wastage | Unknown ID, known ID without records, measured zero, date boundaries; distinct results and correct count/total/average |
| Bill | Missing order, empty order, NULL/negative tip, fractional price, price change, finalized order, concurrent edit; correct exact amount or explicit error |
| Ranking | Six restaurants, multiple reviews per restaurant, tie, incomplete/unrated feedback, ZIP with no restaurants; distinct ranked restaurants |
| Fastest | No deliveries, NULL end, invalid negative time, equal durations, sub-minute duration differences; only valid completed deliveries |
| Violations | 59:59, 60:00, 60:01, custom threshold, negative threshold, ongoing overdue; exact documented SLA behaviour |

## 20. Views — additional findings after full source review

- [x] **20.1 — P2: Restaurant_Incity uses a LEFT JOIN then filters on the right-hand table.** `WHERE l.city = 'Boston'` eliminates unmatched locations, making the result equivalent to an INNER JOIN for this query. **Fix:** use INNER JOIN for the explicitly Boston-only report, or expose all restaurants with a LEFT JOIN without that filter. This is clarity, not an incorrect Boston filter.
- [x] **20.2 — P1: Restaurant_Wastage does not expose daily audit detail promised by README.** It returns only lifetime SUM per restaurant name. **Fix:** create a separate daily audit view with RestaurantID, DateOfWastage, quantity and reporting status; keep a correctly grouped summary view separately.
- [x] **20.3 — P2: Wastage summary omits date coverage, unit in alias and observation count.** Total_Weight has no explicit unit or period. **Fix:** expose `TotalWastagePounds`, `MeasuredDays`, earliest/latest measurement date, and allow date filtering through a detail view or procedure. Distinguish missing from zero.
- [x] **20.4 — P2: Views are not automatically access controls.** Creating a view does not prevent direct table access. **Fix:** define auditor/reporting roles, grant SELECT only on appropriate views, and verify underlying table and credential data are not accessible to those roles.

## 21. Encryption and decryption — additional findings after full source review

Source: `Encryption.sql` and `Decryption.sql`. The correct production direction is password hashing (Section 12), not adding more reversible password infrastructure. Keep encryption/decryption only as a separate demonstration for synthetic, recoverable non-password data if desired.

- [x] **21.1 — P0: Decryption script displays plaintext credentials for every restaurant.** `SELECT *, CONVERT(varchar, DecryptByKey([Password])) AS 'Decrypted password' FROM dbo.RESTAURANTS` exposes the entire table and all decrypted passwords. **Fix:** remove this from authentication and ordinary operations. If demonstrating encryption, limit output to one synthetic non-credential field and restrict the demonstration role.
- [x] **21.2 — P1: Both scripts leave the symmetric key open.** Open symmetric keys are session-scoped and can remain open until explicitly closed or the session ends. **Fix (demo only):** close `RestPass_SM` after use, including failure handling, and avoid reusing sessions containing open keys across unrelated security contexts.
- [x] **21.3 — P1: Decryption script relies on the caller's current database.** Unlike Encryption.sql, it has no USE statement. The key/certificate may not exist in the selected database. **Fix:** explicitly set and validate database context before any demonstration.
- [x] **21.4 — P1: Encryption/decryption failures are not checked.** `EncryptByKey` / `DecryptByKey` can return NULL when required keys/context are unavailable or input is invalid. A mass UPDATE can silently write NULL to a nullable password field. **Fix:** validate results, reject unexpected NULL, use transactional scoped writes and error handling; never overwrite existing credentials on failure.
- [x] **21.5 — P2: Decryption uses `CONVERT(varchar, ...)` with implicit length.** CAST/CONVERT defaults to length 30 when omitted; a longer demonstration plaintext can be truncated. **Fix:** use explicit length and matching original encoding/type, test Unicode and longer values. The short existing demo password is not truncated by this specific defect.
- [x] **21.6 — P2: Encryption comment confuses binary storage with hexadecimal representation.** VARBINARY stores bytes, not hexadecimal text; hex is a display representation. **Fix:** correct comments and specify text-to-binary conversion and length explicitly for the demo.
- [x] **21.7 — P1: Key creation is non-idempotent and has no recovery procedure.** CREATE MASTER KEY/CERTIFICATE/SYMMETRIC KEY will conflict with existing objects. **Fix:** separate one-time provisioning from normal app use, verify object identities and algorithm, do not drop existing keys to rerun a script, and document encrypted backup/restore and key rotation for recoverable encrypted data.
- [x] **21.8 — P1: No credential enrollment, verification, reset or account lifecycle.** The scripts merely assign common demonstration credentials and display decrypted values. **Fix:** implement unique enrollment/reset flows, vetted hash verification, rate limiting, restricted credential storage and appropriate audit events in a real authentication layer. Clearly state the original is only a demo.
- [x] **21.9 — P1: No access separation between restaurant profile and credentials.** The same table contains public-ish profile information and password ciphertext; SELECT * exposes ciphertext too. **Fix:** separate restricted authentication records from profile data or restrict through carefully granted views/procedures. Do not log passwords or hashes.
- [x] **21.10 — P2: No documented protection for database connections, backups, exports or personally identifying data.** Column encryption is not a complete security strategy. **Fix:** establish TLS, access roles, secure backups, retention, and audit policies appropriate to deployment. These are production hardening requirements, not evidence of a breached system.
- [x] **21.11 — P3: Recoverable ciphertext is not bound to a row in the demo.** If retaining a non-password encryption demonstration, consider authenticated row context (SQL Server EncryptByKey authenticator option where suitable) to mitigate whole-value substitution; test failure when context differs. Do not use this as a substitute for password hashing or a broader integrity design.
- [x] **21.12 - P1: General application role included account-wide credential changes.** A shared role able to reset or disable any restaurant account could cross tenant boundaries if assigned too broadly. **Resolution:** enrollment/reset/disable execution is separated into `restaurant_account_admin_role`; enrollment also requires an active restaurant. Documentation states that these database roles are service roles, not tenant authorization, and the application must scope each restaurant action.

## 22. Tableau visualization — workbook and archive review

**Current package inspection:** `DataVisualizationDashboard.zip` contains the revised `.twbx` and visualization report. The `.twbx` contains the workbook, four sanitized source CSVs, and a rebuilt Hyper extract. Extract row counts are 155 wastage measurements, 15 restaurants, 15 customers, and 15 feedback rows. Static XML inspection found no author-specific path, phone/address fields, or obsolete `CustomerType` field. Tableau Desktop open/refresh and cross-machine checks remain unperformed.

- [x] **22.1 — P1: Dashboard is a static CSV/extract workflow, not a live SQL Server connection.** The workbook uses a textscan connection and a packaged Hyper extract rather than the SQL Server database. **Fix:** connect to tested reporting views or maintain a documented CSV/extract regeneration process. Label snapshot date and refresh cadence; do not claim live reporting.
- [x] **22.2 — P1: Workbook refresh depends on an author-specific absolute Windows path.** XML references a local OneDrive/Desktop project folder. The archive contains the extract but does not package the four source CSVs (`RestaurantWastage.csv`, `Restaurant.csv`, `feedback1.csv`, `customer.csv`). **Fix:** provide sanitized reproducible exports, use portable connections or connect to a database, and remove machine-specific paths. Existing packaged extract may still open without original CSVs; refresh is the portability issue.
- [x] **22.3 — P1: Dashboard wastage average formula can use an incorrect denominator.** Workbook contains `SUM([WastageQuantityInPounds])/COUNT([RestaurantID])`. Depending on relationship grain, COUNT may count rows without a valid wastage value or duplicated rows. **Fix:** use AVG on valid daily observations or explicit SUM divided by the count of non-null unique restaurant-day measurements at the correct grain; verify against SQL. Not proof that the current extract produces wrong numbers.
- [x] **22.4 — P2: Rating calculation is defined as FoodRating + ServiceRating.** This is a 2–10 score for complete 1–5 components, not a 1–5 average. **Fix:** label it correctly, or use `(FoodRating + ServiceRating)/2.0` and aggregate by restaurant. Define NULL policy and reconcile with corrected ranking logic. The formula itself is valid if a combined score is intended.
- [x] **22.5 — P1: Dashboard sources cover restaurants, wastage, feedback and customers only.** The workbook does not reference order, order-line or delivery tables. **Fix if intended scope includes all five business cases:** add verified order and delivery reporting datasets and KPI sheets, or describe the dashboard honestly as wastage/customer/restaurant-feedback analytics.
- [~] **22.6 — P3: Mixed-grain sources risk double-counting.** Restaurant, daily wastage, customer and feedback entities have different grains. Tableau relationships may preserve grain, but results must be tested with filters and measures. **Fix:** reconcile totals, use correct relationship cardinality, and avoid flattening multiple one-to-many facts into a single duplicated join.
- [x] **22.7 — P2: Generic worksheet names.** Workbook includes names such as Sheet 1, Sheet 1 (2), Sheet 3–7, Dashboard 1. **Fix:** use descriptive metric names, units, date scope and explanatory tooltips. Review actual rendered labels and accessibility before asserting further visual defects.
- [x] **22.8 — P1: Packaged extract could contain sensitive customer data.** The customer source is included as an extract relation; its row contents were not inspected. **Fix:** audit fields and rows, exclude personal contact information from analytics extracts, apply appropriate permissions, and regenerate a sanitized workbook for public sharing.
- [~] **22.9 — P2: No independently verified refresh or reconciliation workflow.** **Fix:** compare each KPI against known SQL outputs, refresh from clean seed on another machine, test missing records and changed prices, and document Tableau version requirements. Inspect companion visualization PDF for metric/documentation mismatches before marking this complete.

## 23. README, deployment and cross-file consistency — additional findings

- [x] **23.1 — P1: README promises capabilities the scripts do not implement.** Daily/monthly/half-yearly/annual wastage, tax calculation, average top-five ranking and configurable violation threshold differ from code. **Fix:** implement the agreed behaviour or narrow the claims, then add examples with expected results.
- [~] **23.2 — P2: No explicit supported SQL Server version or deployment client.** Inline indexes and CREATE OR ALTER require compatible SQL Server versions; GO requires a batch-aware client. **Fix:** document tested SQL Server version/edition and SSMS/sqlcmd usage; test on a clean instance.
- [x] **23.3 — P1: No database migration/versioning strategy.** DDL uses CREATE TABLE and dependent scripts assume original names and shapes. **Fix:** introduce numbered versioned migrations, a separate demo seed, schema-qualified deploy commands, and a disposable test target; avoid destructive resets for existing data.
- [ ] **23.4 — P2: No automated test harness or CI is present in the repository root listing.** **Fix:** add repeatable SQL integration tests against a disposable SQL Server instance; assert constraints, trigger behavior, reporting outputs, security permissions and deployment repeatability.
- [x] **23.5 — P2: No explicit rollback/backfill plan for new required columns.** Price snapshots, payment/visit fields and stronger constraints cannot safely be added to populated tables without migration decisions. **Fix:** audit, stage nullable fields, backfill from trusted sources, validate, then enforce constraints; mark unavailable history rather than inventing it.
- [x] **23.6 — P2: ER diagrams and SQL consumers need synchronization after fixes.** Rename misspelled objects or change subtype/order/payment models only with updates to views, procedures, DML, Tableau exports, design diagrams and README. Keep a data dictionary and changelog.
- [x] **23.7 — P3: Scope expansion can unnecessarily complicate an interview project.** Choose explicit requirements for one restaurant per order, customer channels, courier ownership, taxes, historical reviews, payment attempts and daily waste. Treat alternatives as optional if the requirement does not exist. Implement correctness first, then benchmark before adding indexes or features.

## 24. Recommended correction sequence (do not apply everything blindly)

1. **Protect the baseline:** create a branch and disposable SQL Server database, capture expected source counts, and never use the public demo credentials for real accounts.
2. **Make deployment reproducible:** database creation, batches, explicit schema, safe migration and seed scripts; separate demo EXEC statements.
3. **Set business rules:** order-level service type, courier ownership, delivery attempts, status transitions, review eligibility, taxes/tips and currency policy. Record decisions before changing keys.
4. **Fix schema and triggers:** missing foreign keys, exact numeric types, required fields, subtype consistency and set-based triggers. Clean or backfill existing data before enabling trusted constraints.
5. **Correct sample data:** identity mapping, dates, restaurant/courier consistency, feedback/order eligibility, menu duplicates and billing values. Seed coherent edge cases.
6. **Implement transactional operations:** order creation, purchase-time prices, finalized billing, payment and delivery lifecycle, availability and status handling.
7. **Fix stored procedures and views:** aggregate correctly, use explicit inputs/outputs and validated periods/thresholds, remove invalid deliveries and protect finalized orders.
8. **Fix security:** separate demonstration encryption from actual authentication; use safe password storage, permissions, key handling where relevant and sanitized data.
9. **Regenerate dashboard and documentation:** replace nonportable refresh paths and reconcile KPIs to SQL.
10. **Measure and test:** validate runtime behavior, concurrency, restore/redeploy and actual execution plans. Only then remove or add indexes based on evidence.

## 25. Additional regression checklist

**Status:** Runtime and deployment checks below remain open unless marked `[x]` or `[~]`; SQL Server was not available for execution. The PDF visual review and static package/privacy checks were completed.

- [ ] Assert the original seed's expected 344 explicit inserts and 389 total records on an unchanged fresh demo; update expected counts once seed/model changes are intentional.
- [ ] Run seed in a nonempty database and after a simulated mid-seed failure; it must refuse safely or rerun idempotently, without mislinking identity values.
- [ ] Verify prices such as 18.95 and 11.50 survive a round trip exactly.
- [ ] Verify every order's delivery/customer channel matches the chosen business rules and all delivery starts follow order creation.
- [ ] Verify all finalized seeded orders have correct totals; use independently calculated expected amounts from source price snapshots.
- [x] Check six original unmatched review pairs and all ten original cross-restaurant courier assignments are resolved or documented as intentional under the new model.
- [ ] Run seed under DMY and MDY settings and compare timestamps/dates.
- [ ] Verify procedure OUTPUT values are captured, deployment doesn't modify order 2, and invalid inputs return documented errors/results.
- [ ] Run concurrent order-line edit/finalization and courier assignment tests; ensure no stale totals, duplicate active assignments or partial writes.
- [ ] Verify SQL view results match date-bounded calculations and do not merge restaurants with identical names.
- [ ] Verify unauthorized app/auditor roles cannot directly read credentials or decrypt demonstration data.
- [~] Verify no shared credentials or hardcoded real secrets are deployed; if retaining encryption demo, test closed keys, NULL failures, long values and restore from backup.
- [ ] Open and refresh Tableau on another machine, compare all measures with SQL, and audit the packaged extract for unnecessary personal data.
- [ ] Test all documented deployment commands from a clean clone on the declared SQL Server version.
- [x] Independently inspect the design document, final report PDF and dashboard report PDF for outdated claims and inconsistencies; update them after the code and schema are corrected.

## Final review scope and limitations

All seven SQL scripts, the README, migration entry points, dashboard workbook XML, sanitized CSV snapshot, rebuilt Hyper extract, and revised PDFs were reviewed. The dashboard extract row counts and sensitive-field/path checks were inspected, and all eight revised PDF pages were rendered and visually checked. Source-level seed and relationship assertions are included, but they were not executed against SQL Server.

The SQL scripts have not been executed against SQL Server. No runtime constraint/trigger/procedure checks, concurrency tests, permission tests, restore/redeploy checks, or execution-plan measurements were performed because SQL Server services were stopped in the review environment. Tableau Desktop was unavailable, so the workbook was not opened or refreshed in Tableau. These are the remaining verification gaps; the checklist does not claim they passed. This review implements the listed source corrections and documents deliberate demo scope choices, but it cannot establish production readiness or guarantee that no other defect exists.
