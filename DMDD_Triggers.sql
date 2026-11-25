USE [DMDDFinalProjectDB];
GO

/* Each employee insert may contain many rows. EmployeeType is immutable so a
   subtype can never become stale; deactivate employees instead of retyping. */
CREATE OR ALTER TRIGGER dbo.trg_Employees_CreateSubtypes
ON dbo.Employees
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.Waiters (WaiterID, RestaurantID, Designation)
        SELECT EmployeeID, RestaurantID, NULL FROM inserted WHERE EmployeeType = 'W';
    INSERT dbo.Chefs (ChefID, Designation)
        SELECT EmployeeID, NULL FROM inserted WHERE EmployeeType = 'C';
    INSERT dbo.DeliveryEmployees (DeliveryEmployeeID, IsDeliveryPartnerAvailable)
        SELECT EmployeeID, 1 FROM inserted WHERE EmployeeType = 'D';
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Employees_TypeImmutable
ON dbo.Employees
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.EmployeeID = i.EmployeeID
        WHERE i.EmployeeType <> d.EmployeeType
    )
        THROW 51001, 'EmployeeType is immutable. Use the employee lifecycle process and preserve subtype history.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Waiters_TypeGuard
ON dbo.Waiters
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        LEFT JOIN dbo.Employees AS e ON e.EmployeeID = i.WaiterID
        WHERE e.EmployeeID IS NULL OR e.EmployeeType <> 'W' OR e.RestaurantID <> i.RestaurantID
    )
        THROW 51002, 'A waiter must reference a waiter employee at the same restaurant.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Chefs_TypeGuard
ON dbo.Chefs
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        LEFT JOIN dbo.Employees AS e ON e.EmployeeID = i.ChefID
        WHERE e.EmployeeID IS NULL OR e.EmployeeType <> 'C'
    )
        THROW 51003, 'A chef subtype must reference an employee whose type is C.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DeliveryEmployees_TypeGuard
ON dbo.DeliveryEmployees
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        LEFT JOIN dbo.Employees AS e ON e.EmployeeID = i.DeliveryEmployeeID
        WHERE e.EmployeeID IS NULL OR e.EmployeeType <> 'D'
    )
        THROW 51004, 'A delivery subtype must reference an employee whose type is D.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Waiters_PreventDelete
ON dbo.Waiters
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted AS d JOIN dbo.Employees AS e ON e.EmployeeID = d.WaiterID)
        THROW 51005, 'Employee subtype rows are managed by the employee lifecycle; deactivate the employee instead.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Chefs_PreventDelete
ON dbo.Chefs
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted AS d JOIN dbo.Employees AS e ON e.EmployeeID = d.ChefID)
        THROW 51006, 'Employee subtype rows are managed by the employee lifecycle; deactivate the employee instead.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DeliveryEmployees_PreventDelete
ON dbo.DeliveryEmployees
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted AS d JOIN dbo.Employees AS e ON e.EmployeeID = d.DeliveryEmployeeID)
        THROW 51007, 'Employee subtype rows are managed by the employee lifecycle; deactivate the employee instead.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Orders_RequirePendingOnInsert
ON dbo.Orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE OrderStatusID <> 1 OR OrderAmount IS NOT NULL)
        THROW 51008, 'New orders must start Pending and unfinalized.', 1;

    INSERT dbo.OrderStatusHistory (OrderID, OrderStatusID, ChangedAtUTC, ChangedBy)
        SELECT OrderID, OrderStatusID, SYSUTCDATETIME(), ORIGINAL_LOGIN()
        FROM inserted;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Orders_ValidateChanges
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.OrderID = i.OrderID
        WHERE i.CustomerID <> d.CustomerID
           OR i.RestaurantID <> d.RestaurantID
           OR i.ServiceType <> d.ServiceType
           OR i.OrderTimeUTC <> d.OrderTimeUTC
    )
        THROW 51009, 'Customer, restaurant, service type and creation time are immutable order attributes.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.OrderID = i.OrderID
        WHERE d.SubtotalAmount IS NOT NULL
          AND
          (
              ISNULL(i.SubtotalAmount, -1) <> ISNULL(d.SubtotalAmount, -1)
              OR ISNULL(i.TaxRate, -1) <> ISNULL(d.TaxRate, -1)
              OR ISNULL(i.TaxAmount, -1) <> ISNULL(d.TaxAmount, -1)
              OR ISNULL(i.TipAmount, -1) <> ISNULL(d.TipAmount, -1)
          )
    )
        THROW 51010, 'Finalized order amounts are immutable; use a separate adjustment or refund record.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.OrderID = i.OrderID
        WHERE i.OrderStatusID <> d.OrderStatusID
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.OrderStatusTransitions AS t
              WHERE t.FromStatusID = d.OrderStatusID AND t.ToStatusID = i.OrderStatusID
          )
    )
        THROW 51011, 'The requested order status transition is not allowed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        WHERE i.OrderStatusID IN (2, 3, 4, 5)
          AND (i.OrderAmount IS NULL OR NOT EXISTS
               (SELECT 1 FROM dbo.OrderLines AS ol WHERE ol.OrderID = i.OrderID))
    )
        THROW 51012, 'An order needs at least one line and a finalized amount before processing.', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        WHERE i.OrderStatusID = 4
          AND (i.ServiceType <> 'DL' OR NOT EXISTS
               (SELECT 1 FROM dbo.Delivery AS d WHERE d.OrderID = i.OrderID AND d.DeliveryStartTimeUTC IS NOT NULL))
    )
        THROW 51013, 'An in-transit order requires a started delivery.', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        WHERE i.OrderStatusID = 5
          AND
          (
              (i.ServiceType = 'DL' AND NOT EXISTS
                  (SELECT 1 FROM dbo.Delivery AS d WHERE d.OrderID = i.OrderID
                   AND d.DeliveryEmployeeID IS NOT NULL AND d.DeliveryEndTimeUTC IS NOT NULL))
              OR
              (i.ServiceType = 'DI' AND NOT EXISTS
                  (SELECT 1 FROM dbo.DineInOrders AS x WHERE x.OrderID = i.OrderID))
          )
    )
        THROW 51014, 'A fulfilled order must have a completed delivery or a dine-in visit record.', 1;

    INSERT dbo.OrderStatusHistory (OrderID, OrderStatusID, ChangedAtUTC, ChangedBy)
        SELECT i.OrderID, i.OrderStatusID, SYSUTCDATETIME(), ORIGINAL_LOGIN()
        FROM inserted AS i
        JOIN deleted AS d ON d.OrderID = i.OrderID
        WHERE i.OrderStatusID <> d.OrderStatusID;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_OrderLines_ValidateWrites
