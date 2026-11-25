USE [DMDDFinalProjectDB];
GO

CREATE OR ALTER PROCEDURE dbo.usp_CreateOrder
    @CustomerID int,
    @RestaurantID int,
    @ServiceType char(2),
    @OrderLines dbo.OrderLineInput READONLY,
    @OrderID int OUTPUT,
    @WaiterID int = NULL,
    @OrderTimeUTC datetime2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ServiceType IS NULL OR @ServiceType NOT IN ('DI', 'DL')
        THROW 51100, 'ServiceType must be DI (dine-in) or DL (delivery).', 1;
    IF NOT EXISTS (SELECT 1 FROM @OrderLines)
        THROW 51103, 'An order must contain at least one menu item.', 1;
    IF @ServiceType = 'DI' AND @WaiterID IS NULL
        THROW 51104, 'A dine-in order requires a waiter assignment.', 1;
    IF @ServiceType = 'DL' AND @WaiterID IS NOT NULL
        THROW 51105, 'A delivery order cannot have a dine-in waiter assignment.', 1;
    DECLARE @RequestedLineCount int = (SELECT COUNT(*) FROM @OrderLines);
    DECLARE @ValidLineCount int;
    DECLARE @CreatedAtUTC datetime2(3) = COALESCE(@OrderTimeUTC, SYSUTCDATETIME());

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS
           (SELECT 1 FROM dbo.Customers WITH (UPDLOCK, HOLDLOCK)
            WHERE CustomerID = @CustomerID AND IsActive = 1)
            THROW 51101, 'The customer does not exist or is inactive.', 1;
        IF NOT EXISTS
           (SELECT 1 FROM dbo.Restaurants WITH (UPDLOCK, HOLDLOCK)
            WHERE RestaurantID = @RestaurantID AND IsActive = 1)
            THROW 51102, 'The restaurant does not exist or is inactive.', 1;
        IF @ServiceType = 'DI' AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.Waiters AS w WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Employees AS e WITH (UPDLOCK, HOLDLOCK)
              ON e.EmployeeID = w.WaiterID
            WHERE w.WaiterID = @WaiterID AND w.RestaurantID = @RestaurantID AND e.IsActive = 1
        )
            THROW 51106, 'The waiter must be active and work at the order restaurant.', 1;

        /* Update/serializable locks keep menu availability and price stable
           while the order and its price snapshots are written. */
        SELECT @ValidLineCount = COUNT(*)
        FROM @OrderLines AS input
        JOIN dbo.MenuItems AS menu WITH (UPDLOCK, HOLDLOCK)
          ON menu.MenuItemID = input.MenuItemID
         AND menu.RestaurantID = @RestaurantID
         AND menu.IsAvailable = 1;

        IF @ValidLineCount <> @RequestedLineCount
            THROW 51107, 'Every requested menu item must exist at this restaurant and be available.', 1;

        SELECT @OrderID = NEXT VALUE FOR dbo.OrderIDSequence;

        INSERT dbo.Orders (OrderID, CustomerID, RestaurantID, ServiceType, OrderStatusID, OrderTimeUTC)
        VALUES (@OrderID, @CustomerID, @RestaurantID, @ServiceType, 1, @CreatedAtUTC);

        INSERT dbo.OrderLines (OrderID, MenuItemID, RestaurantID, OrderQuantity, UnitPrice)
        SELECT @OrderID, input.MenuItemID, @RestaurantID, input.OrderQuantity, menu.Price
        FROM @OrderLines AS input
        JOIN dbo.MenuItems AS menu
          ON menu.MenuItemID = input.MenuItemID
         AND menu.RestaurantID = @RestaurantID;

        IF @ServiceType = 'DI'
        BEGIN
            INSERT dbo.DineInOrders (OrderID, RestaurantID, WaiterID, VisitAtUTC)
            VALUES (@OrderID, @RestaurantID, @WaiterID, @CreatedAtUTC);
        END;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CalculateTotalAmount
    @OrderID int,
    @TipAmount decimal(12,2),
    @TaxRate decimal(5,4),
    @TotalAmount decimal(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @TipAmount IS NULL OR @TipAmount < 0
        THROW 51110, 'TipAmount must be zero or greater.', 1;
    IF @TaxRate IS NULL OR @TaxRate < 0 OR @TaxRate > 1
        THROW 51111, 'TaxRate must be between 0 and 1; pass the configured jurisdiction rate explicitly.', 1;

    DECLARE @OrderStatusID tinyint;
    DECLARE @ExistingSubtotal decimal(12,2);
    DECLARE @SubtotalWide decimal(38,2);
    DECLARE @TaxWide decimal(38,2);
    DECLARE @TotalWide decimal(38,2);
    DECLARE @TaxAmount decimal(12,2);
    DECLARE @SubtotalAmount decimal(12,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @OrderStatusID = OrderStatusID,
               @ExistingSubtotal = SubtotalAmount
        FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderID = @OrderID;

        IF @OrderStatusID IS NULL
            THROW 51112, 'OrderID was not found.', 1;
        IF @OrderStatusID <> 1
            THROW 51113, 'Only an unprocessed Pending order can be finalized.', 1;
        IF @ExistingSubtotal IS NOT NULL
            THROW 51114, 'The order is already finalized; use a separate adjustment or refund.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.OrderLines WITH (UPDLOCK, HOLDLOCK) WHERE OrderID = @OrderID)
            THROW 51115, 'An order with no valid lines cannot be finalized.', 1;

        SELECT @SubtotalWide = SUM(CONVERT(decimal(12,2), LineSubtotal))
        FROM dbo.OrderLines WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderID = @OrderID;

        SET @TaxWide = ROUND(@SubtotalWide * @TaxRate, 2);
        SET @TotalWide = @SubtotalWide + @TaxWide + @TipAmount;

        IF @SubtotalWide > 9999999999.99 OR @TaxWide > 9999999999.99 OR @TotalWide > 9999999999.99
            THROW 51116, 'The calculated amount exceeds the supported decimal(12,2) range.', 1;

        SET @SubtotalAmount = CONVERT(decimal(12,2), @SubtotalWide);
        SET @TaxAmount = CONVERT(decimal(12,2), @TaxWide);
        SET @TotalAmount = CONVERT(decimal(12,2), @TotalWide);

        UPDATE dbo.Orders
           SET SubtotalAmount = @SubtotalAmount,
               TaxRate = @TaxRate,
               TaxAmount = @TaxAmount,
               TipAmount = @TipAmount
         WHERE OrderID = @OrderID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransitionOrderStatus
    @OrderID int,
    @NewOrderStatusID tinyint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentStatusID tinyint;
    DECLARE @ServiceType char(2);
    DECLARE @Amount decimal(12,2);

    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @CurrentStatusID = OrderStatusID,
               @ServiceType = ServiceType,
               @Amount = OrderAmount
        FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderID = @OrderID;

        IF @CurrentStatusID IS NULL
            THROW 51120, 'OrderID was not found.', 1;
        IF NOT EXISTS
           (SELECT 1 FROM dbo.OrderStatuses WHERE OrderStatusID = @NewOrderStatusID)
            THROW 51121, 'The requested status does not exist.', 1;
        IF NOT EXISTS
           (SELECT 1 FROM dbo.OrderStatusTransitions WHERE FromStatusID = @CurrentStatusID AND ToStatusID = @NewOrderStatusID)
            THROW 51122, 'The requested status transition is not allowed.', 1;
        IF @NewOrderStatusID IN (2, 3, 4, 5) AND @Amount IS NULL
            THROW 51123, 'Finalize an order before moving it beyond Pending.', 1;
        IF @NewOrderStatusID = 4 AND (@ServiceType <> 'DL' OR NOT EXISTS
           (SELECT 1 FROM dbo.Delivery WHERE OrderID = @OrderID AND DeliveryStartTimeUTC IS NOT NULL))
            THROW 51124, 'An in-transit order requires a started delivery.', 1;
        IF @NewOrderStatusID = 5 AND
           ((@ServiceType = 'DL' AND NOT EXISTS
                (SELECT 1 FROM dbo.Delivery WHERE OrderID = @OrderID
                 AND DeliveryEmployeeID IS NOT NULL AND DeliveryEndTimeUTC IS NOT NULL))
            OR (@ServiceType = 'DI' AND NOT EXISTS
                (SELECT 1 FROM dbo.DineInOrders WHERE OrderID = @OrderID)))
            THROW 51125, 'A fulfilled order needs a completed delivery or dine-in visit.', 1;

        UPDATE dbo.Orders SET OrderStatusID = @NewOrderStatusID WHERE OrderID = @OrderID;
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AssignDelivery
    @OrderID int,
    @DeliveryEmployeeID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK)
            WHERE OrderID = @OrderID AND ServiceType = 'DL' AND OrderStatusID = 3
        )
            THROW 51130, 'A courier can only be assigned to a Ready delivery order.', 1;
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DeliveryEmployees AS de WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Employees AS e WITH (UPDLOCK, HOLDLOCK)
              ON e.EmployeeID = de.DeliveryEmployeeID
            WHERE de.DeliveryEmployeeID = @DeliveryEmployeeID
              AND de.IsDeliveryPartnerAvailable = 1 AND e.IsActive = 1 AND e.EmployeeType = 'D'
        )
            THROW 51131, 'The delivery employee does not exist or is already assigned to an active delivery.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Delivery WHERE OrderID = @OrderID)
            THROW 51132, 'This order already has a delivery record.', 1;

        INSERT dbo.Delivery (OrderID, DeliveryEmployeeID)
        VALUES (@OrderID, @DeliveryEmployeeID);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_StartDelivery
    @OrderID int,
    @StartTimeUTC datetime2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @StartTimeUTC = COALESCE(@StartTimeUTC, SYSUTCDATETIME());

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.Delivery AS d WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Orders AS o ON o.OrderID = d.OrderID
            WHERE d.OrderID = @OrderID AND d.DeliveryEmployeeID IS NOT NULL
              AND d.DeliveryStartTimeUTC IS NULL AND d.DeliveryEndTimeUTC IS NULL
              AND o.OrderStatusID = 3 AND o.ServiceType = 'DL'
              AND @StartTimeUTC >= o.OrderTimeUTC
        )
            THROW 51133, 'The delivery is not assigned and Ready, or the start time is invalid.', 1;

        UPDATE dbo.Delivery SET DeliveryStartTimeUTC = @StartTimeUTC WHERE OrderID = @OrderID;
        UPDATE dbo.Orders SET OrderStatusID = 4 WHERE OrderID = @OrderID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CompleteDelivery
    @OrderID int,
    @EndTimeUTC datetime2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @EndTimeUTC = COALESCE(@EndTimeUTC, SYSUTCDATETIME());

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.Delivery AS d WITH (UPDLOCK, HOLDLOCK)
            JOIN dbo.Orders AS o ON o.OrderID = d.OrderID
            WHERE d.OrderID = @OrderID AND d.DeliveryEmployeeID IS NOT NULL
              AND d.DeliveryStartTimeUTC IS NOT NULL AND d.DeliveryEndTimeUTC IS NULL
              AND o.OrderStatusID = 4 AND o.ServiceType = 'DL'
              AND @EndTimeUTC >= d.DeliveryStartTimeUTC
        )
            THROW 51134, 'The delivery is not In Transit or the end time precedes its start.', 1;

        UPDATE dbo.Delivery SET DeliveryEndTimeUTC = @EndTimeUTC WHERE OrderID = @OrderID;
        UPDATE dbo.Orders SET OrderStatusID = 5 WHERE OrderID = @OrderID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CalculateAndDisplayFoodWastageByRestaurants
    @RestaurantID int,
    @PeriodType varchar(10) = 'DAY',
    @StartDate date = NULL,
    @EndDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @PeriodType = UPPER(@PeriodType);

    IF @PeriodType NOT IN ('DAY', 'MONTH', 'HALFYEAR', 'YEAR')
        THROW 51140, 'PeriodType must be DAY, MONTH, HALFYEAR or YEAR.', 1;
    IF (@StartDate IS NULL AND @EndDate IS NOT NULL) OR (@StartDate IS NOT NULL AND @EndDate IS NULL)
        THROW 51141, 'StartDate and EndDate must either both be supplied or both be omitted.', 1;
    IF @StartDate > @EndDate
        THROW 51142, 'StartDate cannot be later than EndDate.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Restaurants WHERE RestaurantID = @RestaurantID)
        THROW 51143, 'RestaurantID was not found.', 1;

    SELECT @RestaurantID AS RestaurantID,
           r.RestaurantName,
           @PeriodType AS PeriodType,
           p.PeriodStart,
           COUNT_BIG(*) AS MeasuredDays,
           SUM(w.WastageQuantityInPounds) AS TotalWastagePounds,
           AVG(w.WastageQuantityInPounds) AS AverageWastagePounds
    FROM dbo.RestaurantWastage AS w
    JOIN dbo.Restaurants AS r ON r.RestaurantID = w.RestaurantID
    CROSS APPLY
    (
        VALUES
        (
            CASE @PeriodType
                WHEN 'DAY' THEN w.DateOfWastage
                WHEN 'MONTH' THEN DATEFROMPARTS(YEAR(w.DateOfWastage), MONTH(w.DateOfWastage), 1)
                WHEN 'HALFYEAR' THEN DATEFROMPARTS(YEAR(w.DateOfWastage), CASE WHEN MONTH(w.DateOfWastage) <= 6 THEN 1 ELSE 7 END, 1)
                WHEN 'YEAR' THEN DATEFROMPARTS(YEAR(w.DateOfWastage), 1, 1)
            END
        )
    ) AS p(PeriodStart)
    WHERE w.RestaurantID = @RestaurantID
      AND (@StartDate IS NULL OR w.DateOfWastage >= @StartDate)
      AND (@EndDate IS NULL OR w.DateOfWastage <= @EndDate)
    GROUP BY r.RestaurantName, p.PeriodStart
    ORDER BY p.PeriodStart;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_TopRestaurantsInArea
    @ZipCode varchar(5)
