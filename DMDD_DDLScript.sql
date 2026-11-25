/*
  Fresh-install schema for the restaurant and food-delivery demo.
  This script creates the database if needed and never drops existing data.
  It is a one-time baseline install; use a numbered migration for an existing
  deployment instead of rerunning this file.
*/
IF DB_ID(N'DMDDFinalProjectDB') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [DMDDFinalProjectDB]');
END;
GO

USE [DMDDFinalProjectDB];
GO

IF OBJECT_ID(N'dbo.SchemaVersion', N'U') IS NOT NULL
    THROW 51000, 'The project schema already exists. Do not rerun the baseline DDL.', 1;
GO

CREATE TABLE dbo.SchemaVersion
(
    SchemaVersionID int NOT NULL CONSTRAINT PK_SchemaVersion PRIMARY KEY,
    AppliedAtUTC datetime2(3) NOT NULL CONSTRAINT DF_SchemaVersion_AppliedAtUTC DEFAULT SYSUTCDATETIME(),
    Description nvarchar(200) NOT NULL
);
INSERT dbo.SchemaVersion (SchemaVersionID, Description)
VALUES (1, N'Initial corrected schema');
GO

CREATE TABLE dbo.Locations
(
    ZipCode varchar(5) NOT NULL,
    City nvarchar(100) NOT NULL,
    CONSTRAINT PK_Locations PRIMARY KEY (ZipCode),
    CONSTRAINT CK_Locations_ZipCode_US CHECK
    (
        LEN(ZipCode) = 5
        AND ZipCode COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%'
    ),
    CONSTRAINT CK_Locations_City_NotBlank CHECK (LEN(LTRIM(RTRIM(City))) > 0)
);
GO

CREATE TABLE dbo.Restaurants
(
    RestaurantID int IDENTITY(1,1) NOT NULL,
    RestaurantName nvarchar(200) NOT NULL,
    StreetAddress nvarchar(300) NULL,
    ZipCode varchar(5) NOT NULL,
    PhoneNumber varchar(10) NULL,
    Cuisine nvarchar(100) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Restaurants_IsActive DEFAULT (1),
    CONSTRAINT PK_Restaurants PRIMARY KEY (RestaurantID),
    CONSTRAINT FK_Restaurants_Locations FOREIGN KEY (ZipCode) REFERENCES dbo.Locations(ZipCode),
    CONSTRAINT CK_Restaurants_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(RestaurantName))) > 0),
    CONSTRAINT CK_Restaurants_Phone_US CHECK
    (
        PhoneNumber IS NULL OR
        (LEN(PhoneNumber) = 10 AND PhoneNumber COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%')
    )
);
GO

/* Authentication data is separate and stores only an Argon2id PHC string. */
CREATE TABLE dbo.RestaurantAccounts
(
    RestaurantID int NOT NULL,
    Username nvarchar(256) COLLATE Latin1_General_100_CI_AS NOT NULL,
    PasswordHash nvarchar(255) COLLATE Latin1_General_100_BIN2 NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_RestaurantAccounts_IsActive DEFAULT (1),
    CreatedAtUTC datetime2(3) NOT NULL CONSTRAINT DF_RestaurantAccounts_CreatedAtUTC DEFAULT SYSUTCDATETIME(),
    UpdatedAtUTC datetime2(3) NOT NULL CONSTRAINT DF_RestaurantAccounts_UpdatedAtUTC DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_RestaurantAccounts PRIMARY KEY (RestaurantID),
    CONSTRAINT UQ_RestaurantAccounts_Username UNIQUE (Username),
    CONSTRAINT FK_RestaurantAccounts_Restaurants FOREIGN KEY (RestaurantID) REFERENCES dbo.Restaurants(RestaurantID),
    CONSTRAINT CK_RestaurantAccounts_Username_NotBlank CHECK (LEN(LTRIM(RTRIM(Username))) > 0),
    CONSTRAINT CK_RestaurantAccounts_Argon2id CHECK
    (
        LEFT(PasswordHash, 10) = N'$argon2id$' AND LEN(PasswordHash) >= 40
    )
);

