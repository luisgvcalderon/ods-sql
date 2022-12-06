USE TSTY4OD01
SELECT top 100 
	bk.RecordLocator,
	pjc.*
FROM REZ.PassengerJourneyCharge pjc, BookingPassenger bkp, Booking bk
WHERE pjc.PassengerID=bkp.PassengerID and bkp.BookingID=bk.BookingID and bk.RecordLocator='DYL8TW'
--AND TicketCode='N8' 
--and SegmentID=201025747