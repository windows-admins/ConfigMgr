SELECT
    DISTINCT
    rs.Netbios_Name0 AS 'Hostname'
    ,usr.Full_User_Name0 AS 'Name'
    ,usr.User_Name0 AS 'Username'
    ,usr.Mail0 AS 'Email'
    ,rs.AD_Site_Name0 AS 'Site'
    ,tse.ActionName AS 'Step'
    ,tse.GroupName AS 'Group'
    ,CONVERT(VARCHAR,DATEADD(hour, -5,tse.ExecutionTime),111) AS 'Date'
    ,CONVERT ([VARCHAR],DATEADD(HOUR,-5,tse.ExecutionTime),8) AS 'Time'
    ,CASE 
    WHEN tse.AdvertisementID = '## TS Advertisement ID ##' THEN 'Phase 1'
    WHEN tse.AdvertisementID = '## TS Advertisement ID ##' THEN 'Phase 2'
    END AS 'Phase'
    --,tse.ExecutionTime
FROM
    vSMS_TaskSequenceExecutionStatus AS tse
    JOIN v_R_System AS rs ON rs.ResourceID=tse.ResourceID
    JOIN v_R_User AS usr ON usr.User_Name0=rs.User_Name0
WHERE 
    tse.ExitCode != 0
    AND tse.PackageID = '## TS Package ID ##'
    AND DATALENGTH(tse.ActionName) > 0
    AND DATALENGTH(tse.GroupName) > 0
ORDER BY [Date] DESC, [Time] DESC, [Name]

--Failed step count
SELECT    
    tse.ActionName
    ,COUNT(tse.ActionName) AS 'Error Count'
FROM
    vSMS_TaskSequenceExecutionStatus AS tse
    JOIN v_R_System AS rs ON rs.ResourceID=tse.ResourceID
    JOIN v_R_User AS usr ON usr.User_Name0=rs.User_Name0
WHERE 
    tse.ExitCode != 0
    --or if you want ot use the advertisement ID tse.AdvertisementID = '## TS Advertisement ID'
    AND tse.PackageID = '## TS Package ID ##' 
    AND tse.GroupName != 'FaiIure Group'
    AND DATALENGTH(tse.ActionName) > 0
    AND DATALENGTH(tse.GroupName) > 0
GROUP BY tse.ActionName
