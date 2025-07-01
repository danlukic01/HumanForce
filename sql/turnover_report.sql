-- Example SQL to calculate monthly turnover rate for a given year
-- Uses dbo.Employee which contains StartDate and TerminationDate columns
-- Replace @ReportYear with the year you want to calculate

DECLARE @ReportYear INT = 2025;

WITH Months AS (
    SELECT 1 AS MonthNumber
    UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
    UNION ALL SELECT 11 UNION ALL SELECT 12
),
Terminations AS (
    SELECT MONTH(TerminationDate) AS TermMonth, COUNT(*) AS TerminatedEmployees
    FROM dbo.Employee
    WHERE TerminationDate >= DATEFROMPARTS(@ReportYear, 1, 1)
      AND TerminationDate <  DATEFROMPARTS(@ReportYear + 1, 1, 1)
    GROUP BY MONTH(TerminationDate)
),
HeadcountStart AS (
    SELECT m.MonthNumber, COUNT(*) AS StartOfMonth
    FROM Months m
    JOIN dbo.Employee e ON e.StartDate < DATEFROMPARTS(@ReportYear, m.MonthNumber, 1)
       AND (e.TerminationDate IS NULL OR e.TerminationDate >= DATEFROMPARTS(@ReportYear, m.MonthNumber, 1))
    GROUP BY m.MonthNumber
),
HeadcountEnd AS (
    SELECT m.MonthNumber, COUNT(*) AS EndOfMonth
    FROM Months m
    JOIN dbo.Employee e ON e.StartDate < DATEADD(month, 1, DATEFROMPARTS(@ReportYear, m.MonthNumber, 1))
       AND (e.TerminationDate IS NULL OR e.TerminationDate >= DATEADD(month, 1, DATEFROMPARTS(@ReportYear, m.MonthNumber, 1)))
    GROUP BY m.MonthNumber
)
SELECT
    DATENAME(month, DATEFROMPARTS(@ReportYear, m.MonthNumber, 1)) AS MonthName,
    COALESCE(t.TerminatedEmployees, 0) AS TerminatedEmployees,
    hs.StartOfMonth,
    he.EndOfMonth,
    ((hs.StartOfMonth + he.EndOfMonth) / 2.0) AS AverageHeadcount,
    (COALESCE(t.TerminatedEmployees, 0) * 100.0) / NULLIF(((hs.StartOfMonth + he.EndOfMonth) / 2.0), 0) AS TurnoverRatePercent
FROM Months m
LEFT JOIN Terminations t ON m.MonthNumber = t.TermMonth
JOIN HeadcountStart hs ON m.MonthNumber = hs.MonthNumber
JOIN HeadcountEnd he ON m.MonthNumber = he.MonthNumber
ORDER BY m.MonthNumber;
