USE AdventureWorks2014;
GO

SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS NombreProcedimiento
FROM sys.objects
WHERE type = 'P'
ORDER BY Esquema, NombreProcedimiento;
-- =============================================
-- Script  : 01-CLEAN-ADVENTUREWORKS.sql
-- Desc    : Elimina todos los procedimientos almacenados
--           predeterminados de la base de datos AdventureWorks2014
-- =============================================

USE AdventureWorks2014;
GO

-- Schema: dbo
DROP PROCEDURE IF EXISTS dbo.uspGetBillOfMaterials;
DROP PROCEDURE IF EXISTS dbo.uspGetEmployeeManagers;
DROP PROCEDURE IF EXISTS dbo.uspGetManagerEmployees;
DROP PROCEDURE IF EXISTS dbo.uspGetWhereUsedProductID;
DROP PROCEDURE IF EXISTS dbo.uspLogError;
DROP PROCEDURE IF EXISTS dbo.uspPrintError;
DROP PROCEDURE IF EXISTS dbo.uspSearchCandidateResumes;

-- Schema: HumanResources
DROP PROCEDURE IF EXISTS HumanResources.uspUpdateEmployeeHireInfo;
DROP PROCEDURE IF EXISTS HumanResources.uspUpdateEmployeeLogin;
DROP PROCEDURE IF EXISTS HumanResources.uspUpdateEmployeePersonalInfo;
GO

-- Verificación: debe devolver 0 filas
SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS NombreProcedimiento
FROM sys.objects
WHERE type = 'P'
ORDER BY Esquema, NombreProcedimiento;
GO