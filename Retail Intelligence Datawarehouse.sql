USE DATABASE GLOBAL_RETAIL
GLOBAL_RETAIL.RAW_SALES.TABLE1
USE SCHEMA RAW_SALES;

SELECT * FROM TABLE1 LIMIT 10;


select *
from GLOBAL_SUPERSTORE_FULL_DATASET limit 2

-- To Know the Datatypes of the columns
DESCRIBE TABLE GLOBAL_SUPERSTORE_FULL_DATASET;


CREATE TABLE dimCategory (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(100)
);


CREATE TABLE dimSubCategory (
    SubCategoryID INT PRIMARY KEY,
    SubCategoryName VARCHAR(100),
    CategoryID INT,
    FOREIGN KEY (CategoryID) REFERENCES dimCategory(CategoryID)
);


CREATE TABLE dimProduct (
    ProductID VARCHAR(50) PRIMARY KEY,
    ProductName VARCHAR(255),
    SubCategoryID INT,
    FOREIGN KEY (SubCategoryID) REFERENCES dimSubCategory(SubCategoryID)
);


CREATE TABLE dimLocation (
    LocationID INT PRIMARY KEY,
    City VARCHAR(100),
    State VARCHAR(100),
    Country VARCHAR(100),
    PostalCode VARCHAR(20),
    Region VARCHAR(100),
    Market VARCHAR(100)
);



CREATE TABLE dimCustomer (
    CustomerID VARCHAR(50) PRIMARY KEY,
    CustomerName VARCHAR(255),
    Segment VARCHAR(100),
    LocationID INT,
    FOREIGN KEY (LocationID) REFERENCES dimLocation(LocationID)
);



CREATE TABLE dimDate (
    DateID INT PRIMARY KEY, -- format: YYYYMMDD
    FullDate DATE,
    Day INT,
    Month INT,
    MonthName VARCHAR(20),
    Quarter INT,
    Year INT
);




INSERT INTO dimCategory (CategoryID, CategoryName)
SELECT
    DENSE_RANK() OVER (ORDER BY Category) AS CategoryID,
    Category
FROM (
    SELECT DISTINCT Category FROM GLOBAL_SUPERSTORE_FULL_DATASET
) AS distinct_categories;


select * from dimcategory;



-- subcategory
INSERT INTO dimSubCategory (SubCategoryID, SubCategoryName, CategoryID)
SELECT
    DENSE_RANK() OVER (ORDER BY s.SubCategory) AS SubCategoryID,
    s.SubCategory,
    c.CategoryID
FROM (
    SELECT DISTINCT "Sub-Category" AS SubCategory, Category 
    FROM GLOBAL_SUPERSTORE_FULL_DATASET
) AS s
JOIN dimCategory c ON s.Category = c.CategoryName;


--
select * from dimsubcategory



--dimproduct
INSERT INTO dimProduct (ProductID, ProductName, SubCategoryID)
SELECT DISTINCT
    f."Product ID",
    f."Product Name",
    s.SubCategoryID
FROM GLOBAL_SUPERSTORE_FULL_DATASET f
JOIN dimSubCategory s 
    ON f."Sub-Category" = s.SubCategoryName;


select * from dimproduct;


--dimlocation
INSERT INTO dimLocation (LocationID, City, State, Country, PostalCode, Region, Market)
SELECT
    DENSE_RANK() OVER (ORDER BY City, State, Country, "Postal Code") AS LocationID,
    City,
    State,
    Country,
    "Postal Code",
    Region,
    Market
FROM (
    SELECT DISTINCT City, State, Country, "Postal Code", Region, Market
    FROM GLOBAL_SUPERSTORE_FULL_DATASET
) AS locs;


select * from dimlocation


--dimcustomer
INSERT INTO dimCustomer (CustomerID, CustomerName, Segment, LocationID)
SELECT DISTINCT
    f."Customer ID",
    f."Customer Name",
    f.Segment,
    l.LocationID
FROM GLOBAL_SUPERSTORE_FULL_DATASET f
JOIN dimLocation l
  ON f.City = l.City 
     AND f.State = l.State 
     AND f."Postal Code" = l.PostalCode;


select * from dimcustomer;


--dimdate
-- Step 1: Insert Order Dates
-- Insert Order Dates
INSERT INTO dimDate (DateID, FullDate, Day, Month, MonthName, Quarter, Year)
SELECT DISTINCT
    TO_NUMBER(TO_CHAR(TO_DATE("Order Date", 'DD-MM-YYYY'), 'YYYYMMDD')) AS DateID,
    TO_DATE("Order Date", 'DD-MM-YYYY') AS FullDate,
    EXTRACT(DAY FROM TO_DATE("Order Date", 'DD-MM-YYYY')) AS Day,
    EXTRACT(MONTH FROM TO_DATE("Order Date", 'DD-MM-YYYY')) AS Month,
    TO_CHAR(TO_DATE("Order Date", 'DD-MM-YYYY'), 'MMMM') AS MonthName,
    EXTRACT(QUARTER FROM TO_DATE("Order Date", 'DD-MM-YYYY')) AS Quarter,
    EXTRACT(YEAR FROM TO_DATE("Order Date", 'DD-MM-YYYY')) AS Year
FROM GLOBAL_SUPERSTORE_FULL_DATASET;

