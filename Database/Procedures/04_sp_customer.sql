USE AdventureWorks2014;
GO

-- ============================================================
-- SP_Customer
-- Operaciones: SELECT (uno / todos), INSERT, UPDATE, DELETE
-- ============================================================

IF OBJECT_ID('Sales.SP_Customer', 'P') IS NOT NULL
    DROP PROCEDURE Sales.SP_Customer;
GO

CREATE PROCEDURE Sales.SP_Customer
    -- Acción a ejecutar
    @Action             NVARCHAR(10),       -- 'SELECT_ALL' | 'SELECT_ONE' | 'INSERT' | 'UPDATE' | 'DELETE'

    -- Parámetros de identificación
    @CustomerID         INT             = NULL,

    -- Parámetros para INSERT / UPDATE
    -- Datos de Person (cliente individual)
    @PersonType         NCHAR(2)        = NULL,   -- 'IN'=Individual | 'SC'=Store Contact
    @FirstName          NVARCHAR(50)    = NULL,
    @MiddleName         NVARCHAR(50)    = NULL,
    @LastName           NVARCHAR(50)    = NULL,
    @EmailAddress       NVARCHAR(50)    = NULL,
    @EmailPromotion     INT             = NULL,   -- 0=Ninguno | 1=AW | 2=AW y socios

    -- Datos de Customer
    @TerritoryID        INT             = NULL,
    @StoreID            INT             = NULL,   -- NULL = cliente individual
    @AccountNumber      VARCHAR(10)     = NULL,   -- Se genera automáticamente en la BD (columna computada)

    -- Parámetros de salida
    @OutCustomerID      INT             = NULL OUTPUT,
    @OutBusinessEntityID INT            = NULL OUTPUT,
    @StatusCode         INT             = NULL OUTPUT,
    @Message            NVARCHAR(500)   = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS ON;
    SET QUOTED_IDENTIFIER ON;

    SET @StatusCode = 500;
    SET @Message    = N'Error interno no controlado.';

    -- --------------------------------------------------------
    -- SELECT ALL
    -- --------------------------------------------------------
    IF @Action = 'SELECT_ALL'
    BEGIN
        SELECT
            c.CustomerID,
            c.AccountNumber,
            c.TerritoryID,
            st.Name         AS Territory,
            c.StoreID,
            s.Name          AS StoreName,
            c.PersonID,
            p.FirstName,
            p.MiddleName,
            p.LastName,
            ea.EmailAddress,
            c.ModifiedDate
        FROM Sales.Customer c
        LEFT JOIN Sales.SalesTerritory st
            ON c.TerritoryID = st.TerritoryID
        LEFT JOIN Sales.Store s
            ON c.StoreID = s.BusinessEntityID
        LEFT JOIN Person.Person p
            ON c.PersonID = p.BusinessEntityID
        LEFT JOIN Person.EmailAddress ea
            ON c.PersonID = ea.BusinessEntityID
        ORDER BY c.CustomerID;

        SET @StatusCode = 200;
        SET @Message    = N'Consulta exitosa: todos los clientes.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- SELECT ONE
    -- --------------------------------------------------------
    IF @Action = 'SELECT_ONE'
    BEGIN
        IF @CustomerID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: CustomerID es requerido para SELECT_ONE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Sales.Customer WHERE CustomerID = @CustomerID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un cliente con CustomerID = '
                              + CAST(@CustomerID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        SELECT
            c.CustomerID,
            c.AccountNumber,
            c.TerritoryID,
            st.Name         AS Territory,
            c.StoreID,
            s.Name          AS StoreName,
            c.PersonID,
            p.FirstName,
            p.MiddleName,
            p.LastName,
            ea.EmailAddress,
            c.ModifiedDate
        FROM Sales.Customer c
        LEFT JOIN Sales.SalesTerritory st
            ON c.TerritoryID = st.TerritoryID
        LEFT JOIN Sales.Store s
            ON c.StoreID = s.BusinessEntityID
        LEFT JOIN Person.Person p
            ON c.PersonID = p.BusinessEntityID
        LEFT JOIN Person.EmailAddress ea
            ON c.PersonID = ea.BusinessEntityID
        WHERE c.CustomerID = @CustomerID;

        SET @StatusCode = 200;
        SET @Message    = N'Consulta exitosa: cliente ' + CAST(@CustomerID AS NVARCHAR(10)) + '.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- INSERT
    -- --------------------------------------------------------
    IF @Action = 'INSERT'
    BEGIN
        -- Validar campos obligatorios para persona individual
        IF @FirstName IS NULL OR @LastName IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: Campos obligatorios faltantes (FirstName, LastName).';
            RETURN;
        END

        -- Verificar duplicado de email si se proporciona
        IF @EmailAddress IS NOT NULL
           AND EXISTS (
               SELECT 1
               FROM Person.EmailAddress
               WHERE EmailAddress = @EmailAddress
           )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: El correo "' + @EmailAddress + N'" ya está registrado.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                -- 1. Insertar BusinessEntity
                INSERT INTO Person.BusinessEntity (rowguid, ModifiedDate)
                VALUES (NEWID(), GETDATE());

                SET @OutBusinessEntityID = SCOPE_IDENTITY();

                -- 2. Insertar Person
                INSERT INTO Person.Person
                    (BusinessEntityID, PersonType, NameStyle,
                     FirstName, MiddleName, LastName,
                     EmailPromotion, rowguid, ModifiedDate)
                VALUES
                    (@OutBusinessEntityID,
                     ISNULL(@PersonType, 'IN'),
                     0,
                     @FirstName,
                     @MiddleName,
                     @LastName,
                     ISNULL(@EmailPromotion, 0),
                     NEWID(),
                     GETDATE());

                -- 3. Insertar EmailAddress si se proporciona
                IF @EmailAddress IS NOT NULL
                BEGIN
                    INSERT INTO Person.EmailAddress
                        (BusinessEntityID, EmailAddressID, EmailAddress, rowguid, ModifiedDate)
                    VALUES
                        (@OutBusinessEntityID, 1, @EmailAddress, NEWID(), GETDATE());
                END

                -- 4. Insertar Customer
                INSERT INTO Sales.Customer
                    (PersonID, StoreID, TerritoryID, rowguid, ModifiedDate)
                VALUES
                    (@OutBusinessEntityID,
                     @StoreID,
                     @TerritoryID,
                     NEWID(),
                     GETDATE());

                SET @OutCustomerID = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Cliente insertado. '
                              + N'CustomerID = ' + CAST(@OutCustomerID AS NVARCHAR(10))
                              + N', BusinessEntityID = ' + CAST(@OutBusinessEntityID AS NVARCHAR(10)) + '.';
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
        IF @CustomerID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: CustomerID es requerido para UPDATE.';
            RETURN;
        END

        -- Verificar existencia
        DECLARE @ExistingPersonID INT, @ExistingStoreID INT, @ExistingTerritoryID INT;

        SELECT
            @ExistingPersonID    = PersonID,
            @ExistingStoreID     = StoreID,
            @ExistingTerritoryID = TerritoryID
        FROM Sales.Customer
        WHERE CustomerID = @CustomerID;

        IF @ExistingPersonID IS NULL AND @ExistingStoreID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un cliente con CustomerID = '
                              + CAST(@CustomerID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        -- Verificar duplicado de email en otra persona
        IF @EmailAddress IS NOT NULL
           AND EXISTS (
               SELECT 1
               FROM Person.EmailAddress
               WHERE EmailAddress = @EmailAddress
                 AND BusinessEntityID <> ISNULL(@ExistingPersonID, 0)
           )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: El correo "' + @EmailAddress
                              + N'" ya está registrado en otro cliente.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                -- Actualizar Customer
                UPDATE Sales.Customer
                SET
                    TerritoryID  = ISNULL(@TerritoryID, TerritoryID),
                    StoreID      = ISNULL(@StoreID,     StoreID),
                    ModifiedDate = GETDATE()
                WHERE CustomerID = @CustomerID;

                -- Actualizar Person si hay datos de persona
                IF @ExistingPersonID IS NOT NULL
                   AND (@FirstName IS NOT NULL OR @MiddleName IS NOT NULL
                        OR @LastName IS NOT NULL OR @EmailPromotion IS NOT NULL)
                BEGIN
                    UPDATE Person.Person
                    SET
                        FirstName      = ISNULL(@FirstName,      FirstName),
                        MiddleName     = ISNULL(@MiddleName,     MiddleName),
                        LastName       = ISNULL(@LastName,       LastName),
                        EmailPromotion = ISNULL(@EmailPromotion, EmailPromotion),
                        ModifiedDate   = GETDATE()
                    WHERE BusinessEntityID = @ExistingPersonID;
                END

                -- Actualizar o insertar EmailAddress
                IF @ExistingPersonID IS NOT NULL AND @EmailAddress IS NOT NULL
                BEGIN
                    IF EXISTS (
                        SELECT 1 FROM Person.EmailAddress
                        WHERE BusinessEntityID = @ExistingPersonID
                    )
                    BEGIN
                        UPDATE Person.EmailAddress
                        SET EmailAddress = @EmailAddress,
                            ModifiedDate = GETDATE()
                        WHERE BusinessEntityID = @ExistingPersonID;
                    END
                    ELSE
                    BEGIN
                        INSERT INTO Person.EmailAddress
                            (BusinessEntityID, EmailAddressID, EmailAddress, rowguid, ModifiedDate)
                        VALUES
                            (@ExistingPersonID, 1, @EmailAddress, NEWID(), GETDATE());
                    END
                END

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Cliente ' + CAST(@CustomerID AS NVARCHAR(10))
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
        IF @CustomerID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: CustomerID es requerido para DELETE.';
            RETURN;
        END

        DECLARE @DelPersonID INT;

        SELECT @DelPersonID = PersonID
        FROM Sales.Customer
        WHERE CustomerID = @CustomerID;

        IF NOT EXISTS (
            SELECT 1 FROM Sales.Customer WHERE CustomerID = @CustomerID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un cliente con CustomerID = '
                              + CAST(@CustomerID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        -- Verificar si el cliente tiene órdenes de venta asociadas
        IF EXISTS (
            SELECT 1 FROM Sales.SalesOrderHeader
            WHERE CustomerID = @CustomerID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No es posible eliminar el cliente '
                              + CAST(@CustomerID AS NVARCHAR(10))
                              + N' porque tiene órdenes de venta asociadas.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                -- Eliminar Customer
                DELETE FROM Sales.Customer
                WHERE CustomerID = @CustomerID;

                -- Si es persona individual, eliminar registros de Person
                IF @DelPersonID IS NOT NULL
                BEGIN
                    DELETE FROM Person.EmailAddress
                    WHERE BusinessEntityID = @DelPersonID;

                    DELETE FROM Person.PersonPhone
                    WHERE BusinessEntityID = @DelPersonID;

                    DELETE FROM Person.BusinessEntityContact
                    WHERE PersonID = @DelPersonID;

                    DELETE FROM Person.Person
                    WHERE BusinessEntityID = @DelPersonID;

                    DELETE FROM Person.BusinessEntity
                    WHERE BusinessEntityID = @DelPersonID;
                END

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Cliente ' + CAST(@CustomerID AS NVARCHAR(10))
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
-- EJEMPLOS DE USO - Customer
-- ============================================================

-- Obtener todos los clientes
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Sales.SP_Customer
    @Action     = 'SELECT_ALL',
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Obtener un cliente
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Sales.SP_Customer
    @Action     = 'SELECT_ONE',
    @CustomerID = 1,
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Insertar un cliente individual
DECLARE @Code INT, @Msg NVARCHAR(500), @NewCustID INT, @NewBEID INT;
EXEC Sales.SP_Customer
    @Action              = 'INSERT',
    @FirstName           = 'Carlos',
    @MiddleName          = 'Alberto',
    @LastName            = 'Mendoza',
    @EmailAddress        = 'carlos.mendoza@example.com',
    @EmailPromotion      = 1,
    @TerritoryID         = 1,
    @OutCustomerID       = @NewCustID OUTPUT,
    @OutBusinessEntityID = @NewBEID   OUTPUT,
    @StatusCode          = @Code      OUTPUT,
    @Message             = @Msg       OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message,
       @NewCustID AS NuevoCustomerID, @NewBEID AS NuevoBusinessEntityID;
GO

-- Actualizar un cliente
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Sales.SP_Customer
    @Action       = 'UPDATE',
    @CustomerID   = 1,
    @FirstName    = 'Carlos',
    @LastName     = 'Mendoza García',
    @EmailAddress = 'carlos.mendoza2@example.com',
    @TerritoryID  = 2,
    @StatusCode   = @Code OUTPUT,
    @Message      = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Eliminar un cliente (sin órdenes)
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Sales.SP_Customer
    @Action     = 'DELETE',
    @CustomerID = 1,
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO
