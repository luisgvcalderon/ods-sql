USE REZY4OD01
DECLARE @SaleStartDate datetime
SET @SaleStartDate ='2022-09-13'
DECLARE @SaleEndDate datetime
SET @SaleEndDate = '2022-09-13'

DECLARE @SaleDDate datetime
SET @SaleDDate = '2023-11-01'
DECLARE @SaleRDate datetime
SET @SaleRDate = '2024-03-31'
---¡¡¡¡¡¡IMPORTANTE!!!!!! CAMBIAR TIMESALES CUANDO HAYA UN CAMBIO DE HORARIO (INVIERNO (-6) / VERANO(-5))---


DECLARE @SaleStartDateUTC datetime
set @SaleStartDateUTC = dbo.convertdate('MX1',@SaleStartDate,1,0)
DECLARE @SaleEndDateUTC datetime
set @SaleEndDateUTC = dbo.convertdate('MX1',dateadd(dd,1,@SaleEndDate),1,0)
DECLARE @SaleDepartureDateUTC datetime
set @SaleDepartureDateUTC = dbo.convertdate('MX1',dateadd(dd,1,@SaleDDate),1,0)
DECLARE @SaleReturnDateUTC datetime
set @SaleReturnDateUTC = dbo.convertdate('MX1',dateadd(dd,1,@SaleRDate),1,0)

DECLARE @Conversion TABLE(
FromCurrencyCode varchar(3),
ToCurrencyCode varchar(3),
ValidFrom datetime, 
ValidTo datetime, 
ConversionRate decimal(14,7))
INSERT INTO @Conversion
exec REZY4WB01.Reports.GetExchangeRateTable 'MXN'

DECLARE @BF TABLE(
PNR varchar(8),
OD varchar(6),
DepartureDate datetime,
Pax decimal(2,2),
BFMXN decimal (8,3),
IVAMXN decimal (5,3))

