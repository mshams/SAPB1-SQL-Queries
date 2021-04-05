--** Create SP
CREATE PROCEDURE [dbo].[TRIAL_BALANCE_BP]
    @periodid NVARCHAR(5) = NULL
    ,@dtfrom DATE
    ,@dtto DATE
    ,@datetype CHAR
    ,@itype INT = 3 -- 1=Journals 2=Vouchers 3=Both
    ,@bp NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Get dates from Posting Period if param is not null
    IF(@periodid IS NOT NULL)
    BEGIN
        DECLARE @df1 DATE;
        DECLARE @dt1 DATE;
        DECLARE @df2 DATE;
        DECLARE @dt2 DATE;
        DECLARE @df3 DATE;
        DECLARE @dt3 DATE;

        SELECT @df1 = F_RefDate
               ,@dt1 = T_RefDate
               ,@df2 = F_DueDate
               ,@dt2 = T_DueDate
               ,@df3 = F_TaxDate
               ,@dt3 = T_TaxDate
          FROM OFPR
         WHERE AbsEntry = @periodid;

        IF(@datetype = 'P')
        BEGIN
            SET @dtfrom = @df1;
            SET @dtto = @dt1;
        END;
        ELSE IF(@datetype = 'D')
        BEGIN
            SET @dtfrom = @df2;
            SET @dtto = @dt2;
        END;
        ELSE IF(@datetype = 'T')
        BEGIN
            SET @dtfrom = @df3;
            SET @dtto = @dt3;
        END;
    END;


    WITH
    Q1  AS (SELECT T1.TransId
                   ,T0.BatchNum AS Number
                   ,Account
                   ,(SELECT ActId FROM OACT WHERE AcctCode = T0.Account) AS ActId
                   ,T0.ShortName
                   ,T0.ContraAct
                   ,T0.RefDate
                   ,Debit
                   ,Credit
                   ,T1.Memo
                   ,N'Voucher' AS Type
              FROM BTF1 T0
                   INNER JOIN OBTF T1 ON T1.BatchNum  = T0.BatchNum
                                     AND T1.TransId   = T0.TransId
                                     AND T1.BtfStatus = 'O'
             WHERE @itype IN ( 2, 3 )
               AND ( ((T1.U_removed IS NULL) OR (T1.U_removed = '0'))
                 AND ( (@datetype                             = 'P' AND T0.RefDate BETWEEN @dtfrom AND @dtto)
                    OR (@datetype                            = 'D' AND T0.DueDate BETWEEN @dtfrom AND @dtto)
                    OR (@datetype                            = 'T' AND T0.TaxDate BETWEEN @dtfrom AND @dtto)))
            UNION ALL
            SELECT T1.TransId
                   ,T1.Number AS Number
                   ,Account
                   ,(SELECT ActId FROM OACT WHERE AcctCode = T0.Account) AS ActId
                   ,T0.ShortName
                   ,T0.ContraAct
                   ,T0.RefDate
                   ,Debit
                   ,Credit
                   ,T1.Memo
                   ,N'Journal' AS Type
              FROM JDT1 T0
                   INNER JOIN OJDT T1 ON T1.TransId = T0.TransId
             WHERE @itype IN ( 1, 3 )
               AND ( ((T1.U_removed IS NULL) OR (T1.U_removed = '0'))
                 AND ( (@datetype                             = 'P' AND T0.RefDate BETWEEN @dtfrom AND @dtto)
                    OR (@datetype                            = 'D' AND T0.DueDate BETWEEN @dtfrom AND @dtto)
                    OR (@datetype                            = 'T' AND T0.TaxDate BETWEEN @dtfrom AND @dtto))))
    ,
    Q2  AS (SELECT TransId
                   ,FinncPriod
                   ,row = ROW_NUMBER() OVER (PARTITION BY FinncPriod ORDER BY FinncPriod, RefDate)
              FROM OJDT
             WHERE U_removed IS NULL
                OR U_removed = '0')
    SELECT ISNULL(Q2.row, '-') AS Number
           ,Q1.Type
           ,ISNULL(
                CONVERT(NVARCHAR, Q1.Number) + '/' + CONVERT(NVARCHAR, Q1.TransId)
                ,CONVERT(NVARCHAR, Q1.Number) + '/' + CONVERT(NVARCHAR, Q1.TransId)) AS Ref
           ,Q1.RefDate AS RefDate
           ,Q1.ActId
           ,(SELECT AcctName FROM OACT WHERE AcctCode = Q1.Account) AS AcctName
           ,Q1.ShortName + ' - ' + (SELECT CardName FROM OCRD WHERE CardCode = Q1.ShortName) AS BP
           ,Q1.Debit
           ,Q1.Credit
           ,Q1.Memo
           ,@dtfrom AS Date1
           ,@dtto AS Date2
           ,CASE @datetype
                WHEN 'P' THEN N'Posting Date'
                WHEN 'D' THEN N'Due Date'
                WHEN 'T' THEN N'Tax Date'
                ELSE 'Unknown' END AS DType
      FROM Q1
           LEFT OUTER JOIN Q2 ON Q2.TransId   = Q1.TransId
           INNER JOIN OCRD T0 ON Q1.ShortName = T0.CardCode
     WHERE (@bp IS NOT NULL AND Q1.ShortName = @bp)
        OR (@bp IS NULL)
    UNION ALL
    SELECT ISNULL(Q2.row, '-') AS Number
           ,Q1.Type
           ,CONVERT(NVARCHAR, Q1.Number) + '/' + CONVERT(NVARCHAR, Q1.TransId) AS Ref
           ,Q1.RefDate AS RefDate
           ,Q1.ActId
           ,(SELECT AcctName FROM OACT WHERE AcctCode = Q1.Account) AS AcctName
           ,Q1.ContraAct + ' - ' + (SELECT CardName FROM OCRD WHERE CardCode = Q1.ContraAct) AS BP
           ,Q1.Debit
           ,Q1.Credit
           ,Q1.Memo
           ,@dtfrom AS Date1
           ,@dtto AS Date2
           ,CASE @datetype
                WHEN 'P' THEN N'Posting Date'
                WHEN 'D' THEN N'Due Date'
                WHEN 'T' THEN N'Tax Date'
                ELSE 'Unknown' END AS DType
      FROM Q1
           LEFT OUTER JOIN Q2 ON Q2.TransId   = Q1.TransId
           INNER JOIN OCRD T0 ON Q1.ContraAct = T0.CardCode
     WHERE (@bp IS NOT NULL AND Q1.ContraAct = @bp)
        OR (@bp IS NULL)
     ORDER BY BP
              ,AcctName
              ,Number
              ,RefDate;
END;
GO