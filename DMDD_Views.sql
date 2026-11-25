USE [DMDDFinalProjectDB];
GO

CREATE OR ALTER VIEW dbo.v_RestaurantDirectory
AS
    SELECT r.RestaurantID, r.RestaurantName, r.StreetAddress, r.ZipCode,
           l.City, r.PhoneNumber, r.Cuisine, r.IsActive
    FROM dbo.Restaurants AS r
    JOIN dbo.Locations AS l ON l.ZipCode = r.ZipCode;
GO

/* One row per recorded restaurant/day. A row with quantity zero is a measured
   zero; a date without a row is unreported and is not invented as zero. */
CREATE OR ALTER VIEW dbo.v_RestaurantWastageDaily
AS
    SELECT r.RestaurantID,
           r.RestaurantName,
           w.DateOfWastage,
           w.WastageQuantityInPounds,
           N'Reported' AS ReportingStatus
    FROM dbo.RestaurantWastage AS w
    JOIN dbo.Restaurants AS r ON r.RestaurantID = w.RestaurantID;
GO

/* Lifetime coverage summary. Reporting date ranges belong in the procedure,
   since a view cannot take parameters. */
CREATE OR ALTER VIEW dbo.v_RestaurantWastageSummary
AS
    SELECT r.RestaurantID,
           r.RestaurantName,
           SUM(w.WastageQuantityInPounds) AS TotalWastagePounds,
           COUNT_BIG(w.DateOfWastage) AS MeasuredDays,
           MIN(w.DateOfWastage) AS FirstMeasurementDate,
           MAX(w.DateOfWastage) AS LastMeasurementDate
    FROM dbo.Restaurants AS r
    LEFT JOIN dbo.RestaurantWastage AS w ON w.RestaurantID = r.RestaurantID
    GROUP BY r.RestaurantID, r.RestaurantName;
GO

CREATE OR ALTER VIEW dbo.v_RestaurantRatings
AS
    SELECT r.RestaurantID,
           r.RestaurantName,
           r.ZipCode,
           AVG((CONVERT(decimal(5,2), f.FoodRating) + CONVERT(decimal(5,2), f.ServiceRating)) / 2.0) AS AverageRating,
           COUNT_BIG(f.OrderID) AS ReviewCount
    FROM dbo.Restaurants AS r
    LEFT JOIN dbo.Orders AS o ON o.RestaurantID = r.RestaurantID
    LEFT JOIN dbo.Feedback AS f ON f.OrderID = o.OrderID
    GROUP BY r.RestaurantID, r.RestaurantName, r.ZipCode;
GO

CREATE OR ALTER VIEW dbo.v_MenuCatalog
AS
    SELECT m.MenuItemID, m.RestaurantID, r.RestaurantName,
           m.MenuItemCode, m.MenuItemName, m.Price, m.IsAvailable
    FROM dbo.MenuItems AS m
    JOIN dbo.Restaurants AS r ON r.RestaurantID = m.RestaurantID;
GO

CREATE OR ALTER VIEW dbo.v_OrderSummary
AS
    SELECT o.OrderID, o.CustomerID, o.RestaurantID, r.RestaurantName,
           o.ServiceType, s.OrderStatusDescription, o.OrderTimeUTC,
           o.SubtotalAmount, o.TaxRate, o.TaxAmount, o.TipAmount, o.OrderAmount
    FROM dbo.Orders AS o
    JOIN dbo.Restaurants AS r ON r.RestaurantID = o.RestaurantID
    JOIN dbo.OrderStatuses AS s ON s.OrderStatusID = o.OrderStatusID;
GO
