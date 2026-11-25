USE [DMDDFinalProjectDB];
GO

IF DATABASE_PRINCIPAL_ID(N'restaurant_app_role') IS NULL
    CREATE ROLE restaurant_app_role AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'restaurant_reporting_role') IS NULL
    CREATE ROLE restaurant_reporting_role AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'restaurant_account_admin_role') IS NULL
    CREATE ROLE restaurant_account_admin_role AUTHORIZATION dbo;
GO

/* Application users call business procedures instead of writing base tables. */
GRANT EXECUTE ON dbo.usp_CreateOrder TO restaurant_app_role;
GRANT EXECUTE ON dbo.usp_CalculateTotalAmount TO restaurant_app_role;
GRANT EXECUTE ON dbo.usp_TransitionOrderStatus TO restaurant_app_role;
GRANT EXECUTE ON dbo.usp_AssignDelivery TO restaurant_app_role;
GRANT EXECUTE ON dbo.usp_StartDelivery TO restaurant_app_role;
GRANT EXECUTE ON dbo.usp_CompleteDelivery TO restaurant_app_role;

/* Credential lifecycle is restricted to a separate DBA-managed service role. */
GRANT EXECUTE ON dbo.usp_EnrollRestaurantAccount TO restaurant_account_admin_role;
GRANT EXECUTE ON dbo.usp_ResetRestaurantPasswordHash TO restaurant_account_admin_role;
GRANT EXECUTE ON dbo.usp_DisableRestaurantAccount TO restaurant_account_admin_role;
GRANT EXECUTE, REFERENCES ON TYPE::dbo.OrderLineInput TO restaurant_app_role;
GRANT SELECT ON dbo.v_MenuCatalog TO restaurant_app_role;
GRANT SELECT ON dbo.v_OrderSummary TO restaurant_app_role;

/* Reporting access is limited to reporting views and read-only procedures. */
GRANT SELECT ON dbo.v_RestaurantDirectory TO restaurant_reporting_role;
GRANT SELECT ON dbo.v_RestaurantWastageDaily TO restaurant_reporting_role;
GRANT SELECT ON dbo.v_RestaurantWastageSummary TO restaurant_reporting_role;
GRANT SELECT ON dbo.v_RestaurantRatings TO restaurant_reporting_role;
GRANT SELECT ON dbo.v_OrderSummary TO restaurant_reporting_role;
GRANT EXECUTE ON dbo.usp_CalculateAndDisplayFoodWastageByRestaurants TO restaurant_reporting_role;
GRANT EXECUTE ON dbo.usp_TopRestaurantsInArea TO restaurant_reporting_role;
GRANT EXECUTE ON dbo.usp_CalculateFastestDelivery TO restaurant_reporting_role;
GRANT EXECUTE ON dbo.usp_ListDeliveryViolations TO restaurant_reporting_role;

DENY SELECT ON dbo.RestaurantAccounts TO restaurant_app_role;
DENY SELECT ON dbo.RestaurantAccounts TO restaurant_reporting_role;
DENY SELECT ON dbo.RestaurantAccounts TO restaurant_account_admin_role;
DENY SELECT ON dbo.RestaurantAccountAudit TO restaurant_app_role;
DENY SELECT ON dbo.RestaurantAccountAudit TO restaurant_reporting_role;
DENY SELECT ON dbo.RestaurantAccountAudit TO restaurant_account_admin_role;
GO

/*
  A DBA/deployment owner must add only application service identities to these roles.
  restaurant_account_admin_role is for the separately controlled credential-management
  service. These database roles do not enforce restaurant-level tenant isolation; the
  application must authorize each tenant action before calling a procedure. Do not add
  restaurant users directly or grant ordinary users db_owner, db_datareader or db_datawriter.
*/
