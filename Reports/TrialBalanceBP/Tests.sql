-----Use SP---------------------------------------------------
EXEC [dbo].[TRIAL_BALANCE_BP] @periodid = 2
                              ,@datetype = 'P'
                              ,@dtfrom = '2020-01-01'
                              ,@dtto = '2020-02-28'
                              ,@itype = 3
                              ,@bp = 'E0001';
GO
---------------------------------------------------
