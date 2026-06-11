USE AdventureWorks2014;
GO

-- ============================================================
-- SP_Product
-- Operaciones: SELECT (uno / todos), INSERT, UPDATE, DELETE
-- ============================================================

IF OBJECT_ID('Production.SP_Product', 'P') IS NOT NULL
    DROP PROCEDURE Production.SP_Product;
GO

CREATE PROCEDURE Production.SP_Product
    -- Acción a ejecutar
    @Action                 NVARCHAR(10),       -- 'SELECT_ALL' | 'SELECT_ONE' | 'INSERT' | 'UPDATE' | 'DELETE'

    -- Parámetros de identificación
    @ProductID              INT             = NULL,

    -- Parámetros para INSERT / UPDATE
    @Name                   NVARCHAR(50)    = NULL,
    @ProductNumber          NVARCHAR(25)    = NULL,
    @MakeFlag               BIT             = NULL,   -- 1 = fabricado internamente
    @FinishedGoodsFlag      BIT             = NULL,   -- 1 = producto terminado vendible
    @Color                  NVARCHAR(15)    = NULL,
    @SafetyStockLevel       SMALLINT        = NULL,
    @ReorderPoint           SMALLINT        = NULL,
    @StandardCost           MONEY           = NULL,
    @ListPrice              MONEY           = NULL,
    @Size                   NVARCHAR(5)     = NULL,
    @SizeUnitMeasureCode    NCHAR(3)        = NULL,
    @WeightUnitMeasureCode  NCHAR(3)        = NULL,
    @Weight                 DECIMAL(8,2)    = NULL,
    @DaysToManufacture      INT             = NULL,
    @ProductLine            NCHAR(2)        = NULL,   -- 'R'=Road | 'M'=Mountain | 'T'=Touring | 'S'=Standard
    @Class                  NCHAR(2)        = NULL,   -- 'H'=High | 'M'=Medium | 'L'=Low
    @Style                  NCHAR(2)        = NULL,   -- 'W'=Womens | 'M'=Mens | 'U'=Universal
    @ProductSubcategoryID   INT             = NULL,
    @ProductModelID         INT             = NULL,
    @SellStartDate          DATETIME        = NULL,
    @SellEndDate            DATETIME        = NULL,
    @DiscontinuedDate       DATETIME        = NULL,

    -- Parámetros de salida
    @OutProductID           INT             = NULL OUTPUT,
    @StatusCode             INT             = NULL OUTPUT,
    @Message                NVARCHAR(500)   = NULL OUTPUT
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
            p.ProductID,
            p.Name,
            p.ProductNumber,
            p.MakeFlag,
            p.FinishedGoodsFlag,
            p.Color,
            p.SafetyStockLevel,
            p.ReorderPoint,
            p.StandardCost,
            p.ListPrice,
            p.Size,
            p.Weight,
            p.DaysToManufacture,
            p.ProductLine,
            p.Class,
            p.Style,
            ps.Name  AS Subcategory,
            pm.Name  AS ProductModel,
            p.SellStartDate,
            p.SellEndDate,
            p.DiscontinuedDate,
            p.ModifiedDate
        FROM Production.Product p
        LEFT JOIN Production.ProductSubcategory ps
            ON p.ProductSubcategoryID = ps.ProductSubcategoryID
        LEFT JOIN Production.ProductModel pm
            ON p.ProductModelID = pm.ProductModelID
        ORDER BY p.ProductID;

        SET @StatusCode = 200;
        SET @Message    = N'Consulta exitosa: todos los productos.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- SELECT ONE
    -- --------------------------------------------------------
    IF @Action = 'SELECT_ONE'
    BEGIN
        IF @ProductID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: ProductID es requerido para SELECT_ONE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Production.Product WHERE ProductID = @ProductID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un producto con ProductID = '
                              + CAST(@ProductID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        SELECT
            p.ProductID,
            p.Name,
            p.ProductNumber,
            p.MakeFlag,
            p.FinishedGoodsFlag,
            p.Color,
            p.SafetyStockLevel,
            p.ReorderPoint,
            p.StandardCost,
            p.ListPrice,
            p.Size,
            p.Weight,
            p.DaysToManufacture,
            p.ProductLine,
            p.Class,
            p.Style,
            ps.Name  AS Subcategory,
            pm.Name  AS ProductModel,
            p.SellStartDate,
            p.SellEndDate,
            p.DiscontinuedDate,
            p.ModifiedDate
        FROM Production.Product p
        LEFT JOIN Production.ProductSubcategory ps
            ON p.ProductSubcategoryID = ps.ProductSubcategoryID
        LEFT JOIN Production.ProductModel pm
            ON p.ProductModelID = pm.ProductModelID
        WHERE p.ProductID = @ProductID;

        SET @StatusCode = 200;
        SET @Message    = N'Consulta exitosa: producto ' + CAST(@ProductID AS NVARCHAR(10)) + '.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- INSERT
    -- --------------------------------------------------------
    IF @Action = 'INSERT'
    BEGIN
        -- Validar campos obligatorios
        IF @Name IS NULL OR @ProductNumber IS NULL OR @SafetyStockLevel IS NULL
           OR @ReorderPoint IS NULL OR @StandardCost IS NULL OR @ListPrice IS NULL
           OR @DaysToManufacture IS NULL OR @SellStartDate IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: Campos obligatorios faltantes '
                              + N'(Name, ProductNumber, SafetyStockLevel, ReorderPoint, '
                              + N'StandardCost, ListPrice, DaysToManufacture, SellStartDate).';
            RETURN;
        END

        -- Verificar duplicado por Name
        IF EXISTS (
            SELECT 1 FROM Production.Product WHERE Name = @Name
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: Ya existe un producto con el nombre "' + @Name + '".';
            RETURN;
        END

        -- Verificar duplicado por ProductNumber
        IF EXISTS (
            SELECT 1 FROM Production.Product WHERE ProductNumber = @ProductNumber
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: Ya existe un producto con ProductNumber = '
                              + @ProductNumber + '.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                INSERT INTO Production.Product
                    (Name, ProductNumber, MakeFlag, FinishedGoodsFlag,
                     Color, SafetyStockLevel, ReorderPoint,
                     StandardCost, ListPrice, Size,
                     SizeUnitMeasureCode, WeightUnitMeasureCode, Weight,
                     DaysToManufacture, ProductLine, Class, Style,
                     ProductSubcategoryID, ProductModelID,
                     SellStartDate, SellEndDate, DiscontinuedDate,
                     rowguid, ModifiedDate)
                VALUES
                    (@Name,
                     @ProductNumber,
                     ISNULL(@MakeFlag, 1),
                     ISNULL(@FinishedGoodsFlag, 1),
                     @Color,
                     @SafetyStockLevel,
                     @ReorderPoint,
                     @StandardCost,
                     @ListPrice,
                     @Size,
                     @SizeUnitMeasureCode,
                     @WeightUnitMeasureCode,
                     @Weight,
                     @DaysToManufacture,
                     @ProductLine,
                     @Class,
                     @Style,
                     @ProductSubcategoryID,
                     @ProductModelID,
                     @SellStartDate,
                     @SellEndDate,
                     @DiscontinuedDate,
                     NEWID(),
                     GETDATE());

                SET @OutProductID = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Producto insertado con ProductID = '
                              + CAST(@OutProductID AS NVARCHAR(10)) + '.';
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
        IF @ProductID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: ProductID es requerido para UPDATE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Production.Product WHERE ProductID = @ProductID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un producto con ProductID = '
                              + CAST(@ProductID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        -- Verificar duplicados de Name en otro producto
        IF @Name IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM Production.Product
               WHERE Name = @Name AND ProductID <> @ProductID
           )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: El nombre "' + @Name + N'" ya está en uso por otro producto.';
            RETURN;
        END

        -- Verificar duplicados de ProductNumber en otro producto
        IF @ProductNumber IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM Production.Product
               WHERE ProductNumber = @ProductNumber AND ProductID <> @ProductID
           )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: ProductNumber ' + @ProductNumber
                              + N' ya está en uso por otro producto.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                UPDATE Production.Product
                SET
                    Name                  = ISNULL(@Name,                  Name),
                    ProductNumber         = ISNULL(@ProductNumber,         ProductNumber),
                    MakeFlag              = ISNULL(@MakeFlag,              MakeFlag),
                    FinishedGoodsFlag     = ISNULL(@FinishedGoodsFlag,     FinishedGoodsFlag),
                    Color                 = ISNULL(@Color,                 Color),
                    SafetyStockLevel      = ISNULL(@SafetyStockLevel,      SafetyStockLevel),
                    ReorderPoint          = ISNULL(@ReorderPoint,          ReorderPoint),
                    StandardCost          = ISNULL(@StandardCost,          StandardCost),
                    ListPrice             = ISNULL(@ListPrice,             ListPrice),
                    Size                  = ISNULL(@Size,                  Size),
                    SizeUnitMeasureCode   = ISNULL(@SizeUnitMeasureCode,   SizeUnitMeasureCode),
                    WeightUnitMeasureCode = ISNULL(@WeightUnitMeasureCode, WeightUnitMeasureCode),
                    Weight                = ISNULL(@Weight,                Weight),
                    DaysToManufacture     = ISNULL(@DaysToManufacture,     DaysToManufacture),
                    ProductLine           = ISNULL(@ProductLine,           ProductLine),
                    Class                 = ISNULL(@Class,                 Class),
                    Style                 = ISNULL(@Style,                 Style),
                    ProductSubcategoryID  = ISNULL(@ProductSubcategoryID,  ProductSubcategoryID),
                    ProductModelID        = ISNULL(@ProductModelID,        ProductModelID),
                    SellStartDate         = ISNULL(@SellStartDate,         SellStartDate),
                    SellEndDate           = ISNULL(@SellEndDate,           SellEndDate),
                    DiscontinuedDate      = ISNULL(@DiscontinuedDate,      DiscontinuedDate),
                    ModifiedDate          = GETDATE()
                WHERE ProductID = @ProductID;

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Producto ' + CAST(@ProductID AS NVARCHAR(10))
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
        IF @ProductID IS NULL
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: ProductID es requerido para DELETE.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Production.Product WHERE ProductID = @ProductID
        )
        BEGIN
            SET @StatusCode = 400;
            SET @Message    = N'Error 400: No existe un producto con ProductID = '
                              + CAST(@ProductID AS NVARCHAR(10)) + '.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRANSACTION;

                -- Eliminar dependencias en orden correcto
                DELETE FROM Production.ProductListPriceHistory
                WHERE ProductID = @ProductID;

                DELETE FROM Production.ProductCostHistory
                WHERE ProductID = @ProductID;

                DELETE FROM Production.ProductInventory
                WHERE ProductID = @ProductID;

                DELETE FROM Production.ProductReview
                WHERE ProductID = @ProductID;

                DELETE FROM Production.BillOfMaterials
                WHERE ComponentID = @ProductID
                   OR ProductAssemblyID = @ProductID;

                -- Eliminar Product
                DELETE FROM Production.Product
                WHERE ProductID = @ProductID;

            COMMIT TRANSACTION;

            SET @StatusCode = 200;
            SET @Message    = N'Éxito 200: Producto ' + CAST(@ProductID AS NVARCHAR(10))
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
-- EJEMPLOS DE USO - Product
-- ============================================================

-- Obtener todos los productos
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Production.SP_Product
    @Action     = 'SELECT_ALL',
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Obtener un producto
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Production.SP_Product
    @Action     = 'SELECT_ONE',
    @ProductID  = 1,
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Insertar un producto
DECLARE @Code INT, @Msg NVARCHAR(500), @NewID INT;
EXEC Production.SP_Product
    @Action               = 'INSERT',
    @Name                 = 'Mountain Bike Pro 2024',
    @ProductNumber        = 'MB-PRO-2024',
    @MakeFlag             = 1,
    @FinishedGoodsFlag    = 1,
    @Color                = 'Black',
    @SafetyStockLevel     = 100,
    @ReorderPoint         = 75,
    @StandardCost         = 450.00,
    @ListPrice            = 899.99,
    @Size                 = 'L',
    @DaysToManufacture    = 5,
    @ProductLine          = 'M ',
    @Class                = 'H ',
    @Style                = 'U ',
    @SellStartDate        = '2024-01-01',
    @OutProductID         = @NewID  OUTPUT,
    @StatusCode           = @Code   OUTPUT,
    @Message              = @Msg    OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message, @NewID AS NuevoProductID;
GO

-- Actualizar un producto
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Production.SP_Product
    @Action     = 'UPDATE',
    @ProductID  = 1,
    @ListPrice  = 950.00,
    @Color      = 'Red',
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO

-- Eliminar un producto
DECLARE @Code INT, @Msg NVARCHAR(500);
EXEC Production.SP_Product
    @Action     = 'DELETE',
    @ProductID  = 1,
    @StatusCode = @Code OUTPUT,
    @Message    = @Msg  OUTPUT;
SELECT @Code AS StatusCode, @Msg AS Message;
GO
