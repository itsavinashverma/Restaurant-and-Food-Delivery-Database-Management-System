/* Synthetic, transactional demo seed. Install DDL, triggers, procedures and views first.
   This seed requires an empty project schema and refuses to append to existing data.
   Restaurant, customer and menu IDs are explicit and stable; order IDs come from a sequence
   and are captured by output parameters so failed/retried runs cannot mislink child rows. */
USE [DMDDFinalProjectDB];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.Locations) OR EXISTS (SELECT 1 FROM dbo.Restaurants) OR EXISTS (SELECT 1 FROM dbo.Customers)
   OR EXISTS (SELECT 1 FROM dbo.Employees) OR EXISTS (SELECT 1 FROM dbo.MenuItems) OR EXISTS (SELECT 1 FROM dbo.RestaurantWastage)
   OR EXISTS (SELECT 1 FROM dbo.Orders) OR EXISTS (SELECT 1 FROM dbo.OrderLines) OR EXISTS (SELECT 1 FROM dbo.Delivery)
   OR EXISTS (SELECT 1 FROM dbo.DineInOrders) OR EXISTS (SELECT 1 FROM dbo.Feedback) OR EXISTS (SELECT 1 FROM dbo.Payments)
    THROW 51300, 'The demo seed requires an empty project schema. Use a new disposable database or restore a clean backup.', 1;

CREATE TABLE #SeedOrderMap
(
    CustomerID int NOT NULL PRIMARY KEY,
    RestaurantID int NOT NULL,
    OrderID int NOT NULL UNIQUE,
    ServiceType char(2) NOT NULL,
    OrderTimeUTC datetime2(3) NOT NULL
);

DECLARE @OrderLines dbo.OrderLineInput;
DECLARE @NewOrderID int;
DECLARE @TotalAmount decimal(12,2);
DECLARE @SeedOrderTime datetime2(3);
DECLARE @DeliveryStart datetime2(3);
DECLARE @DeliveryEnd datetime2(3);
DECLARE @BaseTime datetime2(3) = DATEADD(hour, -8, SYSUTCDATETIME());

