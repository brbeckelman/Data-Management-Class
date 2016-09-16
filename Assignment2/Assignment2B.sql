-- QUESTION 1
CREATE TABLE Managers (
  RegID       NUMBER,
  Region      VARCHAR2(10 BYTE),
  RegManager  VARCHAR2(10 BYTE),
  PRIMARY KEY (RegID),
  CONSTRAINT ch_reg CHECK (Region IN ('East', 'South', 'Central', 'West')));
  
CREATE TABLE Products (
  ProdID        NUMBER,
  ProdName      VARCHAR2(100 BYTE),
  ProdCat       VARCHAR2(30 BYTE),
  ProdSubCat    VARCHAR2(30 BYTE),
  ProdCont      VARCHAR2(20 BYTE),
  ProdUnitPrice NUMBER(7,2),
  ProdMargin    NUMBER(5,3),
  PRIMARY KEY (ProdID),
  CONSTRAINT ch_cat CHECK (ProdCat IN ('Technology', 'Furniture', 'Office Supplies')),
  CONSTRAINT ch_cont CHECK (ProdCont IN ('Jumbo Drum', 'Medium Box', 'Jumbo Box', 'Wrap Bag', 
                                          'Large Box', 'Small Box', 'Small Pack')));
                                          
CREATE TABLE Orders (
  OrderID   NUMBER,
  Status    VARCHAR2(10 BYTE),
  PRIMARY KEY (OrderID));
  
CREATE TABLE Customers (
  CustID      NUMBER,
  CustName    VARCHAR2(35 BYTE),
  CustReg     NUMBER(1,0),
  CustState   VARCHAR2(20 BYTE),
  CustCity    VARCHAR2(20 BYTE),
  CustZip     NUMBER(5,0),
  CustSeg     VARCHAR2(15 BYTE),
  PRIMARY KEY (CustID),
  FOREIGN KEY (CustReg) REFERENCES Managers(RegID) ON DELETE CASCADE,
  CONSTRAINT ch_seg CHECK (CustSeg IN ('Home Office', 'Corporate', 'Small Business', 'Consumer')));
  
CREATE TABLE OrderDet (
  OrderID       NUMBER,
  CustID        NUMBER,
  ProdID        NUMBER,
  OrdPriority   VARCHAR2(15 BYTE),
  OrdDiscount   NUMBER(3,2),
  OrdShipMode   VARCHAR2(15 BYTE),
  OrdDate       DATE,
  OrdShipDate   DATE,
  OrdShipCost   NUMBER(5,2),
  OrdQty        NUMBER,
  OrdSales      NUMBER(8,2),
  PRIMARY KEY (OrderID, CustID, ProdID),
  FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
  FOREIGN KEY (CustID) REFERENCES Customers(CustID),
  FOREIGN KEY (ProdID) REFERENCES Products(ProdID),
  CONSTRAINT ch_priority CHECK (OrdPriority IN ('Low', 'Medium', 'High', 'Critical', 'Not Specified')),
  CONSTRAINT ch_mode CHECK (OrdShipMode IN ('Regular Air', 'Delivery Truck', 'Express Air')));
  
-- QUESTION 2: ORDER Cancellation
-- a)
SELECT ROUND(R.ReturnCount/O.TotOrders,4) AS FracReturned
FROM (
  SELECT COUNT(OrderID) AS ReturnCount
  FROM Orders
  WHERE Status LIKE 'Returned') R,
  (SELECT COUNT(OrderID) AS TotOrders
  FROM Orders) O;
  
-- b)
SELECT SUM(D.OrdSales) AS SalesReturned
FROM Orders O, OrderDet D
WHERE O.OrderID = D.OrderID AND O.Status LIKE 'Returned';

-- c)
SELECT CustName, RetOrders FROM (
  SELECT C.CustName, COUNT(O.OrderID) RetOrders, RANK() OVER (ORDER BY COUNT(O.OrderID) DESC) AS Rank
  FROM Orders O, OrderDet D, Customers C
  WHERE O.OrderID = D.OrderID AND D.CustID = C.CustID AND O.Status LIKE 'Returned'
  GROUP BY C.CustName)
WHERE Rank <= 5;

-- QUESTION 3: CUSTOMER Related
-- a) 
SELECT CustName, TotSales FROM (
  SELECT C.CustName, SUM(D.OrdSales) AS TotSales, RANK() OVER (ORDER BY SUM(D.OrdSales) DESC) AS Rank
  FROM Customers C, OrderDet D
  WHERE C.CustID = D.CustID
  GROUP BY C.CustName)
WHERE Rank <= 10;

