INSERT INTO MYTABLE (A, B, C)
SELECT DISTINCT FL.loanid,
                Stuff((SELECT DISTINCT ', ' + Rtrim(Isnull(( CASE @CountryID
                                       WHEN 2 THEN
                                             pd3.productname WHEN 3 THEN
                                       pd4.productname ELSE pd2.productname END
                                       ), ''))
                       FROM   usr_crm.dbo.family_loan_structure s2
                              LEFT OUTER JOIN usr_crm.dbo.api_nz_products pd2
                                           ON s2.productid = pd2.productid
                                              AND @CountryID = 1
                              LEFT OUTER JOIN usr_crm.dbo.api_au_products pd3
                                           ON s2.productid = pd3.productid
                                              AND @CountryID = 2
                              LEFT OUTER JOIN usr_crm.dbo.api_id_products pd4
                                           ON s2.productid = pd4.productid
                                              AND @CountryID = 3
                       WHERE  s2.loanid = Fl.loanid
                          AND s2.isactive = 1
                       FOR xml path('')), 1, 2, ''),
                (SELECT Min(s3.fixedrateexpiry)
                 FROM   usr_crm.dbo.family_loan_structure s3
                        LEFT OUTER JOIN (SELECT productid,
                                                ratetype,
                                                rate InterestRate
                                         FROM   usr_crm.dbo.api_nz_products
                                         WHERE  @CountryID = 1
                                         --Cant get RateTerm for NZ products
                                         UNION ALL
                                         SELECT productid,
                                                interestratetypeinitial RateType
                                                ,initialrate             InterestRate
                                        FROM   usr_crm.dbo.api_au_products
                                        WHERE  @CountryID = 2)) pd
                        ON pd.ProductID = s3.ProductID
 FROM @Temp T
            INNER JOIN USR_CRM.dbo.Family_Loan FL
                ON FL.LoanID = T.LoanID