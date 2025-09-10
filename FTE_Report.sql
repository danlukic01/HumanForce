/*
  HumanForce FTE Report Extract
  Generates weekly Full-Time Equivalent (FTE) metrics per employee.
  - Standard full-time hours are configurable (default 38).
  - Caps FTE at 1.0 to handle overtime.
  - Casual employees use a rolling 4-week average of rostered hours.
  - Unpaid leave (ShiftType.IsUnPaid = 1) is excluded from hours worked.
  - Start and end dates are returned for proration in Power BI.
*/

-- Parameters ---------------------------------------------------------------
DECLARE @StartDate date = '2024-01-01';   -- Reporting period start (inclusive)
DECLARE @EndDate   date = '2024-12-31';   -- Reporting period end (exclusive)
DECLARE @StdHours  decimal(4,2) = 38.0;   -- Standard full-time hours per week

;WITH WeekHours AS (
    SELECT
        EmployeeGuidKey,
        EmployeeCode,
        EmployeeName,
        DepartmentName,
        LocationName,
        EmploymentTypeName,
        StartDate       AS EmployeeStartDate,
        TerminationDate AS EmployeeEndDate,
        DATEADD(DAY, - (DATEPART(WEEKDAY, DateStart) + @@DATEFIRST - 2) % 7, CAST(DateStart AS date)) AS WeekStartDate,
        SUM(CASE WHEN ShiftType.IsUnPaid = 0 THEN TimesheetNetMinutes ELSE 0 END) AS WorkMinutes,
        SUM(CASE WHEN ShiftType.IsUnPaid = 0 THEN RosterNetMinutes ELSE 0 END)     AS RosterMinutes
    FROM dbo.TimesheetData
    WHERE DateStart >= @StartDate
      AND DateStart <  @EndDate
      AND Authorised = 1
    GROUP BY EmployeeGuidKey, EmployeeCode, EmployeeName, DepartmentName,
             LocationName, EmploymentTypeName, StartDate, TerminationDate,
             DATEADD(DAY, - (DATEPART(WEEKDAY, DateStart) + @@DATEFIRST - 2) % 7, CAST(DateStart AS date))
),
Calc AS (
    SELECT
        *,
        CASE WHEN WorkMinutes   < 0 THEN 0 ELSE WorkMinutes   END / 60.0 AS HoursWorked,
        CASE WHEN RosterMinutes < 0 THEN 0 ELSE RosterMinutes END / 60.0 AS RosterHours
    FROM WeekHours
),
CasualAvg AS (
    SELECT
        *,
        AVG(RosterHours) OVER (
            PARTITION BY EmployeeGuidKey
            ORDER BY WeekStartDate
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS AvgRosterHours4Weeks
    FROM Calc
)

SELECT
    EmployeeGuidKey,
    EmployeeCode,
    EmployeeName,
    DepartmentName,
    LocationName,
    EmploymentTypeName,
    EmployeeStartDate,
    EmployeeEndDate,
    WeekStartDate,
    ROUND(HoursWorked,2)     AS HoursWorked,
    ROUND(RosterHours,2)     AS RosterHours,
    ROUND(
        CASE WHEN EmploymentTypeName = 'Casual'
             THEN CASE WHEN AvgRosterHours4Weeks / @StdHours > 1 THEN 1
                       ELSE AvgRosterHours4Weeks / @StdHours END
             ELSE CASE WHEN HoursWorked / @StdHours > 1 THEN 1
                       ELSE HoursWorked / @StdHours END
        END, 2) AS FTE
FROM CasualAvg
ORDER BY EmployeeName, WeekStartDate;
