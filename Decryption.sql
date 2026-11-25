/* Optional: decrypt only the synthetic record created by Encryption.sql. */
USE [DMDDFinalProjectDB];
GO

DECLARE @DemoRecordID int = 1;
DECLARE @Ciphertext varbinary(max);
DECLARE @Plaintext nvarchar(max);

BEGIN TRY
    SELECT @Ciphertext = PayloadCipher
    FROM dbo.EncryptionDemo
    WHERE DemoRecordID = @DemoRecordID;

    IF @Ciphertext IS NULL
        THROW 51210, 'The synthetic encrypted record is missing.', 1;

    OPEN SYMMETRIC KEY DemoData_SM DECRYPTION BY CERTIFICATE DemoDataCertificate;
    SELECT @Plaintext = CONVERT(nvarchar(max), DecryptByKey
    (
        @Ciphertext,
        1,
        CONVERT(varbinary(4), @DemoRecordID)
    ));

    IF @Plaintext IS NULL
        THROW 51211, 'Decryption failed. Verify database context, key, certificate and record authenticator.', 1;

    CLOSE SYMMETRIC KEY DemoData_SM;
    SELECT @DemoRecordID AS DemoRecordID, @Plaintext AS SyntheticDemoText;
END TRY
BEGIN CATCH
    IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'DemoData_SM')
        CLOSE SYMMETRIC KEY DemoData_SM;
    THROW;
END CATCH;
GO
