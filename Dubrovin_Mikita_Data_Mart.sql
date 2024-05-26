-- 1) Create a fact table: FactSupplierPurchases
CREATE TABLE FactSupplierPurchases (
    PurchaseID SERIAL PRIMARY KEY,
    SupplierID INT,
    TotalPurchaseAmount DECIMAL,
    PurchaseDate DATE,
    NumberOfProducts INT,
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID)
);

-- Populate the FactSupplierPurchases table with data aggregated from the staging tables
INSERT INTO FactSupplierPurchases (SupplierID, TotalPurchaseAmount, PurchaseDate, NumberOfProducts)
SELECT 
    P.SupplierID, 
    SUM(OD.UnitPrice * OD.Qty) AS TotalPurchaseAmount, 
    CURRENT_DATE AS PurchaseDate, 
    COUNT(DISTINCT OD.ProductID) AS NumberOfProducts
FROM Staging_Order_Details OD
JOIN Staging_Products P ON OD.ProductID = P.ProductID
GROUP BY P.SupplierID;

--- Supplier spending analysis
SELECT
    S.CompanyName,
    SUM(FSP.TotalPurchaseAmount) AS TotalSpend,
    EXTRACT(YEAR FROM FSP.PurchaseDate) AS Year,
    EXTRACT(MONTH FROM FSP.PurchaseDate) AS Month
FROM FactSupplierPurchases FSP
JOIN DimSupplier S ON FSP.SupplierID = S.SupplierID
GROUP BY S.CompanyName, Year, Month
ORDER BY TotalSpend DESC;

-- Product cost breakdown by supplier
SELECT
    S.CompanyName,
    P.ProductName,
    AVG(OD.UnitPrice) AS AverageUnitPrice,
    SUM(OD.Qty) AS TotalQuantityPurchased,
    SUM(OD.UnitPrice * OD.Qty) AS TotalSpend
FROM Staging_Order_Details OD
JOIN Staging_Products P ON OD.ProductID = P.ProductID
JOIN DimSupplier S ON P.SupplierID = S.SupplierID
GROUP BY S.CompanyName, P.ProductName
ORDER BY S.CompanyName, TotalSpend DESC;

-- Top five products by total purchases per supplier
SELECT
    S.CompanyName,
    P.ProductName,
    SUM(OD.UnitPrice * OD.Qty) AS TotalSpend
FROM Staging_Order_Details OD
JOIN Staging_Products P ON OD.ProductID = P.ProductID
JOIN DimSupplier S ON P.SupplierID = S.SupplierID
GROUP BY S.CompanyName, P.ProductName
ORDER BY S.CompanyName, TotalSpend DESC
LIMIT 5;

-- Supplier performance report не работает 

-- Supplier reliability score report не работает 

-- 2) Create a fact table: FactProductSales
CREATE TABLE FactProductSales (
    FactSalesID SERIAL PRIMARY KEY,
    DateID INT,
    ProductID INT,
    QuantitySold INT,
    TotalSales DECIMAL(10,2),
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID)
);

-- Insert into FactProductSales table:
INSERT INTO FactProductSales (DateID, ProductID, QuantitySold, TotalSales)
SELECT 
    (SELECT DateID FROM DimDate WHERE Date = S.OrderDate) AS DateID,
    P.ProductID, 
    SOD.Qty, 
    (SOD.Qty * SOD.UnitPrice) AS TotalSales
FROM Staging_Order_Details SOD
JOIN Staging_Orders S ON SOD.OrderID = S.OrderID
JOIN Staging_Products P ON SOD.ProductID = P.ProductID;

-- Top-selling products
SELECT 
    P.ProductName,
    SUM(FPS.QuantitySold) AS TotalQuantitySold,
    SUM(FPS.TotalSales) AS TotalRevenue
FROM 
    FactProductSales FPS
JOIN DimProduct P ON FPS.ProductID = P.ProductID
GROUP BY P.ProductName
ORDER BY TotalRevenue DESC
LIMIT 5;

-- Products below reorder не работает 