CREATE TABLE dbo.RestaurantAccountAudit
(
    AccountAuditID bigint IDENTITY(1,1) NOT NULL,
    RestaurantID int NOT NULL,
    EventType varchar(12) NOT NULL,
    EventAtUTC datetime2(3) NOT NULL CONSTRAINT DF_RestaurantAccountAudit_EventAtUTC DEFAULT SYSUTCDATETIME(),
    ActorName sysname NOT NULL,
    CONSTRAINT PK_RestaurantAccountAudit PRIMARY KEY (AccountAuditID),
    CONSTRAINT FK_RestaurantAccountAudit_Accounts FOREIGN KEY (RestaurantID) REFERENCES dbo.RestaurantAccounts(RestaurantID),
    CONSTRAINT CK_RestaurantAccountAudit_EventType CHECK (EventType IN ('ENROLLED', 'RESET', 'DISABLED'))
);
GO

/* Optional reversible-encryption example. It contains synthetic text only. */
CREATE TABLE dbo.EncryptionDemo
(
    DemoRecordID int NOT NULL,
    PayloadCipher varbinary(max) NULL,
    CONSTRAINT PK_EncryptionDemo PRIMARY KEY (DemoRecordID)
);
GO

CREATE TABLE dbo.RestaurantWastage
(
    RestaurantID int NOT NULL,
    DateOfWastage date NOT NULL,
    WastageQuantityInPounds decimal(8,2) NOT NULL,
    CONSTRAINT PK_RestaurantWastage PRIMARY KEY (RestaurantID, DateOfWastage),
    CONSTRAINT FK_RestaurantWastage_Restaurants FOREIGN KEY (RestaurantID) REFERENCES dbo.Restaurants(RestaurantID),
    CONSTRAINT CK_RestaurantWastage_Quantity CHECK (WastageQuantityInPounds >= 0)
);
GO

CREATE TABLE dbo.Customers
(
    CustomerID int IDENTITY(1,1) NOT NULL,
    CustomerName nvarchar(200) NOT NULL,
    StreetAddress nvarchar(300) NULL,
    ZipCode varchar(5) NOT NULL,
    PhoneNumber varchar(10) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Customers_IsActive DEFAULT (1),
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerID),
    CONSTRAINT FK_Customers_Locations FOREIGN KEY (ZipCode) REFERENCES dbo.Locations(ZipCode),
    CONSTRAINT CK_Customers_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(CustomerName))) > 0),
    CONSTRAINT CK_Customers_Phone_US CHECK
    (
        PhoneNumber IS NULL OR
        (LEN(PhoneNumber) = 10 AND PhoneNumber COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%')
    )
);
GO

CREATE TABLE dbo.Employees
(
    EmployeeID int NOT NULL, /* Supplied by the HR system; the PK enforces uniqueness. */
    RestaurantID int NOT NULL,
    EmployeeName nvarchar(200) NOT NULL,
    StreetAddress nvarchar(300) NULL,
    ZipCode varchar(5) NULL,
    PhoneNumber varchar(10) NULL,
    Salary decimal(12,2) NOT NULL,
    EmployeeType char(1) NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Employees_IsActive DEFAULT (1),
    CONSTRAINT PK_Employees PRIMARY KEY (EmployeeID),
    CONSTRAINT UQ_Employees_Employee_Restaurant UNIQUE (EmployeeID, RestaurantID),
    CONSTRAINT FK_Employees_Restaurants FOREIGN KEY (RestaurantID) REFERENCES dbo.Restaurants(RestaurantID),
    CONSTRAINT FK_Employees_Locations FOREIGN KEY (ZipCode) REFERENCES dbo.Locations(ZipCode),
    CONSTRAINT CK_Employees_Type CHECK (EmployeeType IN ('W', 'C', 'D')),
    CONSTRAINT CK_Employees_Salary CHECK (Salary >= 0),
    CONSTRAINT CK_Employees_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(EmployeeName))) > 0),
    CONSTRAINT CK_Employees_Phone_US CHECK
    (
        PhoneNumber IS NULL OR
        (LEN(PhoneNumber) = 10 AND PhoneNumber COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%')
    )
);
GO

CREATE TABLE dbo.Waiters
(
    WaiterID int NOT NULL,
    RestaurantID int NOT NULL,
    Designation nvarchar(50) NULL,
    CONSTRAINT PK_Waiters PRIMARY KEY (WaiterID),
    CONSTRAINT UQ_Waiters_Waiter_Restaurant UNIQUE (WaiterID, RestaurantID),
    CONSTRAINT FK_Waiters_Employees FOREIGN KEY (WaiterID, RestaurantID)
        REFERENCES dbo.Employees(EmployeeID, RestaurantID)
);