-- Insert missing Ship Dates
INSERT INTO dimDate (DateID, FullDate, Day, Month, MonthName, Quarter, Year)
SELECT DISTINCT
    TO_NUMBER(TO_CHAR(TO_DATE("Ship Date", 'DD-MM-YYYY'), 'YYYYMMDD')) AS DateID,
    TO_DATE("Ship Date", 'DD-MM-YYYY') AS FullDate,
    EXTRACT(DAY FROM TO_DATE("Ship Date", 'DD-MM-YYYY')) AS Day,
    EXTRACT(MONTH FROM TO_DATE("Ship Date", 'DD-MM-YYYY')) AS Month,
    TO_CHAR(TO_DATE("Ship Date", 'DD-MM-YYYY'), 'MMMM') AS MonthName,
    EXTRACT(QUARTER FROM TO_DATE("Ship Date", 'DD-MM-YYYY')) AS Quarter,
    EXTRACT(YEAR FROM TO_DATE("Ship Date", 'DD-MM-YYYY')) AS Year
FROM GLOBAL_SUPERSTORE_FULL_DATASET
WHERE TO_NUMBER(TO_CHAR(TO_DATE("Ship Date", 'DD-MM-YYYY'), 'YYYYMMDD')) 
      NOT IN (SELECT DateID FROM dimDate);





SELECT DISTINCT MonthName FROM dimDate ORDER BY MonthName;

select * from dimdate limit 2


--TRUNCATE table dimdate







-- To Know the Datatypes of the columns
DESCRIBE TABLE dimdate;

describe table dimcustomer;

select * from DIMDATE limit 3


--fact order
CREATE OR REPLACE TABLE factOrder (
    OrderID VARCHAR PRIMARY KEY,
    ProductID VARCHAR,
    CustomerID VARCHAR,
    DateID NUMBER(38,0),         -- Must match dimDate.DateID
    ShipDateID NUMBER(38,0),     -- FIXED: previously DATE, now correct
    OrderPriority VARCHAR,
    ShipMode VARCHAR,
    Sales DECIMAL(10,2),
    Quantity INT,
    Discount DECIMAL(5,2),
    Profit DECIMAL(10,2),
    ShippingCost DECIMAL(10,2)
);


DESC TABLE GLOBAL_SUPERSTORE_FULL_DATASET;



INSERT INTO factOrder (
    OrderID, ProductID, CustomerID, DateID, ShipDateID,
    OrderPriority, ShipMode, Sales, Quantity, Discount,
    Profit, ShippingCost
)
SELECT
    "Order ID",
    "Product ID",
    "Customer ID",
    od.DateID,
    sd.DateID,
    "Order Priority",
    "Ship Mode",
    Sales,
    Quantity,
    Discount,
    Profit,
    "Shipping Cost"
FROM GLOBAL_SUPERSTORE_FULL_DATASET g
JOIN dimDate od ON od.FullDate = TO_DATE(g."Order Date", 'DD-MM-YYYY')
JOIN dimDate sd ON sd.FullDate = TO_DATE(g."Ship Date", 'DD-MM-YYYY');



select * from factorder limit 2



--analysis


--Top 8 Analysis


-- Top 10 Most Profitable Products

SELECT 
  p.ProductName,
  SUM(f.Profit) AS TotalProfit
FROM factOrder f
JOIN dimProduct p ON f.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY TotalProfit DESC
LIMIT 10;


-- Sales by Category & Sub-Category

SELECT 
  c.CategoryName,
  s.SubCategoryName,
  SUM(f.Sales) AS TotalSales
FROM factOrder f
JOIN dimProduct p ON f.ProductID = p.ProductID
JOIN dimSubCategory s ON p.SubCategoryID = s.SubCategoryID
JOIN dimCategory c ON s.CategoryID = c.CategoryID
GROUP BY c.CategoryName, s.SubCategoryName
ORDER BY TotalSales DESC;


-- Regional Performance

SELECT 
  loc.Region,
  SUM(f.Sales) AS TotalSales,
  SUM(f.Profit) AS TotalProfit
FROM factOrder f
JOIN dimCustomer cust ON f.CustomerID = cust.CustomerID
JOIN dimLocation loc ON cust.LocationID = loc.LocationID
GROUP BY loc.Region
ORDER BY TotalProfit DESC;


-- Shipping Mode Preference

SELECT 
  ShipMode,
  COUNT(*) AS OrderCount,
FROM factOrder
GROUP BY ShipMode
ORDER BY OrderCount DESC;


-- Segment-wise Sales and Profit

SELECT 
  cust.Segment,
  SUM(f.Sales) AS TotalSales,
  SUM(f.Profit) AS TotalProfit
FROM factOrder f
JOIN dimCustomer cust ON f.CustomerID = cust.CustomerID
GROUP BY cust.Segment
ORDER BY TotalSales DESC;


-- Top Customers by Sales

SELECT 
  cust.CustomerName,
  SUM(f.Sales) AS TotalSales
FROM factOrder f
JOIN dimCustomer cust ON f.CustomerID = cust.CustomerID
GROUP BY cust.CustomerName
ORDER BY TotalSales DESC
LIMIT 10;


-- Monthly Sales Trend

SELECT 
  d.Year,
  d.Month,
  d.MonthName,
  SUM(f.Sales) AS TotalSales
FROM factOrder f
JOIN dimDate d ON f.DateID = d.DateID
GROUP BY d.Year, d.Month, d.MonthName
ORDER BY d.Year, d.Month;


-- Impact of Discounts on Profit

SELECT 
  Discount,
  ROUND(SUM(Sales), 2) AS TotalSales,
  ROUND(SUM(Profit), 2) AS TotalProfit
FROM factOrder
GROUP BY Discount
ORDER BY Discount;







