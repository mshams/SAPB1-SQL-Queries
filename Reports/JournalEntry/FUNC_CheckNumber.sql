--Check for Function
IF OBJECT_ID('[dbo].[GET_CHECK]', 'FN') IS NOT NULL
    DROP FUNCTION [dbo].[GET_CHECK];
GO

CREATE FUNCTION GET_CHECK(@transid INT)
RETURNS NVARCHAR(150)
AS
BEGIN
    DECLARE @ResultVar NVARCHAR(150);
    SELECT @ResultVar
        = N'NUM: ' + CONVERT(NVARCHAR(100), T1.CheckNum) + N'BANK: ' + CONVERT(NVARCHAR(100), T5.BankName) + N' ('
          + CONVERT(NVARCHAR(100), T1.AcctNum) + N')'
      FROM OJDT T3
           INNER JOIN OVPM T4 ON T4.TransId  = T3.TransId
           INNER JOIN OCHO T1 ON T4.DocEntry = T1.PmntNum --and T1.Canceled = 'N'
           INNER JOIN ODSC T5 ON T5.BankCode = T1.BankNum
     WHERE T3.TransId = @transid;

    RETURN @ResultVar;

END;
GO
