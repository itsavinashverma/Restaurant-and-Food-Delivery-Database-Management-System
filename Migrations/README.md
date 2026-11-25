# SQL Server migration and seed policy

`DMDD_DDLScript.sql` is schema version 1. `dbo.SchemaVersion` records the installed baseline. `001_InitialInstall.sql` is the SQLCMD deployment entry point for a fresh database; `002_SeedDemoData.sql` loads the optional synthetic sample records in a single guarded transaction.

Run the entry points from the repository root with SQL Server 2019 or later:

```powershell
sqlcmd -S .\SQLEXPRESS -E -i .\Migrations\001_InitialInstall.sql
sqlcmd -S .\SQLEXPRESS -E -i .\Migrations\002_SeedDemoData.sql
```

In SSMS, enable **SQLCMD Mode** before running either migration entry point. `:r` and `GO` are client directives, not T-SQL statements. The seed requires an empty version 1 database and will roll back and reject a rerun.

Never rerun the initial-install file on a populated database. Future schema changes must be new numbered scripts (`003_...sql`, `004_...sql`), check the current `dbo.SchemaVersion`, make a reviewed backup, apply a transaction where SQL Server permits it, validate the migrated data, and update the version row only after success. Keep seed or demo data changes separate from schema migrations.

The repository contains no deployed database backup or trusted original purchase-time prices, payment records, or account credentials. There is therefore no safe automatic migration from the old schema. For an existing installation, stage a copy, map renamed objects and data explicitly, mark unavailable historical prices as unknown, require account resets instead of converting reversible ciphertext, reconcile data, and switch consumers only after validation. Do not invent historical values or run the fresh-install DDL against production data.