SELECT TBF.RecordLocator, TBF.OD, TBF.DepartureDate, tbf.OwningCarrierCode,TBF.PAX, TBF.BaseFareMXN,TIVA.IVA
FROM 
(SELECT T2.RecordLocator, T2.OD, t2.OwningCarrierCode,t2.DepartureDate,SUM(t2.pax) PAX,SUM(T2.BaseFareMXN) BaseFareMXN
FROM(
SELECT  t1.RecordLocator,T1.FeeSalesDate AS BookingDate, T1.TimeSales,t1.FareClassOfService AS FareClass, T1.Year_Departure, T1.Month_Departure,t1.DepartureDate, OD=T1.DepartureStation+T1.ArrivalStation,SUM(t1.AmountLC) as BaseFareMXN, SUM(T1.PAX) as Pax, t1.OwningCarrierCode
FROM (
	SELECT CASE WHEN T1.ConnectPoint='' THEN 1
			WHEN (T1.DepartureStation='TJX' or T1.ArrivalStation='TJX') THEN 1 -- Omitir los clientes en segmento TJX
			ELSE 2 --Contabilizar los clientes con conexión
			END AS PAX, 
			T1.FeeSalesDate, T1.TimeSales,  T1.RecordLocator, T1.Year_Departure, T1.Month_Departure, T1.DepartureStation, T1.ConnectPoint, T1.ArrivalStation, T1.AmountLC, t1.FareClassOfService, t1.DepartureDate, t1.OwningCarrierCode
	FROM(
		SELECT DISTINCT  t1.PassengerID, T1.FeeSalesDate, T1.TimeSales, T1.RecordLocator,t1.OwningCarrierCode, YEAR(PJS.DepartureDate) AS Year_Departure,MONTH(PJS.DepartureDate) AS Month_Departure, pjs.DepartureDate,cn.DepartureStation, cn.ConnectPoint,cn.ArrivalStation, PJS.SegmentNumber--, PJS.JourneyNumber, 
							,t1.AmountLC, T1.SegmentID, pjs.FareClassOfService
		FROM(
			SELECT  T1.RecordLocator ,T1.FeeSalesDate,T1.TimeSales, t1.OwningCarrierCode,
							CASE WHEN T1.CurrencyCode = 'MXN' THEN T1.Amount
								ELSE conv.ConversionRate * T1.Amount
							END AS AmountLC,T1.PassengerID, t1.SegmentID
			FROM(
				SELECT SUM(T1.ChargeRight) AS Amount,T1.CurrencyCode, T1.TimeSales, T1.FeeSalesDate, t1.RecordLocator, t1.PassengerID, t1.SegmentID, t1.OwningCarrierCode
				FROM(
							SELECT DISTINCT bk.BookingID, pjc.ChargeCode, bk.BookingDate, bk.RecordLocator, bp.PassengerID, pjc.SegmentID,pjc.ChargeType, bk.OwningCarrierCode,
								CASE WHEN pjc.ChargeType in (1,7) THEN pjc.ChargeAmount*(-1)
									WHEN pjc.ChargeType = 0 THEN pjc.ChargeAmount
									END AS ChargeRight, pjc.CurrencyCode, pjc.ChargeAmount,dbo.ConvertDate('MX1', bk.BookingDate,0,1) as FeeSalesDate,
									DATEPART(HOUR,DATEADD(HOUR,-5, bk.BookingDate)) AS TimeSales ---AJUSTAR POR HORARIO
							FROM Booking bk 
							join BookingPassenger BP on (bk.BookingID =BP.BookingID)
							left outer join PassengerJourneyCharge pjc on (pjc.PassengerID = bp.PassengerID)
							--left outer join Agent ag on (bk.CreatedAgentCode=ag.AgentName)
							--left outer join AgentRole ar on (ag.AgentID=ar.AgentID)
							WHERE pjc.ChargeType in (0,1,7)
							AND bk.RecordLocator in (SELECT Distinct(bk.RecordLocator) RecordLocator 
							FROM Booking bk
							left outer join BookingPassenger bp on (bk.BookingID=bp.BookingID)
							left outer join PassengerJourneySegment pjs on (bp.PassengerID=pjs.PassengerID)
							WHERE bk.BookingDate between @SaleStartDateUTC and @SaleEndDateUTC
							AND pjs.DepartureDate between @SaleDepartureDateUTC and @SaleReturnDateUTC
							AND pjs.FareClassOfService in ('A')
							AND bk.Status not in (1,4)
							AND bp.PaxType in ('CVC','CPF','AVC','APF')) 
				) T1
				GROUP BY  T1.CurrencyCode, T1.TimeSales, T1.FeeSalesDate, t1.RecordLocator, t1.PassengerID, t1.SegmentID, t1.OwningCarrierCode
			)T1
			LEFT JOIN @Conversion conv ON T1.CurrencyCode = conv.FromCurrencyCode AND T1.FeeSalesDate BETWEEN conv.ValidFrom AND conv.ValidTo
		) T1
		left outer join PassengerJourneySegment pjs on (pjs.PassengerID = t1.PassengerID) and (t1.SegmentID=pjs.SegmentID)
		CROSS APPLY [REZY4WB01].[dbo].[FCNGetConnectionsByPax] (pjs.PassengerID,pjs.JourneyNumber) cn
		WHERE pjs.DepartureDate BETWEEN @SaleDepartureDateUTC AND @SaleReturnDateUTC --Filtro de fecha de vuelo
		
	)T1
)t1
GROUP BY  T1.FeeSalesDate, t1.OwningCarrierCode,T1.TimeSales,t1.FareClassOfService, t1.DepartureDate,t1.RecordLocator,T1.Year_Departure, T1.Month_Departure,T1.DepartureStation+T1.ArrivalStation)T2
GROUP BY T2.RecordLocator, t2.OD,t2.OwningCarrierCode, t2.DepartureDate) TBF
left outer join (SELECT T1.RecordLocator PNR, T1.DepartureDate, T1.OD, t1.RuleCarrierCode, Case WHEN t1.CurrencyCode='MXN' THEN T1.IVA Else T1.IVA*conv.ConversionRate END AS IVA
FROM
(SELECT bk.RecordLocator,bk.BookingDate, pjs.DepartureDate, pjs.DepartureStation+pjs.ArrivalStation OD, pjs.RuleCarrierCode,SUM(pjc.ChargeAmount) IVA, pjc.CurrencyCode
FROM booking bk
left outer join BookingPassenger bp on (bk.BookingID=bp.BookingID)
left outer join PassengerJourneyCharge pjc on (bp.PassengerID=pjc.PassengerID)
left outer join PassengerJourneySegment pjs on (pjc.PassengerID=pjs.PassengerID and pjc.SegmentID=pjs.SegmentID)
WHERE 
bk.RecordLocator in (SELECT Distinct(bk.RecordLocator) RecordLocator 
							FROM Booking bk
							left outer join BookingPassenger bp on (bk.BookingID=bp.BookingID)
							left outer join PassengerJourneySegment pjs on (bp.PassengerID=pjs.PassengerID)
							WHERE bk.BookingDate between @SaleStartDateUTC and @SaleEndDateUTC
							AND pjs.DepartureDate between @SaleDepartureDateUTC and @SaleReturnDateUTC
							AND bk.Status not in (1,4)
							AND pjs.FareClassOfService in ('A')
							AND bp.PaxType in ('CVC','CPF','AVC','APF'))
AND pjc.ChargeType=5 and pjc.TicketCode in ('MX', 'XO')
GROUP by bk.RecordLocator, bk.BookingDate, pjs.DepartureDate, pjs.DepartureStation+pjs.ArrivalStation,pjs.RuleCarrierCode, pjc.CurrencyCode) T1
LEFT JOIN @Conversion conv ON T1.CurrencyCode = conv.FromCurrencyCode AND T1.BookingDate BETWEEN conv.ValidFrom AND conv.ValidTo) TIVA
on (TBF.RecordLocator=TIVA.PNR AND TBF.OD=TIVA.OD AND TBF.DepartureDate=TIVA.DepartureDate)
ORDER BY 1 ASC