CREATE TABLE dbo.Chefs
(
    ChefID int NOT NULL,
    Designation nvarchar(50) NULL,
    CONSTRAINT PK_Chefs PRIMARY KEY (ChefID),
    CONSTRAINT FK_Chefs_Employees FOREIGN KEY (ChefID) REFERENCES dbo.Employees(EmployeeID)
);

/* Delivery employees are part of a shared platform fleet across restaurants. */
CREATE TABLE dbo.DeliveryEmployees
(
    DeliveryEmployeeID int NOT NULL,
    IsDeliveryPartnerAvailable bit NOT NULL CONSTRAINT DF_DeliveryEmployees_Available DEFAULT (1),
    CONSTRAINT PK_DeliveryEmployees PRIMARY KEY (DeliveryEmployeeID),
    CONSTRAINT FK_DeliveryEmployees_Employees FOREIGN KEY (DeliveryEmployeeID) REFERENCES dbo.Employees(EmployeeID)
);
GO

CREATE TABLE dbo.MenuItems
(
    MenuItemID int IDENTITY(1,1) NOT NULL,
    RestaurantID int NOT NULL,
    MenuItemCode varchar(20) NOT NULL,
    MenuItemName nvarchar(200) NOT NULL,
    Price decimal(10,2) NOT NULL,
    IsAvailable bit NOT NULL CONSTRAINT DF_MenuItems_IsAvailable DEFAULT (1),
    CONSTRAINT PK_MenuItems PRIMARY KEY (MenuItemID),
    CONSTRAINT UQ_MenuItems_Restaurant_Code UNIQUE (RestaurantID, MenuItemCode),
    CONSTRAINT UQ_MenuItems_Item_Restaurant UNIQUE (MenuItemID, RestaurantID),
    CONSTRAINT FK_MenuItems_Restaurants FOREIGN KEY (RestaurantID) REFERENCES dbo.Restaurants(RestaurantID),
    CONSTRAINT CK_MenuItems_Price CHECK (Price >= 0),
    CONSTRAINT CK_MenuItems_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(MenuItemName))) > 0)
);
GO

CREATE TABLE dbo.OrderStatuses
(
    OrderStatusID tinyint NOT NULL,
    OrderStatusDescription nvarchar(40) NOT NULL,
    CONSTRAINT PK_OrderStatuses PRIMARY KEY (OrderStatusID),
    CONSTRAINT UQ_OrderStatuses_Description UNIQUE (OrderStatusDescription)
);
INSERT dbo.OrderStatuses (OrderStatusID, OrderStatusDescription)
VALUES (1, N'Pending'), (2, N'Preparing'), (3, N'Ready'),
       (4, N'In Transit'), (5, N'Fulfilled'), (6, N'Cancelled');
GO

CREATE TABLE dbo.OrderStatusTransitions
(
    FromStatusID tinyint NOT NULL,
    ToStatusID tinyint NOT NULL,
    CONSTRAINT PK_OrderStatusTransitions PRIMARY KEY (FromStatusID, ToStatusID),
    CONSTRAINT FK_OrderStatusTransitions_From FOREIGN KEY (FromStatusID) REFERENCES dbo.OrderStatuses(OrderStatusID),
    CONSTRAINT FK_OrderStatusTransitions_To FOREIGN KEY (ToStatusID) REFERENCES dbo.OrderStatuses(OrderStatusID),
    CONSTRAINT CK_OrderStatusTransitions_NoSelfTransition CHECK (FromStatusID <> ToStatusID)
);
INSERT dbo.OrderStatusTransitions (FromStatusID, ToStatusID)
VALUES (1,2), (1,6), (2,3), (2,6), (3,4), (3,5), (3,6), (4,5);
GO

CREATE SEQUENCE dbo.OrderIDSequence AS int START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 50;
GO