BEGIN TRY
    BEGIN TRANSACTION

    INSERT dbo.Locations (ZipCode, City) VALUES
        ('02215', N'Boston'),
        ('02115', N'Boston'),
        ('02145', N'Medford'),
        ('02129', N'Cambridge'),
        ('02147', N'Somerville'),
        ('02148', N'Malden');

    SET IDENTITY_INSERT dbo.Restaurants ON;
    BEGIN TRY
        INSERT dbo.Restaurants (RestaurantID, RestaurantName, StreetAddress, ZipCode, PhoneNumber, Cuisine) VALUES
            (1, N'Demo Restaurant 01', N'101 Example Street', '02215', '2025550101', N'Indian'),
            (2, N'Demo Restaurant 02', N'102 Example Street', '02115', '2025550102', N'American'),
            (3, N'Demo Restaurant 03', N'103 Example Street', '02215', '2025550103', N'Thai'),
            (4, N'Demo Restaurant 04', N'104 Example Street', '02215', '2025550104', N'Seafood'),
            (5, N'Demo Restaurant 05', N'105 Example Street', '02215', '2025550105', N'American'),
            (6, N'Demo Restaurant 06', N'106 Example Street', '02145', '2025550106', N'Mediterranean'),
            (7, N'Demo Restaurant 07', N'107 Example Street', '02129', '2025550107', N'American'),
            (8, N'Demo Restaurant 08', N'108 Example Street', '02147', '2025550108', N'Japanese'),
            (9, N'Demo Restaurant 09', N'109 Example Street', '02148', '2025550109', N'French'),
            (10, N'Demo Restaurant 10', N'110 Example Street', '02215', '2025550110', N'Seafood'),
            (11, N'Demo Restaurant 11', N'111 Example Street', '02115', '2025550111', N'American'),
            (12, N'Demo Restaurant 12', N'112 Example Street', '02148', '2025550112', N'Italian'),
            (13, N'Demo Restaurant 13', N'113 Example Street', '02145', '2025550113', N'Seafood'),
            (14, N'Demo Restaurant 14', N'114 Example Street', '02215', '2025550114', N'Japanese'),
            (15, N'Demo Restaurant 15', N'115 Example Street', '02115', '2025550115', N'American');
        SET IDENTITY_INSERT dbo.Restaurants OFF;
    END TRY
    BEGIN CATCH
        SET IDENTITY_INSERT dbo.Restaurants OFF;
        THROW;
    END CATCH;

    SET IDENTITY_INSERT dbo.Customers ON;
    BEGIN TRY
        INSERT dbo.Customers (CustomerID, CustomerName, StreetAddress, ZipCode, PhoneNumber) VALUES
            (1, N'Demo Customer 01', N'201 Sample Avenue', '02215', '2025550116'),
            (2, N'Demo Customer 02', N'202 Sample Avenue', '02129', '2025550117'),
            (3, N'Demo Customer 03', N'203 Sample Avenue', '02145', '2025550118'),
            (4, N'Demo Customer 04', N'204 Sample Avenue', '02147', '2025550119'),
            (5, N'Demo Customer 05', N'205 Sample Avenue', '02148', '2025550120'),
            (6, N'Demo Customer 06', N'206 Sample Avenue', '02215', '2025550121'),
            (7, N'Demo Customer 07', N'207 Sample Avenue', '02129', '2025550122'),
            (8, N'Demo Customer 08', N'208 Sample Avenue', '02129', '2025550123'),
            (9, N'Demo Customer 09', N'209 Sample Avenue', '02145', '2025550124'),
            (10, N'Demo Customer 10', N'210 Sample Avenue', '02147', '2025550125'),
            (11, N'Demo Customer 11', N'211 Sample Avenue', '02148', '2025550126'),
            (12, N'Demo Customer 12', N'212 Sample Avenue', '02215', '2025550127'),
            (13, N'Demo Customer 13', N'213 Sample Avenue', '02129', '2025550128'),
            (14, N'Demo Customer 14', N'214 Sample Avenue', '02147', '2025550129'),
            (15, N'Demo Customer 15', N'215 Sample Avenue', '02129', '2025550130');
        SET IDENTITY_INSERT dbo.Customers OFF;
    END TRY
    BEGIN CATCH
        SET IDENTITY_INSERT dbo.Customers OFF;
        THROW;
    END CATCH;

    /* Employee IDs are supplied by the demo HR source. The set-based trigger creates role rows. */
    INSERT dbo.Employees (EmployeeID, RestaurantID, EmployeeName, StreetAddress, ZipCode, PhoneNumber, Salary, EmployeeType) VALUES
        (1, 1, N'Demo Employee 001', N'301 Example Road', '02129', '2025550131', 1500.00, 'W'),
        (2, 1, N'Demo Employee 002', N'302 Example Road', '02147', '2025550132', 1400.00, 'C'),
        (3, 2, N'Demo Employee 003', N'303 Example Road', '02148', '2025550133', 1500.00, 'D'),
        (4, 2, N'Demo Employee 004', N'304 Example Road', '02129', '2025550134', 1000.00, 'W'),
        (5, 3, N'Demo Employee 005', N'305 Example Road', '02215', '2025550135', 1200.00, 'C'),
        (6, 3, N'Demo Employee 006', N'306 Example Road', '02215', '2025550136', 1500.00, 'D'),
        (7, 4, N'Demo Employee 007', N'307 Example Road', '02148', '2025550137', 1200.00, 'W'),
        (8, 4, N'Demo Employee 008', N'308 Example Road', '02147', '2025550138', 1300.00, 'C'),
        (9, 5, N'Demo Employee 009', N'309 Example Road', '02145', '2025550139', 1000.00, 'D'),
        (10, 5, N'Demo Employee 010', N'310 Example Road', '02129', '2025550140', 1900.00, 'W'),
        (11, 6, N'Demo Employee 011', N'311 Example Road', '02215', '2025550141', 1700.00, 'C'),
        (12, 6, N'Demo Employee 012', N'312 Example Road', '02215', '2025550142', 1000.00, 'D'),
        (13, 7, N'Demo Employee 013', N'313 Example Road', '02129', '2025550143', 1290.00, 'W'),
        (14, 7, N'Demo Employee 014', N'314 Example Road', '02148', '2025550144', 1300.00, 'C'),
        (15, 8, N'Demo Employee 015', N'315 Example Road', '02147', '2025550145', 1400.00, 'D'),
        (16, 8, N'Demo Employee 016', N'316 Example Road', '02145', '2025550146', 1500.00, 'W'),
        (17, 9, N'Demo Employee 017', N'317 Example Road', '02129', '2025550147', 1600.00, 'C'),
        (18, 9, N'Demo Employee 018', N'318 Example Road', '02115', '2025550148', 1700.00, 'D'),
        (19, 10, N'Demo Employee 019', N'319 Example Road', '02215', '2025550149', 1800.00, 'W'),
        (20, 10, N'Demo Employee 020', N'320 Example Road', '02148', '2025550150', 1900.00, 'C'),
        (21, 11, N'Demo Employee 021', N'321 Example Road', '02147', '2025550151', 1500.00, 'D'),
        (22, 11, N'Demo Employee 022', N'322 Example Road', '02145', '2025550152', 1341.00, 'W'),
        (23, 12, N'Demo Employee 023', N'323 Example Road', '02129', '2025550153', 1200.00, 'C'),
        (24, 12, N'Demo Employee 024', N'324 Example Road', '02115', '2025550154', 1100.00, 'D'),
        (25, 13, N'Demo Employee 025', N'325 Example Road', '02215', '2025550155', 1000.00, 'W'),
        (26, 13, N'Demo Employee 026', N'326 Example Road', '02148', '2025550156', 1100.00, 'C'),
        (27, 14, N'Demo Employee 027', N'327 Example Road', '02147', '2025550157', 1000.00, 'D'),
        (28, 14, N'Demo Employee 028', N'328 Example Road', '02145', '2025550158', 1500.00, 'W'),
        (29, 15, N'Demo Employee 029', N'329 Example Road', '02129', '2025550159', 1900.00, 'C'),
        (30, 15, N'Demo Employee 030', N'330 Example Road', '02115', '2025550160', 1211.00, 'D');

    SET IDENTITY_INSERT dbo.MenuItems ON;
    BEGIN TRY
        INSERT dbo.MenuItems (MenuItemID, RestaurantID, MenuItemCode, MenuItemName, Price, IsAvailable) VALUES
            (1, 1, 'R01-M01', N'Chicken Tandoori', 10.00, 1),
            (2, 1, 'R01-M02', N'Chicken Biryani', 10.00, 1),
            (3, 1, 'R01-M03', N'Chicken Shawarma', 5.00, 1),
            (4, 1, 'R01-M04', N'Mutton Biryani', 11.50, 1),
            (5, 1, 'R01-M05', N'Daal Rice', 8.00, 1),
            (6, 2, 'R02-M01', N'Spicy Chicken Burger', 18.95, 1),
            (7, 2, 'R02-M02', N'Louisiana Chicken Pasta', 21.95, 1),
            (8, 2, 'R02-M03', N'Jambalaya Chicken Pasta', 20.50, 1),
            (9, 3, 'R03-M01', N'Funyuns', 10.60, 1),
            (10, 3, 'R03-M02', N'Donut', 12.30, 1),
            (11, 3, 'R03-M03', N'Double Cheeseburger', 14.52, 1),
            (12, 4, 'R04-M01', N'Hash Browns', 10.30, 1),
            (13, 4, 'R04-M02', N'Hamburger', 16.30, 1),
            (14, 4, 'R04-M03', N'Strawberry Pie', 11.40, 1),
            (15, 5, 'R05-M01', N'Pistachio Muffin', 2.36, 1),
            (16, 5, 'R05-M02', N'Teddy Grahams', 5.12, 1),
            (17, 5, 'R05-M03', N'Root Beer Float', 4.68, 1),
            (18, 6, 'R06-M01', N'Spring Roll', 12.04, 1),
            (19, 6, 'R06-M02', N'Spring Roll', 10.04, 1),
            (20, 6, 'R06-M03', N'Alligator Jerky', 5.90, 1),
            (21, 7, 'R07-M01', N'Avocado Paste', 5.00, 1),
            (22, 7, 'R07-M02', N'Grilled Cheese Sandwich', 3.00, 1),
            (23, 7, 'R07-M03', N'Chicken Pot Pie', 10.00, 1),
            (24, 8, 'R08-M01', N'Mozzarella Sticks', 12.41, 1),
            (25, 8, 'R08-M02', N'Stromboli', 12.63, 1),
            (26, 8, 'R08-M03', N'Crab Rangoon', 12.03, 1),
            (27, 9, 'R09-M01', N'Egg Rolls', 12.36, 1),
            (28, 9, 'R09-M02', N'Oatmeal Raisin Cookies', 10.30, 1),
            (29, 9, 'R09-M03', N'Chocolate Cake', 12.50, 1),
            (30, 10, 'R10-M01', N'Daal Rice', 1.14, 1),
            (31, 10, 'R10-M02', N'Pulled Pork', 8.02, 1),
            (32, 10, 'R10-M03', N'Carbonara', 9.63, 1),
            (33, 11, 'R11-M01', N'Mexican Street Corn', 12.54, 1),
            (34, 11, 'R11-M02', N'Lemon Cookies', 14.12, 1),
            (35, 11, 'R11-M03', N'Quesadillas', 17.25, 1),
            (36, 12, 'R12-M01', N'Japanese Curry', 14.96, 1),
            (37, 12, 'R12-M02', N'Margherita Pizza', 10.23, 1),
            (38, 12, 'R12-M03', N'Cream Tea', 17.25, 1),
            (39, 13, 'R13-M01', N'Tortilla Chips', 10.23, 1),
            (40, 13, 'R13-M02', N'Chow Mein', 11.02, 1),
            (41, 13, 'R13-M03', N'Chicken Pot Pie', 14.36, 1),
            (42, 14, 'R14-M01', N'Bruschetta', 15.21, 1),
            (43, 14, 'R14-M02', N'Potato Skins', 17.23, 1),
            (44, 14, 'R14-M03', N'Daal Rice', 4.69, 1),
            (45, 15, 'R15-M01', N'Hamburger Pizza', 5.23, 1),
            (46, 15, 'R15-M02', N'Fried Chicken', 14.30, 1),
            (47, 15, 'R15-M03', N'Oysters Rockefeller', 13.69, 1);
        SET IDENTITY_INSERT dbo.MenuItems OFF;
    END TRY
    BEGIN CATCH
        SET IDENTITY_INSERT dbo.MenuItems OFF;
        THROW;
    END CATCH;

    INSERT dbo.RestaurantWastage (RestaurantID, DateOfWastage, WastageQuantityInPounds) VALUES
        (1, DATEFROMPARTS(2021, 1, 1), 1.25),
        (1, DATEFROMPARTS(2021, 1, 2), 2.26),
        (1, DATEFROMPARTS(2021, 1, 3), 2.23),
        (1, DATEFROMPARTS(2021, 1, 4), 3.24),
        (1, DATEFROMPARTS(2021, 1, 5), 3.54),
        (1, DATEFROMPARTS(2021, 1, 6), 1.26),
        (1, DATEFROMPARTS(2021, 1, 7), 3.54),
        (1, DATEFROMPARTS(2021, 1, 8), 3.69),
        (1, DATEFROMPARTS(2021, 1, 9), 2.98),
        (1, DATEFROMPARTS(2021, 1, 10), 3.41),
        (1, DATEFROMPARTS(2021, 1, 11), 3.67),
        (1, DATEFROMPARTS(2021, 1, 12), 4.54),
        (1, DATEFROMPARTS(2021, 1, 13), 4.21),
        (1, DATEFROMPARTS(2021, 1, 14), 2.36),
        (1, DATEFROMPARTS(2021, 1, 15), 2.14),
        (1, DATEFROMPARTS(2021, 1, 16), 2.78),
        (1, DATEFROMPARTS(2021, 1, 17), 3.97),
        (1, DATEFROMPARTS(2021, 1, 18), 3.41),
        (1, DATEFROMPARTS(2021, 1, 19), 5.80),
        (1, DATEFROMPARTS(2021, 1, 20), 4.12),
        (1, DATEFROMPARTS(2021, 1, 21), 3.50),
        (1, DATEFROMPARTS(2021, 1, 22), 4.12),
        (1, DATEFROMPARTS(2021, 1, 23), 4.19),
        (1, DATEFROMPARTS(2021, 1, 24), 4.21),
        (1, DATEFROMPARTS(2021, 1, 25), 3.64),
        (1, DATEFROMPARTS(2021, 1, 26), 3.24),
        (1, DATEFROMPARTS(2021, 1, 27), 4.17),
        (1, DATEFROMPARTS(2021, 1, 28), 5.21),
        (1, DATEFROMPARTS(2021, 1, 29), 2.17),
        (1, DATEFROMPARTS(2021, 1, 30), 2.36),
        (1, DATEFROMPARTS(2021, 1, 31), 3.21),
        (2, DATEFROMPARTS(2021, 1, 1), 26.39),
        (2, DATEFROMPARTS(2021, 1, 2), 25.64),
        (2, DATEFROMPARTS(2021, 1, 3), 31.47),
        (2, DATEFROMPARTS(2021, 1, 4), 29.98),
        (2, DATEFROMPARTS(2021, 1, 5), 22.69),
        (2, DATEFROMPARTS(2021, 1, 6), 22.14),
        (2, DATEFROMPARTS(2021, 1, 7), 24.69),
        (2, DATEFROMPARTS(2021, 1, 8), 23.54),
        (2, DATEFROMPARTS(2021, 1, 9), 21.22),
        (2, DATEFROMPARTS(2021, 1, 10), 23.65),
        (2, DATEFROMPARTS(2021, 1, 11), 21.57),
        (2, DATEFROMPARTS(2021, 1, 12), 26.34),
        (2, DATEFROMPARTS(2021, 1, 13), 29.96),
        (2, DATEFROMPARTS(2021, 1, 14), 30.25),
        (2, DATEFROMPARTS(2021, 1, 15), 24.07),
        (2, DATEFROMPARTS(2021, 1, 16), 22.54),
        (2, DATEFROMPARTS(2021, 1, 17), 23.69),
        (2, DATEFROMPARTS(2021, 1, 18), 21.58),
        (2, DATEFROMPARTS(2021, 1, 19), 26.39),
        (2, DATEFROMPARTS(2021, 1, 20), 25.47),
        (2, DATEFROMPARTS(2021, 1, 21), 27.47),
        (2, DATEFROMPARTS(2021, 1, 22), 25.98),
        (2, DATEFROMPARTS(2021, 1, 23), 100.00),
        (2, DATEFROMPARTS(2021, 1, 24), 23.15),
        (2, DATEFROMPARTS(2021, 1, 25), 24.69),
        (2, DATEFROMPARTS(2021, 1, 26), 19.25),
        (2, DATEFROMPARTS(2021, 1, 27), 25.30),
        (2, DATEFROMPARTS(2021, 1, 28), 30.90),
        (2, DATEFROMPARTS(2021, 1, 29), 16.32),
        (2, DATEFROMPARTS(2021, 1, 30), 23.91),
        (2, DATEFROMPARTS(2021, 1, 31), 25.50),
        (3, DATEFROMPARTS(2021, 1, 1), 10.98),
        (3, DATEFROMPARTS(2021, 1, 2), 10.23),
        (3, DATEFROMPARTS(2021, 1, 3), 13.25),
        (3, DATEFROMPARTS(2021, 1, 4), 14.25),
        (3, DATEFROMPARTS(2021, 1, 5), 22.60),
        (3, DATEFROMPARTS(2021, 1, 6), 22.36),
        (3, DATEFROMPARTS(2021, 1, 7), 15.87),
        (3, DATEFROMPARTS(2021, 1, 8), 21.36),
        (3, DATEFROMPARTS(2021, 1, 9), 20.69),
        (3, DATEFROMPARTS(2021, 1, 10), 15.87),
        (3, DATEFROMPARTS(2021, 1, 11), 19.21),
        (3, DATEFROMPARTS(2021, 1, 12), 13.69),
        (3, DATEFROMPARTS(2021, 1, 13), 14.74),
        (3, DATEFROMPARTS(2021, 1, 14), 15.36),
        (3, DATEFROMPARTS(2021, 1, 15), 14.69),
        (3, DATEFROMPARTS(2021, 1, 16), 12.54),
        (3, DATEFROMPARTS(2021, 1, 17), 19.67),
        (3, DATEFROMPARTS(2021, 1, 18), 14.87),
        (3, DATEFROMPARTS(2021, 1, 19), 15.25),
        (3, DATEFROMPARTS(2021, 1, 20), 13.65),
        (3, DATEFROMPARTS(2021, 1, 21), 21.47),
        (3, DATEFROMPARTS(2021, 1, 22), 20.36),
        (3, DATEFROMPARTS(2021, 1, 23), 15.47),
        (3, DATEFROMPARTS(2021, 1, 24), 16.52),
        (3, DATEFROMPARTS(2021, 1, 25), 17.89),
        (3, DATEFROMPARTS(2021, 1, 26), 20.36),
        (3, DATEFROMPARTS(2021, 1, 27), 11.36),
        (3, DATEFROMPARTS(2021, 1, 28), 20.69),
        (3, DATEFROMPARTS(2021, 1, 29), 16.84),
        (3, DATEFROMPARTS(2021, 1, 30), 12.69),
        (3, DATEFROMPARTS(2021, 1, 31), 10.98),
        (4, DATEFROMPARTS(2021, 1, 1), 5.30),
        (4, DATEFROMPARTS(2021, 1, 2), 2.69),
        (4, DATEFROMPARTS(2021, 1, 3), 2.58),
        (4, DATEFROMPARTS(2021, 1, 4), 2.03),
        (4, DATEFROMPARTS(2021, 1, 5), 1.64),
        (4, DATEFROMPARTS(2021, 1, 6), 5.21),
        (4, DATEFROMPARTS(2021, 1, 7), 1.28),
        (4, DATEFROMPARTS(2021, 1, 8), 3.69),
        (4, DATEFROMPARTS(2021, 1, 9), 2.12),
        (4, DATEFROMPARTS(2021, 1, 10), 2.68),
        (4, DATEFROMPARTS(2021, 1, 11), 2.54),
        (4, DATEFROMPARTS(2021, 1, 12), 6.90),
        (4, DATEFROMPARTS(2021, 1, 13), 1.02),
        (4, DATEFROMPARTS(2021, 1, 14), 2.52),
        (4, DATEFROMPARTS(2021, 1, 15), 4.15),
        (4, DATEFROMPARTS(2021, 1, 16), 2.36),
        (4, DATEFROMPARTS(2021, 1, 17), 2.14),
        (4, DATEFROMPARTS(2021, 1, 18), 3.26),
        (4, DATEFROMPARTS(2021, 1, 19), 2.54),
        (4, DATEFROMPARTS(2021, 1, 20), 3.87),
        (4, DATEFROMPARTS(2021, 1, 21), 2.32),
        (4, DATEFROMPARTS(2021, 1, 22), 3.17),
        (4, DATEFROMPARTS(2021, 1, 23), 1.29),
        (4, DATEFROMPARTS(2021, 1, 24), 0.20),
        (4, DATEFROMPARTS(2021, 1, 25), 5.20),
        (4, DATEFROMPARTS(2021, 1, 26), 3.65),
        (4, DATEFROMPARTS(2021, 1, 27), 2.10),
        (4, DATEFROMPARTS(2021, 1, 28), 7.80),
        (4, DATEFROMPARTS(2021, 1, 29), 1.20),
        (4, DATEFROMPARTS(2021, 1, 30), 5.69),
        (4, DATEFROMPARTS(2021, 1, 31), 4.20),
        (5, DATEFROMPARTS(2021, 1, 1), 0.52),
        (5, DATEFROMPARTS(2021, 1, 2), 7.05),
        (5, DATEFROMPARTS(2021, 1, 3), 5.63),
        (5, DATEFROMPARTS(2021, 1, 4), 10.23),
        (5, DATEFROMPARTS(2021, 1, 5), 9.63),
        (5, DATEFROMPARTS(2021, 1, 6), 4.21),
        (5, DATEFROMPARTS(2021, 1, 7), 8.97),
        (5, DATEFROMPARTS(2021, 1, 8), 5.24),
        (5, DATEFROMPARTS(2021, 1, 9), 13.02),
        (5, DATEFROMPARTS(2021, 1, 10), 7.14),
        (5, DATEFROMPARTS(2021, 1, 11), 5.29),
        (5, DATEFROMPARTS(2021, 1, 12), 1.05),
        (5, DATEFROMPARTS(2021, 1, 13), 6.32),
        (5, DATEFROMPARTS(2021, 1, 14), 7.15),
        (5, DATEFROMPARTS(2021, 1, 15), 5.62),
        (5, DATEFROMPARTS(2021, 1, 16), 9.23),
        (5, DATEFROMPARTS(2021, 1, 17), 11.25),
        (5, DATEFROMPARTS(2021, 1, 18), 6.32),
        (5, DATEFROMPARTS(2021, 1, 19), 7.41),
        (5, DATEFROMPARTS(2021, 1, 20), 9.63),
        (5, DATEFROMPARTS(2021, 1, 21), 7.50),
        (5, DATEFROMPARTS(2021, 1, 22), 5.60),
        (5, DATEFROMPARTS(2021, 1, 23), 1.00),
        (5, DATEFROMPARTS(2021, 1, 24), 2.00),
        (5, DATEFROMPARTS(2021, 1, 25), 9.36),
        (5, DATEFROMPARTS(2021, 1, 26), 5.78),
        (5, DATEFROMPARTS(2021, 1, 27), 5.23),
        (5, DATEFROMPARTS(2021, 1, 28), 10.64),
        (5, DATEFROMPARTS(2021, 1, 29), 9.42),
        (5, DATEFROMPARTS(2021, 1, 30), 15.87),
        (5, DATEFROMPARTS(2021, 1, 31), 10.30);

    DECLARE @FeedbackSeed TABLE
    (
        CustomerID int NOT NULL PRIMARY KEY,
        RestaurantID int NOT NULL,
        FeedbackDescription nvarchar(1000) NOT NULL,
        FoodRating tinyint NOT NULL,
        ServiceRating tinyint NOT NULL
    );

    INSERT @FeedbackSeed (CustomerID, RestaurantID, FeedbackDescription, FoodRating, ServiceRating) VALUES
        (1, 1, N'Synthetic sample review for order 01.', 3, 4),
        (2, 2, N'Synthetic sample review for order 02.', 4, 4),
        (3, 3, N'Synthetic sample review for order 03.', 4, 5),
        (4, 4, N'Synthetic sample review for order 04.', 5, 4),
        (5, 5, N'Synthetic sample review for order 05.', 4, 4),
        (6, 6, N'Synthetic sample review for order 06.', 3, 3),
        (7, 7, N'Synthetic sample review for order 07.', 4, 3),
        (8, 8, N'Synthetic sample review for order 08.', 3, 3),
        (9, 9, N'Synthetic sample review for order 09.', 1, 1),
        (10, 10, N'Synthetic sample review for order 10.', 5, 5),
        (11, 11, N'Synthetic sample review for order 11.', 4, 3),
        (12, 12, N'Synthetic sample review for order 12.', 2, 4),
        (13, 13, N'Synthetic sample review for order 13.', 3, 5),
        (14, 14, N'Synthetic sample review for order 14.', 5, 3),
        (15, 15, N'Synthetic sample review for order 15.', 1, 2);

    /* Orders are created through the transactional procedure so each line snapshots its menu price. */

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (1, 2), (2, 1);
    SET @SeedOrderTime = DATEADD(minute, 1, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 1, @RestaurantID = 1, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (1, 1, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 3;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -3489, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (6, 2), (7, 1);
    SET @SeedOrderTime = DATEADD(minute, 2, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 2, @RestaurantID = 2, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (2, 2, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 6;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -1869, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (9, 2), (10, 1);
    SET @SeedOrderTime = DATEADD(minute, 3, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 3, @RestaurantID = 3, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (3, 3, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 9;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -3369, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (12, 2), (13, 1);
    SET @SeedOrderTime = DATEADD(minute, 4, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 4, @RestaurantID = 4, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (4, 4, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 12;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -729, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (15, 2), (16, 1);
    SET @SeedOrderTime = DATEADD(minute, 5, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 5, @RestaurantID = 5, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (5, 5, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 15;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -849, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (18, 2), (19, 1);
    SET @SeedOrderTime = DATEADD(minute, 6, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 6, @RestaurantID = 6, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (6, 6, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 18;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -2589, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (21, 2), (22, 1);
    SET @SeedOrderTime = DATEADD(minute, 7, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 7, @RestaurantID = 7, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (7, 7, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 21;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -1269, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (24, 2), (25, 1);
    SET @SeedOrderTime = DATEADD(minute, 8, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 8, @RestaurantID = 8, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (8, 8, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 24;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -4989, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (27, 2), (28, 1);
    SET @SeedOrderTime = DATEADD(minute, 9, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 9, @RestaurantID = 9, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (9, 9, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 27;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -3249, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (30, 2), (31, 1);
    SET @SeedOrderTime = DATEADD(minute, 10, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 10, @RestaurantID = 10, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (10, 10, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 30;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -849, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (33, 2), (34, 1);
    SET @SeedOrderTime = DATEADD(minute, 131, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 11, @RestaurantID = 11, @ServiceType = 'DI',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = 22, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (11, 11, @NewOrderID, 'DI', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 5;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (36, 2), (37, 1);
    SET @SeedOrderTime = DATEADD(minute, 132, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 12, @RestaurantID = 12, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (12, 12, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 12;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -2700, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (39, 2), (40, 1);
    SET @SeedOrderTime = DATEADD(minute, 133, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 13, @RestaurantID = 13, @ServiceType = 'DI',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = 25, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (13, 13, @NewOrderID, 'DI', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 5;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (42, 2), (43, 1);
    SET @SeedOrderTime = DATEADD(minute, 134, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 14, @RestaurantID = 14, @ServiceType = 'DI',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = 28, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (14, 14, @NewOrderID, 'DI', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 5;

    DELETE FROM @OrderLines;
    INSERT @OrderLines (MenuItemID, OrderQuantity) VALUES (45, 2), (46, 1);
    SET @SeedOrderTime = DATEADD(minute, 255, @BaseTime);
    EXEC dbo.usp_CreateOrder @CustomerID = 15, @RestaurantID = 15, @ServiceType = 'DL',
         @OrderLines = @OrderLines, @OrderID = @NewOrderID OUTPUT,
         @WaiterID = NULL, @OrderTimeUTC = @SeedOrderTime;
    INSERT #SeedOrderMap (CustomerID, RestaurantID, OrderID, ServiceType, OrderTimeUTC) VALUES (15, 15, @NewOrderID, 'DL', @SeedOrderTime);
    EXEC dbo.usp_CalculateTotalAmount @OrderID = @NewOrderID, @TipAmount = 0.00, @TaxRate = 0.0000, @TotalAmount = @TotalAmount OUTPUT;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 2;
    EXEC dbo.usp_TransitionOrderStatus @OrderID = @NewOrderID, @NewOrderStatusID = 3;
    EXEC dbo.usp_AssignDelivery @OrderID = @NewOrderID, @DeliveryEmployeeID = 30;
    SET @DeliveryEnd = DATEADD(minute, -1, SYSUTCDATETIME());
    SET @DeliveryStart = DATEADD(second, -840, @DeliveryEnd);
    EXEC dbo.usp_StartDelivery @OrderID = @NewOrderID, @StartTimeUTC = @DeliveryStart;
    EXEC dbo.usp_CompleteDelivery @OrderID = @NewOrderID, @EndTimeUTC = @DeliveryEnd;

    INSERT dbo.Feedback (OrderID, CustomerID, FeedbackDescription, FoodRating, ServiceRating, CreatedAtUTC)
    SELECT m.OrderID, f.CustomerID, f.FeedbackDescription, f.FoodRating, f.ServiceRating, SYSUTCDATETIME()
    FROM @FeedbackSeed AS f
    JOIN #SeedOrderMap AS m ON m.CustomerID = f.CustomerID AND m.RestaurantID = f.RestaurantID;

    /* Stop and roll back if any expected relationship or finalized amount is missing. */
    IF (SELECT COUNT(*) FROM dbo.Restaurants) <> 15 OR (SELECT COUNT(*) FROM dbo.Customers) <> 15
       OR (SELECT COUNT(*) FROM dbo.Employees) <> 30 OR (SELECT COUNT(*) FROM dbo.MenuItems) <> 47
       OR (SELECT COUNT(*) FROM dbo.RestaurantWastage) <> 155 OR (SELECT COUNT(*) FROM dbo.Orders) <> 15
       OR (SELECT COUNT(*) FROM dbo.OrderLines) <> 30 OR (SELECT COUNT(*) FROM dbo.Delivery) <> 12
       OR (SELECT COUNT(*) FROM dbo.DineInOrders) <> 3 OR (SELECT COUNT(*) FROM dbo.Feedback) <> 15
       OR (SELECT COUNT(*) FROM dbo.Waiters) <> 10 OR (SELECT COUNT(*) FROM dbo.Chefs) <> 10
       OR (SELECT COUNT(*) FROM dbo.DeliveryEmployees) <> 10
        THROW 51301, 'A seeded table does not have its documented demo row count.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderStatusID <> 5 OR OrderAmount IS NULL)
        THROW 51302, 'Every seeded demo order must be fulfilled and have an exact finalized total.', 1;

    IF EXISTS (SELECT 1 FROM dbo.OrderLines AS line JOIN dbo.Orders AS o ON o.OrderID = line.OrderID
               JOIN dbo.MenuItems AS menu ON menu.MenuItemID = line.MenuItemID
               WHERE line.RestaurantID <> o.RestaurantID OR line.RestaurantID <> menu.RestaurantID)
        THROW 51303, 'A seeded order line crosses restaurant boundaries.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Feedback AS f JOIN dbo.Orders AS o ON o.OrderID = f.OrderID
               WHERE f.CustomerID <> o.CustomerID OR o.OrderStatusID <> 5)
        THROW 51304, 'A seeded review is not from the customer?s fulfilled order.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Delivery AS d JOIN dbo.Orders AS o ON o.OrderID = d.OrderID
               WHERE o.ServiceType <> 'DL' OR d.DeliveryStartTimeUTC < o.OrderTimeUTC
                  OR d.DeliveryEndTimeUTC < d.DeliveryStartTimeUTC)
        THROW 51305, 'A seeded delivery does not match its order service or timestamps.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Feedback AS f JOIN dbo.Orders AS o ON o.OrderID = f.OrderID
               LEFT JOIN dbo.Delivery AS d ON d.OrderID = o.OrderID
               WHERE f.CreatedAtUTC < o.OrderTimeUTC
                  OR (o.ServiceType = 'DL' AND f.CreatedAtUTC < d.DeliveryEndTimeUTC))
        THROW 51306, 'A seeded review cannot predate its order or completed delivery.', 1;

    COMMIT TRANSACTION;
    SELECT N'Seed loaded successfully.' AS SeedResult, 379 AS CoreBusinessRowCount;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
