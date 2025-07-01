-- Example SQL to summarize unplanned leave by employee and leave type
-- Uses TimesheetData view where ShiftType records indicate leave
-- Update @StartDate and @EndDate for desired reporting period

DECLARE @StartDate DATE = '2025-01-01';
DECLARE @EndDate   DATE = '2025-12-31';

-- leave type names classified as Unplanned in HumanForce
DECLARE @UnplannedLeave TABLE (Name NVARCHAR(50));
INSERT INTO @UnplannedLeave (Name)
VALUES
    ('Compassionate Leave'),
    ('Jury Duty'),
    ('Personal Leave'),
    ('Union Representative Training Leave'),
    ('Unpaid Carers Leave'),
    ('Unpaid Ceremonial Leave'),
    ('Unpaid Community Service Leave'),
    ('Unpaid Compassionate Leave'),
    ('Unpaid Leave'),
    ('Unpaid Parental Leave'),
    ('Unpaid Personal Leave');

SELECT
    e.EmployeeCode,
    e.Name AS EmployeeName,
    st.Name AS LeaveType,
    SUM(td.TimesheetNetMinutes) / 60.0 AS LeaveHours
FROM dbo.TimesheetData td
    JOIN dbo.Employee e  ON td.EmployeeGuidKey = e.GuidKey
    JOIN dbo.ShiftType st ON td.ShiftTypeGuidKey = st.GuidKey
    JOIN @UnplannedLeave ul ON st.Name = ul.Name
WHERE td.DateStart >= @StartDate
  AND td.DateStart < DATEADD(day, 1, @EndDate)
GROUP BY e.EmployeeCode, e.Name, st.Name
ORDER BY e.EmployeeCode, st.Name;
