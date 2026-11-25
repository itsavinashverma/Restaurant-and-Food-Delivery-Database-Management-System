# Tableau snapshot data

This folder contains a sanitized CSV snapshot and the editable `DMDD_Tableau.twb` workbook template. The packaged workbook remains a file extract, not a live SQL Server connection.

## Refreshing the snapshot

1. Export current rows from SQL Server to the four CSV files in this folder, keeping the headers and types below. Use ISO dates (`YYYY-MM-DD`) and pounds for wastage. Do not export addresses, phone numbers, credential data, or other contact details.
2. `customer.csv` uses `LastOrderChannel`, derived from each customer's most recent order. It must not be stored as a permanent customer type. Use `No order` when a customer has no order.
3. Review the row grain before export: one wastage row per restaurant/day, one restaurant row per restaurant, one feedback row per fulfilled order, and one row per customer.
4. Install the Tableau Hyper API (`python -m pip install tableauhyperapi`) and run `python DashboardData/build_tableau_package.py`. It rebuilds the extract and replaces `DataVisualizationDashboard.zip` with a portable package containing the workbook, CSV sources, and Hyper file.
5. Open the rebuilt `.twbx` in Tableau Desktop or Tableau Reader. Refresh the packaged CSV connection on a second machine and reconcile the average daily wastage and average rating with `dbo.v_RestaurantWastageDaily` and `dbo.v_RestaurantRatings` before distributing the report.

The current snapshot has 15 customers, 15 restaurants, 15 reviews, and 155 wastage days. The workbook focuses on customer/restaurant counts, ratings, and wastage; it makes no order or delivery KPI claims. Tableau Desktop was not available for a visual open/refresh check when this package was revised.

## CSV columns

- `RestaurantWastage.csv`: `RestaurantID`, `DateOfWastage`, `WastageQuantityInPounds`
- `Restaurant.csv`: `RestaurantID`, `RestaurantName`, `ZipCode`, `Cuisine`
- `feedback1.csv`: `CustomerID`, `RestaurantID`, `FeedbackDescription`, `FoodRating`, `ServiceRating`
- `customer.csv`: `CustomerID`, `CustomerName`, `ZipCode`, `LastOrderChannel`