ON dbo.OrderLines
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        JOIN dbo.Orders AS o ON o.OrderID = i.OrderID
        WHERE o.OrderStatusID <> 1 OR o.SubtotalAmount IS NOT NULL
    )
        THROW 51015, 'Order lines can only be changed on an unfinalized Pending order.', 1;

    IF EXISTS
    (
        SELECT 1 FROM deleted AS d
        JOIN dbo.Orders AS o ON o.OrderID = d.OrderID
        WHERE o.OrderStatusID <> 1 OR o.SubtotalAmount IS NOT NULL
    )
        THROW 51016, 'Order lines cannot be removed or changed after finalization or processing.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.MenuItems AS m ON m.MenuItemID = i.MenuItemID AND m.RestaurantID = i.RestaurantID
        WHERE m.IsAvailable = 0
    )
        THROW 51017, 'Unavailable menu items cannot be added to an order.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.OrderID = i.OrderID AND d.MenuItemID = i.MenuItemID
        JOIN dbo.MenuItems AS m ON m.MenuItemID = i.MenuItemID AND m.RestaurantID = i.RestaurantID
        WHERE (d.OrderID IS NULL AND i.UnitPrice <> m.Price)
           OR (d.OrderID IS NOT NULL AND i.UnitPrice <> d.UnitPrice)
    )
        THROW 51018, 'UnitPrice must snapshot the current menu price when a line is created and cannot later be edited.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DineInOrders_RequireDineInService
ON dbo.DineInOrders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        JOIN dbo.Orders AS o ON o.OrderID = i.OrderID
        WHERE o.ServiceType <> 'DI'
    )
        THROW 51019, 'A dine-in visit can only reference a dine-in order.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Delivery_ValidateAndMaintainAvailability
ON dbo.Delivery
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.Orders AS o ON o.OrderID = i.OrderID
        WHERE o.ServiceType <> 'DL'
           OR (i.DeliveryStartTimeUTC IS NOT NULL AND i.DeliveryStartTimeUTC < o.OrderTimeUTC)
    )
        THROW 51020, 'A delivery must belong to a delivery order and cannot start before order creation.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.DeliveryEmployees AS de ON de.DeliveryEmployeeID = i.DeliveryEmployeeID
        JOIN dbo.Employees AS e ON e.EmployeeID = de.DeliveryEmployeeID
        WHERE e.EmployeeType <> 'D' OR (i.DeliveryEndTimeUTC IS NULL AND e.IsActive = 0)
    )
        THROW 51021, 'Only an employee with delivery role D can be assigned to a delivery.', 1;

    IF EXISTS
    (
        SELECT 1 FROM deleted AS old
        JOIN dbo.Orders AS o ON o.OrderID = old.OrderID
        LEFT JOIN dbo.Delivery AS currentRow ON currentRow.OrderID = old.OrderID
        WHERE o.OrderStatusID = 5
          AND (currentRow.OrderID IS NULL OR currentRow.DeliveryEndTimeUTC IS NULL)
    )
        THROW 51022, 'A fulfilled delivery cannot be deleted or returned to an incomplete state.', 1;

    ;WITH AffectedEmployees AS
    (
        SELECT DeliveryEmployeeID FROM inserted WHERE DeliveryEmployeeID IS NOT NULL
        UNION
        SELECT DeliveryEmployeeID FROM deleted WHERE DeliveryEmployeeID IS NOT NULL
    )
    UPDATE de
       SET IsDeliveryPartnerAvailable = CASE WHEN EXISTS
           (SELECT 1 FROM dbo.Delivery AS d
            WHERE d.DeliveryEmployeeID = de.DeliveryEmployeeID AND d.DeliveryEndTimeUTC IS NULL)
           THEN 0 ELSE 1 END
    FROM dbo.DeliveryEmployees AS de
    JOIN AffectedEmployees AS a ON a.DeliveryEmployeeID = de.DeliveryEmployeeID;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Feedback_CompletedOrderOnly
ON dbo.Feedback
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS f
        JOIN dbo.Orders AS o ON o.OrderID = f.OrderID AND o.CustomerID = f.CustomerID
        WHERE o.OrderStatusID <> 5
    )
        THROW 51023, 'Feedback is allowed only for the customer fulfilled order.', 1;
END;
GO