-- Sales trends by product category
SELECT 
    C.CategoryName, 
    EXTRACT(YEAR FROM D.Date) AS Year,
    EXTRACT(MONTH FROM D.Date) AS Month,
    SUM(FPS.QuantitySold) AS TotalQuantitySold,
    SUM(FPS.TotalSales) AS TotalRevenue
FROM 
    FactProductSales FPS
JOIN DimProduct P ON FPS.ProductID = P.ProductID
JOIN DimCategory C ON P.CategoryID = C.CategoryID
JOIN DimDate D ON FPS.DateID = D.DateID
GROUP BY C.CategoryName, Year, Month, D.Date
ORDER BY Year, Month, TotalRevenue DESC;

-- Inventory valuation
SELECT 
    P.ProductName,
    P.UnitsInStock,
    P.UnitPrice,
    (P.UnitsInStock * P.UnitPrice) AS InventoryValue
FROM 
    DimProduct P
ORDER BY InventoryValue DESC;	
	
-- Supplier performance based on product sales
SELECT 
    S.CompanyName,
    COUNT(DISTINCT FPS.FactSalesID) AS NumberOfSalesTransactions,
    SUM(FPS.QuantitySold) AS TotalProductsSold,
    SUM(FPS.TotalSales) AS TotalRevenueGenerated
FROM 
    FactProductSales FPS
JOIN DimProduct P ON FPS.ProductID = P.ProductID
JOIN DimSupplier S ON P.SupplierID = S.SupplierID
GROUP BY S.CompanyName
ORDER BY TotalRevenueGenerated DESC;

-- 3) не работает 	

-- 4) All tables were created in the first task and aggregate sales by month and category
SELECT D.Month, D.Year, C.CategoryName, SUM(FS.TotalAmount) AS TotalSales
FROM FactSales FS
JOIN DimDate D ON FS.DateID = D.DateID
JOIN DimCategory C ON FS.CategoryID = C.CategoryID
GROUP BY D.Month, D.Year, C.CategoryName
ORDER BY D.Year, D.Month, TotalSales DESC;	

-- Top-selling products per quarter
SELECT D.Quarter, D.Year, P.ProductName, SUM(FS.QuantitySold) AS TotalQuantitySold
FROM FactSales FS
JOIN DimDate D ON FS.DateID = D.DateID
JOIN DimProduct P ON FS.ProductID = P.ProductID
GROUP BY D.Quarter, D.Year, P.ProductName
ORDER BY D.Year, D.Quarter, TotalQuantitySold DESC
LIMIT 5;

-- Customer sales overview
SELECT CU.CompanyName, SUM(FS.TotalAmount) AS TotalSpent, COUNT(DISTINCT FS.SalesID) AS TransactionsCount
FROM FactSales FS
JOIN DimCustomer CU ON FS.CustomerID = CU.CustomerID
GROUP BY CU.CompanyName
ORDER BY TotalSpent DESC;
				
-- Sales performance by employee	
SELECT E.FirstName, E.LastName, COUNT(FS.SalesID) AS NumberOfSales, SUM(FS.TotalAmount) AS TotalSales
FROM FactSales FS
JOIN DimEmployee E ON FS.EmployeeID = E.EmployeeID
GROUP BY E.FirstName, E.LastName
ORDER BY TotalSales DESC;	
					
-- Monthly sales growth rate	
WITH MonthlySales AS (
    SELECT
        D.Year,
        D.Month,
        SUM(FS.TotalAmount) AS TotalSales
    FROM FactSales FS
    JOIN DimDate D ON FS.DateID = D.DateID
    GROUP BY D.Year, D.Month
),
MonthlyGrowth AS (
    SELECT
        Year,
        Month,
        TotalSales,
        LAG(TotalSales) OVER (ORDER BY Year, Month) AS PreviousMonthSales,
        (TotalSales - LAG(TotalSales) OVER (ORDER BY Year, Month)) / LAG(TotalSales) OVER (ORDER BY Year, Month) AS GrowthRate
    FROM MonthlySales
)
SELECT * FROM MonthlyGrowth;
