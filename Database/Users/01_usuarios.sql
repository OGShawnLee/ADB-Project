USE AdventureWorks2014;
GO

-- ============================================================
-- 1. USUARIO ADMINISTRADOR (control total)
-- ============================================================

-- Login a nivel servidor
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_admin')
BEGIN
    CREATE LOGIN aw_admin
        WITH PASSWORD   = 'Admin@AW2014Secure!',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

-- Usuario en la base de datos
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_admin')
BEGIN
    CREATE USER aw_admin FOR LOGIN aw_admin;
END
GO

-- Control total sobre la base de datos
ALTER ROLE db_owner ADD MEMBER aw_admin;
GO


-- ============================================================
-- 2. USUARIOS POR ÁREA FUNCIONAL
-- ============================================================

-- --------------------------------------------------------
-- ÁREA: Sales (Ventas)
-- --------------------------------------------------------
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_sales_user')
BEGIN
    CREATE LOGIN aw_sales_user
        WITH PASSWORD   = 'Sales@AW2014x99',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_sales_user')
BEGIN
    CREATE USER aw_sales_user FOR LOGIN aw_sales_user;
END
GO

-- Permisos de lectura y escritura sobre el esquema Sales
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Sales TO aw_sales_user;
GO

-- --------------------------------------------------------
-- ÁREA: HumanResources (Recursos Humanos)
-- --------------------------------------------------------
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_hr_user')
BEGIN
    CREATE LOGIN aw_hr_user
        WITH PASSWORD   = 'HumRes@AW2014x88',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_hr_user')
BEGIN
    CREATE USER aw_hr_user FOR LOGIN aw_hr_user;
END
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::HumanResources TO aw_hr_user;
GO

-- --------------------------------------------------------
-- ÁREA: Production (Producción)
-- --------------------------------------------------------
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_production_user')
BEGIN
    CREATE LOGIN aw_production_user
        WITH PASSWORD   = 'Prod@AW2014x77Secure',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_production_user')
BEGIN
    CREATE USER aw_production_user FOR LOGIN aw_production_user;
END
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Production TO aw_production_user;
GO

-- --------------------------------------------------------
-- ÁREA: Purchasing (Compras)
-- --------------------------------------------------------
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_purchasing_user')
BEGIN
    CREATE LOGIN aw_purchasing_user
        WITH PASSWORD   = 'Purch@AW2014x66Secure',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_purchasing_user')
BEGIN
    CREATE USER aw_purchasing_user FOR LOGIN aw_purchasing_user;
END
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Purchasing TO aw_purchasing_user;
GO

-- --------------------------------------------------------
-- ÁREA: Person
-- --------------------------------------------------------
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_person_user')
BEGIN
    CREATE LOGIN aw_person_user
        WITH PASSWORD   = 'Person@AW2014x55Secure',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_person_user')
BEGIN
    CREATE USER aw_person_user FOR LOGIN aw_person_user;
END
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Person TO aw_person_user;
GO


-- ============================================================
-- 3. USUARIO EXCLUSIVO PARA RESPALDOS
-- ============================================================

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'aw_backup_user')
BEGIN
    CREATE LOGIN aw_backup_user
        WITH PASSWORD   = 'Backup@AW2014x44Secure',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = ON;
END
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'aw_backup_user')
BEGIN
    CREATE USER aw_backup_user FOR LOGIN aw_backup_user;
END
GO

-- Solo permisos necesarios para respaldo
ALTER ROLE db_backupoperator ADD MEMBER aw_backup_user;
-- Permiso para leer todos los objetos (necesario para backup completo)
ALTER ROLE db_datareader    ADD MEMBER aw_backup_user;
GO



-- Listar usuarios creados

SELECT
    sp.name          AS LoginName,
    dp.name          AS DBUser,
    dp.type_desc     AS UserType,
    r.name           AS DBRole
FROM sys.database_principals dp
INNER JOIN sys.server_principals sp
    ON dp.sid = sp.sid
LEFT JOIN sys.database_role_members rm
    ON dp.principal_id = rm.member_principal_id
LEFT JOIN sys.database_principals r
    ON rm.role_principal_id = r.principal_id
WHERE dp.name IN (
    'aw_admin', 'aw_sales_user', 'aw_hr_user',
    'aw_production_user', 'aw_purchasing_user',
    'aw_person_user', 'aw_backup_user'
)
ORDER BY dp.name, r.name;
GO