CREATE TABLE dbo.Orders
(
    OrderID int NOT NULL,
    CustomerID int NOT NULL,
    RestaurantID int NOT NULL,
    ServiceType char(2) NOT NULL,
    OrderStatusID tinyint NOT NULL CONSTRAINT DF_Orders_Status DEFAULT (1),
    OrderTimeUTC datetime2(3) NOT NULL CONSTRAINT DF_Orders_OrderTimeUTC DEFAULT SYSUTCDATETIME(),
    SubtotalAmount decimal(12,2) NULL,
    TaxRate decimal(5,4) NULL,
    TaxAmount decimal(12,2) NULL,
    TipAmount decimal(12,2) NULL,
    OrderAmount AS
    (
        CASE WHEN SubtotalAmount IS NULL OR TaxAmount IS NULL OR TipAmount IS NULL THEN NULL
             ELSE CONVERT(decimal(12,2), SubtotalAmount + TaxAmount + TipAmount) END
    ) PERSISTED,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT UQ_Orders_Order_Restaurant UNIQUE (OrderID, RestaurantID),
    CONSTRAINT UQ_Orders_Order_Restaurant_Service UNIQUE (OrderID, RestaurantID, ServiceType),
    CONSTRAINT UQ_Orders_Order_Customer UNIQUE (OrderID, CustomerID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT FK_Orders_Restaurants FOREIGN KEY (RestaurantID) REFERENCES dbo.Restaurants(RestaurantID),
    CONSTRAINT FK_Orders_Statuses FOREIGN KEY (OrderStatusID) REFERENCES dbo.OrderStatuses(OrderStatusID),
    CONSTRAINT CK_Orders_ServiceType CHECK (ServiceType IN ('DI', 'DL')),
    CONSTRAINT CK_Orders_TaxRate CHECK (TaxRate IS NULL OR TaxRate BETWEEN 0 AND 1),
    CONSTRAINT CK_Orders_Amounts CHECK
    (
        (SubtotalAmount IS NULL AND TaxRate IS NULL AND TaxAmount IS NULL AND TipAmount IS NULL)
        OR
        (SubtotalAmount IS NOT NULL AND SubtotalAmount >= 0
         AND TaxRate IS NOT NULL AND TaxAmount IS NOT NULL AND TaxAmount >= 0
         AND TipAmount IS NOT NULL AND TipAmount >= 0)
    )
);
GO

CREATE TABLE dbo.OrderLines
(
    OrderID int NOT NULL,
    MenuItemID int NOT NULL,
    RestaurantID int NOT NULL,
    OrderQuantity int NOT NULL,
    UnitPrice decimal(10,2) NOT NULL,
    LineSubtotal AS CONVERT(decimal(12,2), UnitPrice * OrderQuantity) PERSISTED,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderID, MenuItemID),
    CONSTRAINT FK_OrderLines_Orders FOREIGN KEY (OrderID, RestaurantID)
        REFERENCES dbo.Orders(OrderID, RestaurantID),
    CONSTRAINT FK_OrderLines_MenuItems FOREIGN KEY (MenuItemID, RestaurantID)
        REFERENCES dbo.MenuItems(MenuItemID, RestaurantID),
    CONSTRAINT CK_OrderLines_Quantity CHECK (OrderQuantity > 0),
    CONSTRAINT CK_OrderLines_UnitPrice CHECK (UnitPrice >= 0)
);
GO

CREATE TABLE dbo.DineInOrders
(
    OrderID int NOT NULL,
    RestaurantID int NOT NULL,
    ServiceType char(2) NOT NULL CONSTRAINT DF_DineInOrders_ServiceType DEFAULT ('DI'),
    WaiterID int NOT NULL,
    VisitAtUTC datetime2(3) NOT NULL CONSTRAINT DF_DineInOrders_VisitAtUTC DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_DineInOrders PRIMARY KEY (OrderID),
    CONSTRAINT FK_DineInOrders_Orders FOREIGN KEY (OrderID, RestaurantID, ServiceType)
        REFERENCES dbo.Orders(OrderID, RestaurantID, ServiceType),
    CONSTRAINT FK_DineInOrders_Waiters FOREIGN KEY (WaiterID, RestaurantID)
        REFERENCES dbo.Waiters(WaiterID, RestaurantID),
    CONSTRAINT CK_DineInOrders_ServiceType CHECK (ServiceType = 'DI')
);
GO

CREATE TABLE dbo.Delivery
(
    OrderID int NOT NULL,
    DeliveryEmployeeID int NULL,
    DeliveryStartTimeUTC datetime2(3) NULL,
    DeliveryEndTimeUTC datetime2(3) NULL,
    DeliveryDurationMilliseconds AS
    (
        CASE WHEN DeliveryStartTimeUTC IS NOT NULL AND DeliveryEndTimeUTC IS NOT NULL
             THEN DATEDIFF_BIG(millisecond, DeliveryStartTimeUTC, DeliveryEndTimeUTC) END
    ) PERSISTED,
    CONSTRAINT PK_Delivery PRIMARY KEY (OrderID),
    CONSTRAINT FK_Delivery_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
    CONSTRAINT FK_Delivery_DeliveryEmployees FOREIGN KEY (DeliveryEmployeeID)
        REFERENCES dbo.DeliveryEmployees(DeliveryEmployeeID),
    CONSTRAINT CK_Delivery_TimeOrder CHECK
    (
        DeliveryEndTimeUTC IS NULL OR
        (DeliveryStartTimeUTC IS NOT NULL AND DeliveryEndTimeUTC >= DeliveryStartTimeUTC)
    )
);
GO

