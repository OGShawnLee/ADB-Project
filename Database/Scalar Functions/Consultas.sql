--información básica del empleado
SELECT
    e.BusinessEntityID AS Id,
    p.FirstName,
    p.MiddleName,
    e.JobTitle,
    e.BirthDate,
    e.MaritalStatus,
    e.Gender,
    dbo.fn_CalcularEdad(e.BirthDate) AS Edad
FROM HumanResources.Employee e
INNER JOIN Person.Person p
    ON e.BusinessEntityID = p.BusinessEntityID;
GO

--información de los productos

SELECT
    ProductID AS Id,
    Name,
    ProductNumber,
    ListPrice,
    dbo.fn_PrecioConIVA(ListPrice) AS PrecioConIVA
FROM Production.Product
ORDER BY ListPrice DESC;
GO

--información de clientes 
SELECT
    c.CustomerID AS Id,
    p.FirstName,
    p.MiddleName,
    c.AccountNumber,
    c.CreditLimit,
    dbo.fn_EstatusCredito(c.CreditLimit) AS EstatusCredito
FROM Sales.Customer c
INNER JOIN Person.Person p
    ON c.PersonID = p.BusinessEntityID;
GO


--creación de columna CreditLimit 
ALTER TABLE Sales.Customer
ADD CreditLimit MONEY NOT NULL
CONSTRAINT DF_Customer_CreditLimit DEFAULT 0;
GO

UPDATE Sales.Customer
SET CreditLimit =
    CASE
        WHEN CustomerID % 2 = 0 THEN 10000
        ELSE 5000
    END;
GO