AS
BEGIN
    SET NOCOUNT ON;
    IF @ZipCode IS NULL OR LEN(@ZipCode) <> 5
       OR @ZipCode COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9]%'
        THROW 51150, 'ZipCode must contain exactly five ASCII digits.', 1;

    SELECT TOP (5)
           r.RestaurantID,
           r.RestaurantName,
           r.ZipCode,
           AVG((CONVERT(decimal(5,2), f.FoodRating) + CONVERT(decimal(5,2), f.ServiceRating)) / 2.0) AS AverageRating,
           COUNT_BIG(*) AS ReviewCount
    FROM dbo.Restaurants AS r
    JOIN dbo.Orders AS o ON o.RestaurantID = r.RestaurantID
    JOIN dbo.Feedback AS f ON f.OrderID = o.OrderID
    WHERE r.ZipCode = @ZipCode
    GROUP BY r.RestaurantID, r.RestaurantName, r.ZipCode
    ORDER BY AverageRating DESC, r.RestaurantID ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CalculateFastestDelivery
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
           d.OrderID,
           d.DeliveryEmployeeID,
           e.EmployeeName,
           CONVERT(decimal(12,3), d.DeliveryDurationMilliseconds / 1000.0) AS DeliveryDurationSeconds,
           d.DeliveryStartTimeUTC,
           d.DeliveryEndTimeUTC
    FROM dbo.Delivery AS d
    JOIN dbo.Orders AS o ON o.OrderID = d.OrderID AND o.OrderStatusID = 5
    JOIN dbo.DeliveryEmployees AS de ON de.DeliveryEmployeeID = d.DeliveryEmployeeID
    JOIN dbo.Employees AS e ON e.EmployeeID = de.DeliveryEmployeeID
    WHERE d.DeliveryStartTimeUTC IS NOT NULL
      AND d.DeliveryEndTimeUTC IS NOT NULL
      AND d.DeliveryDurationMilliseconds >= 0
    ORDER BY d.DeliveryDurationMilliseconds ASC, d.OrderID ASC, d.DeliveryEmployeeID ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ListDeliveryViolations
    @ThresholdMinutes int = 60,
    @IncludeActiveOverdue bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @ThresholdMinutes IS NULL OR @ThresholdMinutes < 0
        THROW 51160, 'ThresholdMinutes must be zero or greater.', 1;
    IF @IncludeActiveOverdue IS NULL
        THROW 51161, 'IncludeActiveOverdue must be 0 or 1.', 1;

    DECLARE @NowUTC datetime2(3) = SYSUTCDATETIME();
    DECLARE @ThresholdMilliseconds bigint = CONVERT(bigint, @ThresholdMinutes) * 60000;

    SELECT o.OrderID,
           o.RestaurantID,
           d.DeliveryEmployeeID,
           e.EmployeeName,
           d.DeliveryStartTimeUTC,
           d.DeliveryEndTimeUTC,
           @ThresholdMinutes AS ThresholdMinutes,
           CASE WHEN d.DeliveryEndTimeUTC IS NULL THEN 'ActiveOverdue' ELSE 'CompletedLate' END AS ViolationType,
           CONVERT(decimal(12,3),
               (DATEDIFF_BIG(millisecond, d.DeliveryStartTimeUTC,
                    COALESCE(d.DeliveryEndTimeUTC, @NowUTC)) - @ThresholdMilliseconds) / 1000.0
           ) AS SecondsBeyondThreshold
    FROM dbo.Delivery AS d
    JOIN dbo.Orders AS o ON o.OrderID = d.OrderID
    JOIN dbo.DeliveryEmployees AS de ON de.DeliveryEmployeeID = d.DeliveryEmployeeID
    JOIN dbo.Employees AS e ON e.EmployeeID = de.DeliveryEmployeeID
    WHERE d.DeliveryStartTimeUTC IS NOT NULL
      AND
      (
          (o.OrderStatusID = 5 AND d.DeliveryEndTimeUTC IS NOT NULL AND
           DATEDIFF_BIG(millisecond, d.DeliveryStartTimeUTC, d.DeliveryEndTimeUTC) > @ThresholdMilliseconds)
          OR
          (@IncludeActiveOverdue = 1 AND o.OrderStatusID = 4 AND d.DeliveryEndTimeUTC IS NULL AND
           DATEDIFF_BIG(millisecond, d.DeliveryStartTimeUTC, @NowUTC) > @ThresholdMilliseconds)
      )
    ORDER BY d.DeliveryStartTimeUTC, o.OrderID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_EnrollRestaurantAccount
    @RestaurantID int,
    @Username nvarchar(256),
    @PasswordHash nvarchar(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Username IS NULL OR LEN(LTRIM(RTRIM(@Username))) = 0
        THROW 51170, 'Username is required.', 1;
    IF @PasswordHash IS NULL OR LEFT(@PasswordHash, 10) <> N'$argon2id$' OR LEN(@PasswordHash) < 40
        THROW 51171, 'Supply an Argon2id PHC hash produced by the application; plaintext passwords are not accepted.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.Restaurants WITH (UPDLOCK, HOLDLOCK)
            WHERE RestaurantID = @RestaurantID AND IsActive = 1
        )
            THROW 51175, 'Only an active restaurant can be enrolled for an account.', 1;

        INSERT dbo.RestaurantAccounts (RestaurantID, Username, PasswordHash)
        VALUES (@RestaurantID, @Username, @PasswordHash);
        INSERT dbo.RestaurantAccountAudit (RestaurantID, EventType, ActorName)
        VALUES (@RestaurantID, 'ENROLLED', ORIGINAL_LOGIN());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ResetRestaurantPasswordHash
    @RestaurantID int,
    @PasswordHash nvarchar(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @PasswordHash IS NULL OR LEFT(@PasswordHash, 10) <> N'$argon2id$' OR LEN(@PasswordHash) < 40
        THROW 51172, 'Supply an Argon2id PHC hash produced by the application; plaintext passwords are not accepted.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.RestaurantAccounts WITH (UPDLOCK, HOLDLOCK)
           SET PasswordHash = @PasswordHash, UpdatedAtUTC = SYSUTCDATETIME()
         WHERE RestaurantID = @RestaurantID AND IsActive = 1;
        IF @@ROWCOUNT <> 1
            THROW 51173, 'An active restaurant account was not found.', 1;
        INSERT dbo.RestaurantAccountAudit (RestaurantID, EventType, ActorName)
        VALUES (@RestaurantID, 'RESET', ORIGINAL_LOGIN());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DisableRestaurantAccount
    @RestaurantID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.RestaurantAccounts WITH (UPDLOCK, HOLDLOCK)
           SET IsActive = 0, UpdatedAtUTC = SYSUTCDATETIME()
         WHERE RestaurantID = @RestaurantID AND IsActive = 1;
        IF @@ROWCOUNT <> 1
            THROW 51174, 'An active restaurant account was not found.', 1;
        INSERT dbo.RestaurantAccountAudit (RestaurantID, EventType, ActorName)
        VALUES (@RestaurantID, 'DISABLED', ORIGINAL_LOGIN());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
