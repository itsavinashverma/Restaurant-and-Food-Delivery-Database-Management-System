/*
  Optional SQL Server symmetric column-encryption demonstration for synthetic
  recoverable text only. This is not TDE and is never used for login passwords.
  Back up the database master key and certificate through a protected DBA
  process before relying on recoverable encrypted business data.
*/
USE [DMDDFinalProjectDB];
GO

IF NOT EXISTS
   (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
    CREATE MASTER KEY;
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'DemoDataCertificate')
    CREATE CERTIFICATE DemoDataCertificate
        WITH SUBJECT = N'Synthetic recoverable-data demonstration only';
ELSE IF EXISTS
   (SELECT 1 FROM sys.certificates
    WHERE name = N'DemoDataCertificate'
      AND subject <> N'Synthetic recoverable-data demonstration only')
    THROW 51200, 'The existing DemoDataCertificate does not match the expected demo certificate.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'DemoData_SM')
    CREATE SYMMETRIC KEY DemoData_SM
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE DemoDataCertificate;
ELSE IF EXISTS
   (SELECT 1 FROM sys.symmetric_keys
    WHERE name = N'DemoData_SM' AND algorithm_desc <> N'AES_256')
    THROW 51201, 'The existing DemoData_SM key is not AES_256.', 1;
GO

DECLARE @DemoRecordID int = 1;
DECLARE @DemoText nvarchar(200) = N'Synthetic encrypted note for the coursework demonstration.';
DECLARE @Ciphertext varbinary(max);

BEGIN TRY
    OPEN SYMMETRIC KEY DemoData_SM DECRYPTION BY CERTIFICATE DemoDataCertificate;

    BEGIN TRANSACTION;
    SET @Ciphertext = EncryptByKey
    (
        Key_GUID(N'DemoData_SM'),
        CONVERT(varbinary(max), @DemoText),
        1,
        CONVERT(varbinary(4), @DemoRecordID)
    );
    IF @Ciphertext IS NULL
        THROW 51202, 'Encryption returned NULL; the synthetic record was not written.', 1;

    IF EXISTS (SELECT 1 FROM dbo.EncryptionDemo WITH (UPDLOCK, HOLDLOCK) WHERE DemoRecordID = @DemoRecordID)
        UPDATE dbo.EncryptionDemo SET PayloadCipher = @Ciphertext WHERE DemoRecordID = @DemoRecordID;
    ELSE
        INSERT dbo.EncryptionDemo (DemoRecordID, PayloadCipher) VALUES (@DemoRecordID, @Ciphertext);

    IF @@ROWCOUNT <> 1
        THROW 51203, 'The synthetic encrypted record was not saved.', 1;

    COMMIT TRANSACTION;
    CLOSE SYMMETRIC KEY DemoData_SM;
    SELECT @DemoRecordID AS DemoRecordID, DATALENGTH(@Ciphertext) AS CiphertextBytes;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'DemoData_SM')
        CLOSE SYMMETRIC KEY DemoData_SM;
    THROW;
END CATCH;
GO
