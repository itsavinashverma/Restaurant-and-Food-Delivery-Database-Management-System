/* Optional read/report examples. Nothing here runs during schema installation. */
USE [DMDDFinalProjectDB];
GO

DECLARE @SeededOrderID int;
DECLARE @TotalAmount decimal(12,2);
SELECT @SeededOrderID = MIN(OrderID)
FROM dbo.Orders
WHERE CustomerID = 1;

IF @SeededOrderID IS NOT NULL
BEGIN
    SELECT @TotalAmount = OrderAmount
    FROM dbo.Orders
    WHERE OrderID = @SeededOrderID;
    SELECT @SeededOrderID AS OrderID, @TotalAmount AS FinalAmount;
END;
GO

/*
  For a new, still-Pending order only, capture the output like this:

  DECLARE @TotalAmount decimal(12,2);
  EXEC dbo.usp_CalculateTotalAmount
      @OrderID = @NewOrderID,
      @TipAmount = 3.89,
      @TaxRate = 0.0625,
      @TotalAmount = @TotalAmount OUTPUT;
  SELECT @NewOrderID AS OrderID, @TotalAmount AS FinalAmount;

  Do not finalize an already-finalized seed order a second time.
*/

EXEC dbo.usp_CalculateAndDisplayFoodWastageByRestaurants
    @RestaurantID = 1,
    @PeriodType = 'MONTH',
    @StartDate = '20210101',
    @EndDate = '20210131';
GO

EXEC dbo.usp_TopRestaurantsInArea @ZipCode = '02215';
GO

EXEC dbo.usp_CalculateFastestDelivery;
GO

EXEC dbo.usp_ListDeliveryViolations @ThresholdMinutes = 60, @IncludeActiveOverdue = 0;
GO
