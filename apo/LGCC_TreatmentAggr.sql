USE [ANAY4DW01]
--- Agregation on one statement
--DECLARE @AggTable as table (
--	MinLoggedUTC  date
--	,MinTreatmentID bigint
--	,MaxTreatmentID bigint
--)
--INSERT INTO @AggTable
SELECT
	CAST(MinLoggedUTC as date) as MinLoggedUTC
	,MIN([MinTreatmentID]) AS MinTreatmentID
	,MAX([MinTreatmentID]) AS MaxTreatmentID
	FROM [AnalyticsDW].[TreatmentDistinctRanked]
  WHERE MinLoggedUTC BETWEEN '2022-08-31' AND '2022-09-01'
  group by CAST(MinLoggedUTC as date)
  ORDER BY MinLoggedUTC

--SELECT *
--FROM @AggTable
--ORDER BY MinLoggedUTC asc

--- Comparison of Extraction of Treatments
--SELECT TOP (1) 
--	([MinTreatmentID])
--  FROM [TSTANAY4DW01].[AnalyticsDW].[TreatmentDistinctRanked]
--  WHERE MinLoggedUTC >= '2020-07-17'
--  ORDER BY MinTreatmentID

--SELECT 
--	max([MinTreatmentID]) as MaxTreatmentID
--  FROM [TSTANAY4DW01].[AnalyticsDW].[TreatmentDistinctRanked]
--  WHERE MinLoggedUTC < '2020-07-18'