-- b)
-- Percent of customers who buy all 3 product categories
SELECT ROUND(100*(AllCatsCount/TotCount),2) AS AllCatPerc
FROM(
  SELECT COUNT(CatsPurchased) AS AllCatsCount
  FROM (
    SELECT CustName, COUNT(ProdCat) AS CatsPurchased
    FROM (
      SELECT C.CustName, P.ProdCat
      FROM Customers C, Products P, OrderDet O
      WHERE C.CustID = O.CustID AND O.ProdID = P.ProdID
      GROUP BY C.CustName, P.ProdCat
      ORDER BY C.CustName)
    GROUP BY CustName
    ORDER BY CatsPurchased)
  WHERE CatsPurchased = 3),
  (SELECT COUNT(CatsPurchased) AS TotCount
  FROM (
    SELECT CustName, COUNT(ProdCat) AS CatsPurchased
    FROM (
      SELECT C.CustName, P.ProdCat
      FROM Customers C, Products P, OrderDet O
      WHERE C.CustID = O.CustID AND O.ProdID = P.ProdID
      GROUP BY C.CustName, P.ProdCat
      ORDER BY C.CustName)
    GROUP BY CustName
    ORDER BY CatsPurchased));

-- Percent of sales in each category for each customer
SELECT X.CustName, Y.ProdCat, Y.CatSales, ROUND(100*(Y.CatSales/X.CustSales),2) AS CatPerc
FROM (
      SELECT C.CustName, SUM(D.OrdSales) AS CustSales
      FROM Customers C, OrderDet D
      WHERE C.CustID = D.CustID
      GROUP BY C.CustName) X,
      (SELECT C.CustName, P.ProdCat, SUM(D.OrdSales) AS CatSales
      FROM Products P, OrderDet D, Customers C
      WHERE C.CustID = D.CustID AND P.ProdID = D.ProdID
      GROUP BY C.CustName, P.ProdCat) Y
WHERE X.CustName = Y.CustName AND ROUND(100*(Y.CatSales/X.CustSales),2) < 10
ORDER BY CustName;

-- QUESTION 4:
-- a) 
SELECT SUM(ActPrice) - SUM(TheorPrice) AS TotalDiff FROM (
  SELECT D.OrderID, ((P.ProdUnitPrice*D.OrdQty)*(1-D.OrdDiscount)+OrdShipCost) AS TheorPrice, D.OrdSales AS ActPrice
  FROM OrderDet D, Products P
  WHERE D.ProdID = P.ProdID);
  
-- b) 
SELECT Region, RegManager, ROUND(AVG(ActPrice),2) AS AvgAct, ROUND(AVG(TheorPrice),2) AS AvgTheor, 
        ROUND(100*(AVG(ActPrice) - AVG(TheorPrice))/AVG(TheorPrice),2) AS AvgPercDiff 
FROM (
      SELECT D.OrderID, M.Region, M.RegManager, ((P.ProdUnitPrice*D.OrdQty)*(1-D.OrdDiscount)+OrdShipCost) AS TheorPrice, D.OrdSales AS ActPrice
      FROM OrderDet D, Products P, Managers M, Customers C
      WHERE D.ProdID = P.ProdID AND M.RegID = C.CustReg AND C.CustID = D.CustID)
GROUP BY Region, RegManager
ORDER BY AvgPercDiff;

-- QUESTION 5:
-- a) 
SELECT ProdName
FROM Products
WHERE REGEXP_LIKE (ProdName, '\d');

-- b)
SELECT Rank, ProdName, TotSales FROM (
  SELECT P.ProdName, SUM(D.OrdSales) AS TotSales, RANK() OVER (ORDER BY SUM(D.OrdSales) DESC) AS Rank
  FROM Products P, OrderDet D
  WHERE P.ProdID = D.ProdID AND EXTRACT(YEAR FROM D.OrdDate) = 2011
  GROUP BY P.ProdName)
WHERE Rank <=5;

-- c)
SELECT Rank, ProdName, TotMargin FROM (
  SELECT P.ProdName, SUM(D.OrdSales*P.ProdMargin) AS TotMargin, RANK() OVER (ORDER BY SUM(D.OrdSales*P.ProdMargin) DESC) AS RANK
  FROM Products P, OrderDet D
  WHERE P.ProdID = D.ProdID
  GROUP BY P.ProdName)
WHERE Rank <= 10;

-- d)
SELECT Rank, ProdName, TotSales FROM (
  SELECT P.ProdName, SUM(D.OrdSales) AS TotSales, RANK() OVER (ORDER BY SUM(D.OrdSales)) AS Rank
  FROM Products P, OrderDet D
  WHERE P.ProdID = D.ProdID
  GROUP BY P.ProdName)
WHERE Rank <= 5;
