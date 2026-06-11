USE AdventureWorks2014;
GO

-- ============================================================
-- SP_Employee
-- Operaciones: SELECT (uno / todos), INSERT, UPDATE, DELETE
-- ============================================================

IF OBJECT_ID('HumanResources.SP_Employee', 'P') IS NOT NULL
    DROP PROCEDURE HumanResources.SP_Employee;
GO

CREATE PROCEDURE HumanResources.SP_Employee
    -- Acción a ejecutar
    @Action             NVARCHAR(10),       -- 'SELECT_ALL' | 'SELECT_ONE' | 'INSERT' | 'UPDATE' | 'DELETE'

    -- Parámetros comunes
    @BusinessEntityID   INT             = NULL,

    -- Parámetros para INSERT / UPDATE
    @NationalIDNumber   NVARCHAR(15)    = NULL,
    @LoginID            NVARCHAR(256)   = NULL,
    @JobTitle           NVARCHAR(50)    = NULL,
    @BirthDate          DATE            = NULL,
    @MaritalStatus      NCHAR(1)        = NULL,  -- 'S' soltero | 'M' casado
    @Gender             NCHAR(1)        = NULL,  -- 'M' | 'F'
    @HireDate           DATE            = NULL,
    @SalariedFlag       BIT             = NULL,
    @VacationHours      SMALLINT        = NULL,
    @SickLeaveHours     SMALLINT        = NULL,
    @CurrentFlag        BIT             = NULL,
    @OrganizationLevel  SMALLINT        = NULL,

    -- Parámetros de salida
    @OutBusinessEntityID INT            = NULL OUTPUT,
    @StatusCode          INT            = NULL OUTPUT,
    @Message             NVARCHAR(500)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS ON;
    SET QUOTED_IDENTIFIER ON;

    -- Valores por defecto para salida
    SET @StatusCode = 500;
    SET @Message    = N'Error interno no controlado.';

    -- --------------------------------------------------------
    -- SELECT ALL
    -- --------------------------------------------------------
    IF @Action = 'SELECT_ALL'
    BEGIN
        SELECT
            e.BusinessEntityID,
            p.FirstName,
            p.LastName,
            e.NationalIDNumber,
            e.LoginID,
            e.JobTitle,
            e.BirthDate,
            e.MaritalStatus,
            e.Gender,
            e.HireDate,
            e.SalariedFlag,
            e.VacationHours,
            e.SickLeaveHours,
            e.CurrentFlag,
            e.OrganizationLevel,
            e.ModifiedDate
        FROM HumanResources.Employee e
        INNER JOIN Person.Person p
            ON e.BusinessEntityID = p.BusinessEntityID
        ORDER BY e.BusinessEntityID;

        SET @StatusCode = 200;
        SET @Message    = N'Consulta exitosa: todos los empleados.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- SELECT ONE
    -- --------------------------------------------------------
    IF @Action = 'SELECT_ONE'
    BEGIN
        IF @BusinessEntityID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: BusinessEntityID es requerido para SELECT_ONE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM HumanResources.Employee
            WHERE BusinessEntityID = @BusinessEntityID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un empleado con BusinessEntityID = '
                              + CAST(@BusinessEntityID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        SELECT
            e.BusinessEntityID,
            p.FirstName,
            p.LastName,
            e.NationalIDNumber,
            e.LoginID,
            e.JobTitle,
            e.BirthDate,
            e.MaritalStatus,
            e.Gender,
            e.HireDate,
            e.SalariedFlag,
            e.VacationHours,
            e.SickLeaveHours,
            e.CurrentFlag,
            e.OrganizationLevel,
            e.ModifiedDate
        FROM HumanResources.Employee e
        INNER JOIN Person.Person p
            ON e.BusinessEntityID = p.BusinessEntityID
        WHERE e.BusinessEntityID = @BusinessEntityID;

        SET @StatusCode = 200;
        SET @Message    = N'Consulta exitosa: empleado ' + CAST(@BusinessEntityID AS NVARCHAR(10)) + '.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- INSERT
    -- --------------------------------------------------------
    IF @Action = 'INSERT'
    BEGIN
        -- Validar campos obligatorios
        IF @NationalIDNumber IS NULL OR @LoginID IS NULL OR @JobTitle IS NULL
           OR @BirthDate IS NULL OR @MaritalStatus IS NULL OR @Gender IS NULL
           OR @HireDate IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: Campos obligatorios faltantes '
                              + N'(NationalIDNumber, LoginID, JobTitle, BirthDate, MaritalStatus, Gender, HireDate).';
            RETURN;
        END

        -- Verificar duplicado por NationalIDNumber
        IF EXISTS (
            SELECT 1 FROM HumanResources.Employee
            WHERE NationalIDNumber = @NationalIDNumber
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: Ya existe un empleado con NationalIDNumber = '
                              + @NationalIDNumber + '.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                -- 1. Insertar BusinessEntity (requerido por FK)
                INSERT INTO Person.BusinessEntity (rowguid, ModifiedDate)
                VALUES (NEWID(), GETDATE());

                SET @OutBusinessEntityID = SCOPE_IDENTITY();

                -- 2. Insertar Person básico (mínimo requerido)
                INSERT INTO Person.Person
                    (BusinessEntityID, PersonType, FirstName, LastName,
                     EmailPromotion, rowguid, ModifiedDate)
                VALUES
                    (@OutBusinessEntityID, 'EM', N'Nuevo', N'Empleado',
                     0, NEWID(), GETDATE());

                -- 3. Insertar Employee
                INSERT INTO HumanResources.Employee
                    (BusinessEntityID, NationalIDNumber, LoginID,
                     JobTitle, BirthDate, MaritalStatus, Gender,
                     HireDate, SalariedFlag, VacationHours, SickLeaveHours,
                     CurrentFlag, rowguid, ModifiedDate)
                VALUES
                    (@OutBusinessEntityID,
                     @NationalIDNumber,
                     @LoginID,
                     @JobTitle,
                     @BirthDate,
                     @MaritalStatus,
                     @Gender,
                     @HireDate,
                     ISNULL(@SalariedFlag, 1),
                     ISNULL(@VacationHours, 0),
                     ISNULL(@SickLeaveHours, 0),
                     ISNULL(@CurrentFlag, 1),
                     NEWID(),
                     GETDATE());

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Empleado insertado con BusinessEntityID = '
                              + CAST(@OutBusinessEntityID AS NVARCHAR(10)) + '.';
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            SET @StatusCode = 500;
            SET @Message    = N'Error 500: ' + ERROR_MESSAGE()
                              + N' | Línea: ' + CAST(ERROR_LINE() AS NVARCHAR(10));
        END CATCH

        RETURN;
    END

    -- --------------------------------------------------------
    -- UPDATE
    -- --------------------------------------------------------
    IF @Action = 'UPDATE'
    BEGIN
        IF @BusinessEntityID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: BusinessEntityID es requerido para UPDATE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM HumanResources.Employee
            WHERE BusinessEntityID = @BusinessEntityID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un empleado con BusinessEntityID = '
                              + CAST(@BusinessEntityID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        -- Verificar duplicado de NationalIDNumber en otro registro
        IF @NationalIDNumber IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM HumanResources.Employee
               WHERE NationalIDNumber = @NationalIDNumber
                 AND BusinessEntityID <> @BusinessEntityID
           )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: El NationalIDNumber ' + @NationalIDNumber
                              + N' ya pertenece a otro empleado.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                UPDATE HumanResources.Employee
                SET
                    NationalIDNumber = ISNULL(@NationalIDNumber, NationalIDNumber),
                    LoginID          = ISNULL(@LoginID,          LoginID),
                    JobTitle         = ISNULL(@JobTitle,         JobTitle),
                    BirthDate        = ISNULL(@BirthDate,        BirthDate),
                    MaritalStatus    = ISNULL(@MaritalStatus,    MaritalStatus),
                    Gender           = ISNULL(@Gender,           Gender),
                    HireDate         = ISNULL(@HireDate,         HireDate),
                    SalariedFlag     = ISNULL(@SalariedFlag,     SalariedFlag),
                    VacationHours    = ISNULL(@VacationHours,    VacationHours),
                    SickLeaveHours   = ISNULL(@SickLeaveHours,   SickLeaveHours),
                    CurrentFlag      = ISNULL(@CurrentFlag,      CurrentFlag),
                    ModifiedDate     = GETDATE()
                WHERE BusinessEntityID = @BusinessEntityID;

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Empleado ' + CAST(@BusinessEntityID AS NVARCHAR(10))
                              + N' actualizado correctamente.';
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            SET @StatusCode = 500;
            SET @Message    = N'Error 500: ' + ERROR_MESSAGE()
                              + N' | Línea: ' + CAST(ERROR_LINE() AS NVARCHAR(10));
        END CATCH

        RETURN;
    END

    -- --------------------------------------------------------
    -- DELETE
    -- --------------------------------------------------------
    IF @Action = 'DELETE'
    BEGIN
        IF @BusinessEntityID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: BusinessEntityID es requerido para DELETE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM HumanResources.Employee
            WHERE BusinessEntityID = @BusinessEntityID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un empleado con BusinessEntityID = '
                              + CAST(@BusinessEntityID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                -- Eliminar registros dependientes primero
                DELETE FROM HumanResources.EmployeeDepartmentHistory
                WHERE BusinessEntityID = @BusinessEntityID;

                DELETE FROM HumanResources.EmployeePayHistory
                WHERE BusinessEntityID = @BusinessEntityID;

                -- Eliminar Employee
                DELETE FROM HumanResources.Employee
                WHERE BusinessEntityID = @BusinessEntityID;

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Empleado ' + CAST(@BusinessEntityID AS NVARCHAR(10))
                              + N' eliminado correctamente.';
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            SET @StatusCode = 500;
            SET @Message    = N'Error 500: ' + ERROR_MESSAGE()
                              + N' | Línea: ' + CAST(ERROR_LINE() AS NVARCHAR(10));
        END CATCH

        RETURN;
    END

    -- Acción no reconocida
    SET @StatusCode = 400;
    SET @Message    = N'Error 400: Acción no reconocida. Use SELECT_ALL, SELECT_ONE, INSERT, UPDATE o DELETE.';
END
GO


-- ============================================================
-- EJEMPLOS DE USO - Employee
-- ============================================================

-- Obtener todos los empleados
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC HumanResources.SP_Employee
    @Action     = 'SELECT_ALL',
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Obtener un empleado
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC HumanResources.SP_Employee
    @Action           = 'SELECT_ONE',
    @BusinessEntityID = 1,
    @StatusCode       = @Code OUTPUT,
    @Message          = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Insertar un empleado
DECLARE @Code INT, @Msg NVARCHAR(500), @NewID INT;
EXEC HumanResources.SP_Employee
    @Action           = 'INSERT',
    @NationalIDNumber = '998877665',
    @LoginID          = 'adventure-works\nuevo.empleado',
    @JobTitle         = 'Software Engineer',
    @BirthDate        = '1990-05-15',
    @MaritalStatus    = 'S',
    @Gender           = 'M',
    @HireDate         = '2024-01-10',
    @SalariedFlag     = 1,
    @VacationHours    = 10,
    @SickLeaveHours   = 5,
    @CurrentFlag      = 1,
    @OutBusinessEntityID = @NewID  OUTPUT,
    @StatusCode          = @Code   OUTPUT,
    @Message             = @Msg    OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message, @NewID AS NuevoBusinessEntityID;
GO

-- Actualizar un empleado (usar el ID devuelto por INSERT)
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC HumanResources.SP_Employee
    @Action           = 'UPDATE',
    @BusinessEntityID = 1,
    @JobTitle         = 'Senior Software Engineer',
    @VacationHours    = 20,
    @StatusCode       = @Code OUTPUT,
    @Message          = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Eliminar un empleado
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC HumanResources.SP_Employee
    @Action           = 'DELETE',
    @BusinessEntityID = 1,
    @StatusCode       = @Code OUTPUT,
    @Message          = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO
