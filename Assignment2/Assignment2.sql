-- ASSIGNMENT 2

-- PART A: Coffee Sales
-- A. Just for Starters - SQL Questions
-- A1:
CREATE TABLE TempA1 AS
SELECT StateName, AVG(AreaSales) as StateAvg
FROM (
  SELECT S.StateName, A.AreaID, SUM(F.ActSales) as AreaSales
  FROM States S, AreaCode A, FactCoffee F
  WHERE S.StateID = A.StateID AND A.AreaID = F.AreaID AND EXTRACT(year from F.FactDate) = 2013
  GROUP BY S.StateName, A.AreaID
  )
GROUP BY StateName;

SELECT A.AreaID, S.StateName, ROUND(T.StateAvg,2) as StateAvg, SUM(F.ActSales) as AreaSales
FROM AreaCode A, States S, FactCoffee F, TempA1 T
WHERE A.StateID = S.StateID AND A.AreaID = F.AreaID AND S.StateName = T.StateName
GROUP BY A.AreaID, S.StateName, StateAvg, ROUND(T.StateAvg,2)
HAVING SUM(F.ActSales) > 1.1*T.StateAvg
ORDER BY S.StateName;

-- A2:
SELECT P.ProdName, SUM(F.ActSales) as TotalSales, ROUND(100*(SUM(F.ActProfit)/SUM(F.ActSales)),2) as ProfMargPerc
FROM ProdCoffee P, FactCoffee F
WHERE P.ProductID = F.ProductID
GROUP BY P.ProdName
HAVING ROUND(100*(SUM(F.ActProfit)/SUM(F.ActSales)),2) > 15
ORDER BY TotalSales DESC;

-- A3:
SELECT * FROM (  
  SELECT A.AreaID, P.ProdLine, SUM(F.ActProfit) as AreaProfit
  FROM AreaCode A, ProdCoffee P, FactCoffee F
  WHERE A.AreaID = F.AreaID AND P.ProductID = F.ProductID AND EXTRACT(year from F.FactDate) = 2012
  GROUP BY A.AreaID, P.ProdLine
  )
PIVOT (
  SUM(AreaProfit)
  FOR ProdLine IN ('Beans' as BeansProf, 'Leaves' as LeavesProf)
  )
WHERE LeavesProf > 2*BeansProf;

-- B. DECLINING PROFITS
-- B1.
CREATE TABLE TempAB AS
SELECT * FROM (
  SELECT AreaID, StateName, Y2012, Y2013, Y2012-Y2013 as ProfDec
  FROM(
    SELECT * FROM(
      SELECT A.AreaID, S.StateName, EXTRACT(year from F.FactDate) as ProfYear, SUM(F.ActProfit) As AreaProf
      FROM AreaCode A, FactCoffee F, States S
      WHERE A.AreaID = F.AreaID and S.StateID = A.StateID
      GROUP BY A.AreaID, S.StateName, EXTRACT(year from F.FactDate)
    )
    PIVOT (
      Sum(AreaProf)
      FOR ProfYear IN (2012 as Y2012, 2013 as Y2013)
      ))
  WHERE 100*(Y2013-Y2012)/abs(Y2012) <> 0
  ORDER BY ProfDec DESC)
WHERE ROWNUM <= 5;

-- B2.
SELECT AreaID, StateName, ProdName, Y2012 - Y2013 as ProfDec
FROM (
  SELECT * FROM (
    SELECT T.AreaID, T.StateName, P.ProdName, EXTRACT(year from F.FactDate) as Year, SUM(F.ActProfit) as ProdProfit
    FROM TempAB T, ProdCoffee P, FactCoffee F, States S
    WHERE T.AreaID = F.AreaID AND P.ProductID = F.ProductID AND T.StateName = S.StateName
    GROUP BY T.AreaID, T.StateName, P.ProdName, EXTRACT(year from F.FactDate)
    )
  PIVOT (
    SUM(ProdProfit)
    FOR Year IN (2012 as Y2012, 2013 as Y2013)
    )
  )
WHERE Y2012 - Y2013 > 0
ORDER BY AreaID, ProfDec DESC;

-- C. BUDGETED Numbers
-- C1.
CREATE TABLE TempAC AS
SELECT * FROM (
  SELECT S.StateName, SUM(F.ActProfit) - SUM(F.BudProfit) as ProfDiff, SUM(F.ActSales) - SUM(F.BudSales) as SalesDiff
  FROM States S, FactCoffee F, AreaCode A
  WHERE S.StateID = A.StateID AND A.AreaID = F.AreaID
  GROUP BY S.StateName
  HAVING SUM(F.ActProfit) - SUM(BudProfit) > 0 AND SUM(F.ActSales) - SUM(F.BudSales) > 0
  ORDER BY ProfDiff DESC)
WHERE ROWNUM <= 5;

-- C2.
-- Define significant as actual profit exceeding budget by at least 20% and actual sales exceeding budget by at least 15%
SELECT T.StateName, A.AreaID, SUM(F.BudProfit) as BudProfit, SUM(F.ActProfit) - SUM(F.BudProfit) as ProfDiff,
      SUM(F.BudSales) as BudSales, SUM(F.ActSales) - SUM(F.BudSales) as SalesDiff,
      ROUND(100*(SUM(F.ActProfit) - SUM(F.BudProfit))/SUM(F.BudProfit), 2) as ProfDiffPerc,
      ROUND(100*(SUM(F.ActSales) - SUM(F.BudSales))/SUM(F.BudSales), 2) as SalesDiffPerc
FROM TempAC T, AreaCode A, FactCoffee F, States S
WHERE T.StateName = S.StateName AND S.StateID = A.StateID AND A.AreaID = F.AreaID
GROUP BY T.StateName, A.AreaID
HAVING 100*(SUM(F.ActProfit) - SUM(F.BudProfit))/SUM(F.BudProfit) > 20 
      AND 100*(SUM(F.ActSales) - SUM(F.BudSales))/SUM(F.BudSales) > 15
ORDER BY StateName;

-- D. PRODUCT Related
-- D1.
SELECT StateMkt, ProdName, ProfInc, MktRank
FROM (
  SELECT StateMkt, ProdName, Y2013 - Y2012 as ProfInc, RANK() OVER (PARTITION BY StateMkt 
                                                                    ORDER BY Y2013 - Y2012 DESC) as MktRank
  FROM (
    SELECT S.StateMkt, P.ProdName, EXTRACT(year from F.FactDate) as Year, SUM(F.ActProfit) AS Profit
    FROM States S, ProdCoffee P, FactCoffee F, AreaCode A
    WHERE S.StateID = A.StateID AND P.ProductID = F.ProductID AND A.AreaID = F.AreaID
    GROUP BY S.StateMkt, P.ProdName, EXTRACT(YEAR FROM F.FactDate)
    )
  PIVOT (
    SUM(Profit)
    FOR Year in (2012 as Y2012, 2013 as Y2013)
    )
    )
WHERE MktRank <= 3;

-- D2.
CREATE TABLE TempAD AS
SELECT StateMkt, ProdType, SalesInc, MktRank
FROM (
  SELECT StateMkt, ProdType, Y2013 - Y2012 AS SalesInc, RANK() OVER (PARTITION BY StateMkt
                                                                      ORDER BY Y2013 - Y2012 DESC) AS MktRank
  FROM (
    SELECT S.StateMkt, P.ProdType, EXTRACT(YEAR FROM F.FactDate) AS Year, SUM(F.ActSales) AS Sales
    FROM States S, ProdCoffee P, FactCoffee F, AreaCode A
    WHERE S.StateID = A.StateID AND P.ProductID = F.ProductID AND A.AreaID = F.AreaID
    GROUP BY S.StateMkt, P.ProdType, EXTRACT(YEAR FROM F.FactDate)
    )
    PIVOT (
    SUM(Sales)
    FOR Year IN (2012 AS Y2012, 2013 AS Y2013)
    )
    )
WHERE MktRank <=2;

-- D3.
SELECT StateMkt, ProdType, ProdName, ProdSales2013 - ProdSales2012 AS ProdSalesInc
FROM (
  SELECT T.StateMkt, T.ProdType, P.ProdName, EXTRACT(YEAR FROM F.FactDate) AS Year, SUM(F.ActSales) AS ProdSales
  FROM TempAD T, ProdCoffee P, FactCoffee F, AreaCode A, States S
  WHERE T.StateMkt = S.StateMkt AND T.ProdType = P.ProdType AND P.ProductID = F.ProductID AND 
        S.StateID = A.StateID AND A.AreaID = F.AreaID
  GROUP BY T.StateMkt, T.ProdType, P.ProdName, EXTRACT(YEAR FROM F.FactDate)
  )
PIVOT (
  SUM(ProdSales)
  FOR Year IN (2013 AS ProdSales2013, 2012 AS ProdSales2012)
  )
ORDER BY StateMkt, ProdType, ProdSalesInc DESC;
      
-- E. MARKETING EXPENSES (LOWEST):
-- E1.
SELECT * FROM (
  SELECT S.StateName, ROUND(100*(SUM(F.ActMarkCost)/SUM(F.ActSales)), 2) AS MktPercSales
  FROM States S, FactCoffee F, AreaCode A
  WHERE S.StateID = A.StateID AND F.AreaID = A.AreaID
  GROUP BY S.StateName
  ORDER BY MktPercSales)
WHERE ROWNUM <= 5;

-- E2. 
CREATE TABLE TempAE AS
SELECT * FROM (
  SELECT S.StateName, ROUND(100*(SUM(F.ActProfit)/SUM(F.ActSales)), 2) AS ProfPercSales
  FROM States S, FactCoffee F, AreaCode A
  WHERE S.StateID = A.StateID AND F.AreaID = A.AreaID
  GROUP BY S.StateName
  ORDER BY ProfPercSales DESC)
WHERE ROWNUM <= 5;

-- E3.
SELECT StateName, ProdName, MktExp FROM(
  SELECT T.StateName, P.ProdName, SUM(F.ActMarkCost) AS MktExp, RANK() OVER (PARTITION BY T.StateName
                                                                              ORDER BY SUM(F.ActMarkCost)) AS StateRank
  FROM TempAE T, ProdCoffee P, FactCoffee F, States S, AreaCode A
  WHERE T.StateName = S.StateName AND S.StateID = A.StateID AND A.AreaID = F.AreaID AND P.ProductID = F.ProductID
  GROUP BY T.StateName, P.ProdName
  ORDER BY StateName, MktExp)
WHERE StateRank <= 3;

-- F. MARKETING EXPENSES (HIGHEST):
-- F1.
-- Marketing expenses justified if state profit higher than average profit for all states
CREATE TABLE TempAF AS
SELECT * FROM (
  SELECT S.StateName, ROUND(100*(SUM(F.ActMarkCost)/SUM(F.ActSales)), 2) AS MktPercSales, 
        ROUND(100*(SUM(F.ActProfit)/SUM(F.ActSales)), 2) AS ProfPercSales
  FROM States S, FactCoffee F, AreaCode A
  WHERE S.StateID = A.StateID AND F.AreaID = A.AreaID
  GROUP BY S.StateName
  ORDER BY MktPercSales DESC)
WHERE ROWNUM <= 5;

SELECT AVG(ProfPercSales) AS AvgStateProfPercSales FROM (  
  SELECT S.StateName, ROUND(100*(SUM(F.ActProfit)/SUM(F.ActSales)), 2) AS ProfPercSales
  FROM States S, FactCoffee F, AreaCode A
  WHERE S.StateID = A.StateID AND A.AreaID = F.AreaID
  GROUP BY S.StateName);
  
-- F2. 
SELECT * FROM (
  SELECT T.StateName, A.AreaID, ROUND(100*(SUM(F.ActMarkCost))/SUM(F.ActSales), 2) AS MktPercSales, 
       ROUND(100*(SUM(F.ActProfit)/SUM(F.ActSales)),2) AS ProfPercSales
  FROM TempAF T, AreaCode A, FactCoffee F, States S
  WHERE T.StateName = S.StateName AND S.StateID = A.StateID AND A.AreaID = F.AreaID
  GROUP BY T.StateName, A.AreaID
  ORDER BY StateName, MktPercSales DESC
  )
WHERE ProfPercSales < 25;

-- G1.
-- Find AreaIDs with below avereage profits in 2012 and 2013
CREATE TABLE TempAG1 AS
SELECT A.AreaID, S.StateName
FROM AreaCode A, States S, FactCoffee F
WHERE A.StateID = S.StateID AND A.AreaID = F.AreaID AND EXTRACT(YEAR FROM F.FactDate) = 2013
GROUP BY A.AreaID, S.StateName
HAVING SUM(F.ActProfit) < 
  (SELECT AVG(SUM(ActProfit)) AS AvgProf
  FROM FactCoffee
  WHERE EXTRACT(YEAR FROM FactDate) = 2013
  GROUP BY AreaID)  
INTERSECT
SELECT A.AreaID, S.StateName
FROM AreaCode A, States S, FactCoffee F
WHERE A.StateID = S.StateID AND A.AreaID = F.AreaID AND EXTRACT(YEAR FROM F.FactDate) = 2012
GROUP BY A.AreaID, S.StateName
HAVING SUM(F.ActProfit) < 
  (SELECT AVG(SUM(ActProfit)) AS AvgProf
  FROM FactCoffee
  WHERE EXTRACT(YEAR FROM FactDate) = 2012
  GROUP BY AreaID);

-- Find AreaIDs with largest percent decrease in sales   
SELECT AreaID, StateName, Sales2012, Sales2013, Sales2013 - Sales2012 AS SalesDiff, 
        ROUND(100*(Sales2013 - Sales2012)/Sales2012,2) AS PercDiff 
FROM (
  SELECT T.AreaID, T.StateName, EXTRACT(YEAR FROM F.FactDate) AS Year, SUM(F.ActSales) AS Sales
  FROM TempAG1 T, FactCoffee F, AreaCode A
  WHERE T.AreaID = A.AreaID AND A.AreaID = F.AreaID 
  GROUP BY T.AreaID, T.StateName, EXTRACT(YEAR FROM F.FactDate))
PIVOT (
  SUM(Sales)
  FOR Year IN (2013 AS Sales2013, 2012 AS Sales2012))
ORDER BY PercDiff;

DROP TABLE TempAG1;

-- G2. 
-- Find AreaIDs with above avereage profits in 2012 and 2013
SELECT AreaID, StateName, Sales2012, Sales2013, ROUND(100*(Sales2013 - Sales2012)/Sales2012,2) AS PercDiff
FROM (
  SELECT A.AreaID, S.StateName, EXTRACT(YEAR FROM F.FactDate) AS Year, SUM(F.ActSales) AS TotSales
  FROM AreaCode A, States S, FactCoffee F
  WHERE A.StateID = S.StateID AND A.AreaID = F.AreaID
  GROUP BY A.AreaID, S.StateName, EXTRACT(YEAR FROM F.FactDate))
PIVOT (
  SUM(TotSales)
  FOR Year IN (2013 AS Sales2013, 2012 AS Sales2012))
WHERE Sales2012 IS NOT NULL AND Sales2013 IS NOT NULL
ORDER BY PercDiff DESC;