CREATE UNIQUE INDEX UX_Delivery_OneActiveAssignmentPerEmployee
    ON dbo.Delivery(DeliveryEmployeeID)
    WHERE DeliveryEmployeeID IS NOT NULL AND DeliveryEndTimeUTC IS NULL;
GO

CREATE TABLE dbo.Payments
(
    PaymentID bigint IDENTITY(1,1) NOT NULL,
    OrderID int NOT NULL,
    PaymentMethod varchar(20) NOT NULL,
    PaymentAmount decimal(12,2) NOT NULL,
    PaymentStatus varchar(12) NOT NULL,
    RecordedAtUTC datetime2(3) NOT NULL CONSTRAINT DF_Payments_RecordedAtUTC DEFAULT SYSUTCDATETIME(),
    ProviderReference nvarchar(100) NULL,
    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
    CONSTRAINT CK_Payments_Method CHECK (PaymentMethod IN ('Cash', 'Card', 'Wallet', 'BankTransfer', 'Other')),
    CONSTRAINT CK_Payments_Amount CHECK (PaymentAmount > 0),
    CONSTRAINT CK_Payments_Status CHECK (PaymentStatus IN ('Pending', 'Authorized', 'Captured', 'Failed', 'Refunded'))
);
GO

CREATE TABLE dbo.Feedback
(
    OrderID int NOT NULL,
    CustomerID int NOT NULL,
    FeedbackDescription nvarchar(1000) NULL,
    FoodRating tinyint NOT NULL,
    ServiceRating tinyint NOT NULL,
    CreatedAtUTC datetime2(3) NOT NULL CONSTRAINT DF_Feedback_CreatedAtUTC DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Feedback PRIMARY KEY (OrderID),
    CONSTRAINT FK_Feedback_OrdersAndCustomer FOREIGN KEY (OrderID, CustomerID)
        REFERENCES dbo.Orders(OrderID, CustomerID),
    CONSTRAINT CK_Feedback_FoodRating CHECK (FoodRating BETWEEN 1 AND 5),
    CONSTRAINT CK_Feedback_ServiceRating CHECK (ServiceRating BETWEEN 1 AND 5)
);
GO

CREATE TABLE dbo.OrderStatusHistory
(
    OrderStatusHistoryID bigint IDENTITY(1,1) NOT NULL,
    OrderID int NOT NULL,
    OrderStatusID tinyint NOT NULL,
    ChangedAtUTC datetime2(3) NOT NULL,
    ChangedBy sysname NOT NULL,
    CONSTRAINT PK_OrderStatusHistory PRIMARY KEY (OrderStatusHistoryID),
    CONSTRAINT FK_OrderStatusHistory_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
    CONSTRAINT FK_OrderStatusHistory_Statuses FOREIGN KEY (OrderStatusID) REFERENCES dbo.OrderStatuses(OrderStatusID)
);
GO

CREATE TYPE dbo.OrderLineInput AS TABLE
(
    MenuItemID int NOT NULL PRIMARY KEY,
    OrderQuantity int NOT NULL CHECK (OrderQuantity > 0)
);
GO

CREATE INDEX IX_RestaurantWastage_Date_Restaurant
    ON dbo.RestaurantWastage(DateOfWastage, RestaurantID) INCLUDE (WastageQuantityInPounds);
CREATE INDEX IX_Employees_Restaurant_Type
    ON dbo.Employees(RestaurantID, EmployeeType) INCLUDE (EmployeeName, IsActive);
CREATE INDEX IX_Orders_Customer_Time ON dbo.Orders(CustomerID, OrderTimeUTC DESC);
CREATE INDEX IX_Orders_Restaurant_Time ON dbo.Orders(RestaurantID, OrderTimeUTC DESC);
CREATE INDEX IX_OrderLines_MenuItem_Order ON dbo.OrderLines(MenuItemID, OrderID);
CREATE INDEX IX_Delivery_Employee_Start ON dbo.Delivery(DeliveryEmployeeID, DeliveryStartTimeUTC);
GO
