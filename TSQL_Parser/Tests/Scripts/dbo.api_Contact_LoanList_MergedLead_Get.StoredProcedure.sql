USE [SYS_CRM]
GO

/****** Object:  StoredProcedure [dbo].[api_Contact_LoanList_MergedLead_Get]    Script Date: 6/18/2021 1:03:40 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/****************************************************************************** 
** Change History
**
** CID		Date		Author			Description 
** -----	----------	----------		-----------------------------------------------
** CH001	27/09/2019	B.Borja			CRM-8682: a copy of api_Contact_LoanList_Get (dated CH037) but will include Lead Loan Objects
										this list will always include IsOpportunity = 1
** CH002	07/11/2019	M. Bengil		CRM-9506 -- Handle Inprogress Milli Loan in Contact Lending and Timeline and other card/loan unsync status scenarios
** CH003	29/11/2019	M. Bengil		filter isactive for pipeline cards (CRM-9085)
** CH004	06/01/2020	M. Bengil		should use loan status even if linked to pipeline if loan is already settled (CRM-10038)
** CH005	24/01/2020  M. Bengil		should use loan status even if linked to pipeline if loan is npw (CRM-10147)
** CH005	24/01/2020  M. Bengil		CRM-13114 : should use loan status even if linked to pipeline if loan is cancelled, repaid (CRM-10147)
** CH007	06/10/2020  J. Baron		CRM-12956: Added filter isActive for loan objectives
** CH006	08/10/2020	J. Baron		[CRM-12345] Added Repaid Date
** CH007	10/11/2020  J.Binas			CRM-13109: Added Varied Date
** CH008	17/12/2020  I.Quino			CRM-14080: Added OrgPipelineStatusId
** CH009    24/06/2021  J.Patterson     Add ProductLenderID
** CH010    15/07/2021  T.Callaghan     Remove references to APIS_CRMInsurance_CTRL_Rates_Frequency
*******************************************************************************/
CREATE OR ALTER PROCEDURE [dbo].[api_Contact_LoanList_MergedLead_Get]
    @UserID INT,
    @FamilyID INT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @CountryID INT = (
            SELECT CountryID
            FROM USR_CRM.dbo.Family_Login
            WHERE FamilyID = @UserID
            )
    DECLARE @Temp TABLE (
        LoanID INT,
        FamilyID INT,
        ClientID INT,
        EntityID INT
        )
    DECLARE @IsClient INT = (
            SELECT ISNULL(FamilyTypeID, ISNULL((
                            SELECT TOP 1 2
                            FROM USR_CRM.dbo.Family_AssociatedEntity
                            WHERE FamilyID = @FamilyID
                            ), 1))
            FROM USR_CRM.dbo.Family
            WHERE FamilyID = @FamilyID
            )
    DECLARE @Result TABLE (
        LoanId INT,
        LenderID INT,
        ProviderName VARCHAR(1000),
        ProductName VARCHAR(1000),
        LoanReference VARCHAR(1000),
        SettledDate DATE,
        ApprovalDate DATE,
        NextFixedExpiry DATE,
        LoanAmount DECIMAL(18, 2),
        ClientName VARCHAR(1000),
        StatusName VARCHAR(1000),
        StatusCategoryname VARCHAR(1000),
        isPipelineLinked BIT,
        ExpiryDate DATE,
        FamilyFullName VARCHAR(1000),
        AdviserName VARCHAR(1000),
        CreatedDate DATE,
        LoanPurpose VARCHAR(1000),
        LoanScenarioID INT,
        SubmittedDate DATE,
        Applicants VARCHAR(2000),
        FixedExpiryDescription VARCHAR(max),
        FinanceDate DATE,
        PipelineCardsID INT,
        PipelineStatusID INT,
        PipelineStatus VARCHAR(100),
        PreApprovalExpiryDate DATE,
        LoanStatusId INT,
        SubmittedLoanID INT,
        NextGenID INT,
        DisplayID VARCHAR(200),
        HasBeenSentToNextGen BIT,
        LMI DECIMAL(18, 2),
        IsEstimated BIT,
        LoanStatusDisplayName VARCHAR(100),
        LoanStatusDisplayID INT,
        IsNotShowLoanApp BIT,
        LoanScenarioTitle VARCHAR(2000),
        LoanOpportunityAmount FLOAT,
        IsReadOnly BIT,
        IsOpportunity BIT,
        NotProceedingDate DATE,
        PreApprovedDate DATE,
        ConditionallyApprovedDate DATE,
        EstimatedSettlementDate DATE,
        LendingCategoryId INT,
        IsImportedLoan BIT,
        IsLoanFromOtherAggregator BIT,
        LendingCategoryName VARCHAR(200),
        Lenders_Category VARCHAR(100),
        Lenders_CategoryId INT,
        AssetType VARCHAR(200),
        IsNPSSurvey BIT,
        Probability VARCHAR(255),
        SubStatusId INT,
        SubStatusName VARCHAR(255),
        RepaidDate DATE,
        VariedDate DATE,
        OrgPipelineStatusId INT,
        ProductLenderId INT
        )
    DECLARE @CountryCode VARCHAR(3) = CASE @CountryID
            WHEN 1
                THEN 'NZ'
            WHEN 2
                THEN 'AU'
            WHEN 3
                THEN 'ID'
            END

    DROP TABLE

    IF EXISTS #PREVIOUSLOANSTATUSES
        CREATE TABLE #PREVIOUSLOANSTATUSES (LoanStatusId INT)

    INSERT INTO #PREVIOUSLOANSTATUSES (LoanStatusId)
    SELECT LoanStatusID
    FROM USR_CRM.dbo.CTRL_LoanStatus
    WHERE Category = 'Previous'

    IF SYS_CRM.[dbo].[apif_Validate_FamilyAccess](@UserID, @FamilyID) = 1
    BEGIN
        IF @IsClient = 1
        BEGIN
            INSERT @Temp (
                LoanID,
                FamilyID,
                ClientID
                )
            SELECT FL.LoanID,
                F.FamilyID,
                FC.ClientID
            FROM USR_CRM.dbo.Family F
            INNER JOIN USR_CRM.dbo.Family_Client FC
                ON FC.FamilyID = F.FamilyID
            INNER JOIN USR_CRM.dbo.Family_Loan_Client FLC
                ON FC.ClientID = FLC.ClientID
            INNER JOIN USR_CRM.dbo.Family_Loan FL
                ON FL.LoanID = FLC.LoanID
            WHERE F.FamilyID = @FamilyID
                AND FC.IsActive = 1
                AND F.IsActive = 1
                AND FL.IsActive = 1
                AND (
                    FLC.IsApplicant = 1
                    OR FLC.IsGuarantor = 1
                    )

            INSERT INTO @Result (
                LoanId,
                LenderID,
                ProviderName,
                StatusName,
                LoanReference,
                ProductName,
                NextFixedExpiry,
                LoanAmount,
                StatusCategoryname,
                isPipelineLinked,
                ExpiryDate,
                FamilyFullName,
                AdviserName,
                CreatedDate,
                LoanPurpose,
                LoanScenarioID,
                SubmittedDate,
                Applicants,
                ClientName,
                FixedExpiryDescription,
                PreApprovalExpiryDate,
                SettledDate,
                ApprovalDate,
                FinanceDate,
                LoanStatusId,
                SubmittedLoanID,
                HasBeenSentToNextGen,
                LMI,
                IsEstimated,
                LoanStatusDisplayName,
                LoanStatusDisplayID,
                IsNotShowLoanApp,
                LoanScenarioTitle,
                LoanOpportunityAmount,
                IsReadOnly,
                IsOpportunity,
                NotProceedingDate,
                PreApprovedDate,
                ConditionallyApprovedDate,
                EstimatedSettlementDate,
                LendingCategoryId,
                IsImportedLoan,
                IsLoanFromOtherAggregator,
                LendingCategoryName,
                Lenders_Category,
                Lenders_CategoryId,
                AssetType,
                IsNPSSurvey,
                Probability,
                SubStatusId,
                SubStatusName,
                RepaidDate,
                VariedDate,
                OrgPipelineStatusId,
                ProductLenderId
                )
            SELECT DISTINCT FL.LoanID,
                ISNULL(CAST(PLM.InternalReference AS INT), 0),
                LTRIM(RTRIM(ISNULL(PL.FullName, ''))),
                CASE 
                    WHEN ISNULL(FL.LoanStatusID, 0) = 0
                        THEN CLS2.LoanStatusName
                    ELSE LTRIM(RTRIM(CLS.LoanStatusName))
                    END,
                ISNULL(FL.LoanReferenceNumber, ''),
                STUFF((
                        SELECT DISTINCT ', ' + RTRIM(ISNULL((
                                        CASE @CountryID
                                            WHEN 2
                                                THEN pd3.ProductName
                                            WHEN 3
                                                THEN pd4.ProductName
                                            ELSE pd2.ProductName
                                            END
                                        ), ''))
                        FROM USR_CRM.dbo.Family_Loan_Structure s2
                        LEFT OUTER JOIN USR_CRM.dbo.API_NZ_Products pd2
                            ON s2.ProductID = pd2.ProductID
                                AND @CountryID = 1
                        LEFT OUTER JOIN USR_CRM.dbo.API_AU_Products pd3
                            ON s2.ProductID = pd3.ProductID
                                AND @CountryID = 2
                        LEFT OUTER JOIN USR_CRM.dbo.API_ID_Products pd4
                            ON s2.ProductID = pd4.ProductID
                                AND @CountryID = 3
                        WHERE s2.LoanID = Fl.LoanID
                            AND s2.IsActive = 1
                        FOR XML PATH('')
                        ), 1, 2, ''),
                (
                    SELECT MIN(s3.fixedrateexpiry)
                    FROM USR_CRM.dbo.Family_Loan_Structure s3
                    LEFT OUTER JOIN (
                        SELECT ProductID,
                            RateType,
                            Rate InterestRate
                        FROM USR_CRM.dbo.API_NZ_Products
                        WHERE @CountryID = 1
                        --Cant get RateTerm for NZ products
                        
                        UNION ALL
                        
                        SELECT ProductID,
                            InterestRateTypeInitial RateType,
                            InitialRate InterestRate
                        FROM USR_CRM.dbo.API_AU_Products
                        WHERE @CountryID = 2
                        
                        UNION ALL
                        
                        SELECT ProductID,
                            InterestRateTypeInitial RateType,
                            InitialRate InterestRate
                        FROM USR_CRM.dbo.API_ID_Products
                        WHERE @CountryID = 3
                        ) pd
                        ON pd.ProductID = s3.ProductID
                    WHERE s3.loanid = Fl.loanid
                        AND s3.isactive = 1
                        AND (
                            CASE 
                                WHEN NULLIF(s3.RateType, '') IS NULL
                                    THEN (
                                            CASE 
                                                WHEN CHARINDEX('Fixed', pd.RateType) > 0
                                                    THEN 'Fixed'
                                                WHEN s3.FixedRateExpiry IS NOT NULL
                                                    THEN 'Fixed'
                                                ELSE 'Floating'
                                                END
                                            )
                                ELSE s3.RateType
                                END
                            ) = 'Fixed'
                    ),
                (
                    SELECT SUM(s4.Amount)
                    FROM USR_CRM.dbo.Family_Loan_Structure s4
                    WHERE s4.LoanID = Fl.LoanID
                        AND s4.IsActive = 1
                    ),
                CASE 
                    WHEN c.PipelineCardsID IS NULL
                        OR FL.LoanStatusID IN (1, 19, 11, 12, 18)
                        OR FL.LoanStatusID IN (
                            SELECT LoanStatusId
                            FROM #PREVIOUSLOANSTATUSES
                            )
                        THEN --settled and NPW statuses
                            ISNULL(CLS.V2Category, CLS2.V2Category)
                    ELSE (
                            SELECT V2Category
                            FROM USR_CRM.dbo.CTRL_LoanStatus
                            WHERE LoanStatusID = s.LinkToLoanStatusId
                            )
                    END AS StatusCategoryName,
                (
                    CASE 
                        WHEN CLS.V2Category = 'InProgress'
                            AND APICE.PipelineItemID IS NOT NULL
                            THEN 1
                        WHEN (
                                ISNULL(FL.LeadLoanStatusId, 0) > 0
                                AND ISNULL(FL.LoanStatusID, 0) = 0
                                )
                            AND APICE.PipelineItemID IS NOT NULL
                            THEN 1
                        ELSE 0
                        END
                    ),
                (
                    CASE 
                        WHEN CLS.LoanStatusID = 3
                            THEN ISNULL(LDAppExps.DATE, DATEADD(MONTH, 3, LDPreApproval.DATE))
                        WHEN CLS.LoanStatusID = 10
                            THEN ISNULL(LDAppExps.DATE, DATEADD(MONTH, 3, LDApproval.DATE))
                        END
                    ),
                SYS_CRM.dbo.apif_Get_Family_FullName(t.FamilyID),
                SYS_CRM.dbo.apif_Get_User_FullName(FL.OwnedByAdviserID),
                FL.DateCreated,
                STUFF((
                        SELECT ', ' + p.Purpose
                        FROM USR_CRM.dbo.API_LoanScenario ls
                        INNER JOIN USR_CRM.dbo.API_LoanApplication_Objectives o
                            ON ls.LoanScenarioID = o.LoanApplicationID
                                AND o.QuestionID = 5 --5=PrimaryPurpose question
                        INNER JOIN USR_CRM.dbo.API_CTRL_LoanApplication_PrimaryPurpose p
                            ON o.AnswerInt = p.PurposeID
                        WHERE ls.LoanID = FL.LoanID
                            AND o.IsActive = 1
                        FOR XML PATH('')
                        ), 1, 1, ''),
                LS.LoanScenarioID,
                LDSubmitted.DATE,
                STUFF((
                        SELECT ', ' + ISNULL(fae.EntityName, (afc.FirstName + ' ' + afc.LastName))
                        FROM USR_CRM.dbo.Family_Loan_Client alc
                        LEFT JOIN USR_CRM.dbo.Family_Client afc
                            ON afc.ClientID = alc.ClientID
                                AND (
                                    alc.IsApplicant = 1
                                    OR alc.IsGuarantor = 1
                                    )
                                AND ISNULL(afc.Deceased, 0) <> 1
                                AND afc.RoleID = 1
                        LEFT JOIN USR_CRM.dbo.Family_AssociatedEntity fae
                            ON fae.EntityID = alc.EntityID
                                AND alc.IsApplicant = 1
                        WHERE alc.LoanID = FL.LoanID
                        FOR XML PATH('')
                        ), 1, 1, ''),
                ISNULL(STUFF((
                            SELECT DISTINCT ', ' + ISNULL(EntityName, ISNULL((
                                            CASE RTRIM(c.PreferredName)
                                                WHEN ''
                                                    THEN NULL
                                                ELSE c.preferredname
                                                END
                                            ), c.FirstName))
                            FROM USR_CRM.dbo.Family_Loan_Client lc
                            LEFT OUTER JOIN USR_CRM.dbo.Family_Client c
                                ON lc.ClientID = c.clientid
                                    AND c.IsActive = 1
                            LEFT OUTER JOIN USR_CRM.dbo.Family_AssociatedEntity ae
                                ON lc.EntityID = ae.EntityID
                                    AND ae.IsActive = 1
                                    AND ae.EntityTypeID IN (
                                        SELECT EntityTypeID
                                        FROM USR_CRM.dbo.CTRL_AssociatedEntityType
                                        WHERE BorrowerEntity = 1
                                        )
                            WHERE lc.LoanID = fl.LoanID
                            ORDER BY ', ' + ISNULL(EntityName, ISNULL((
                                            CASE RTRIM(c.PreferredName)
                                                WHEN ''
                                                    THEN NULL
                                                ELSE c.PreferredName
                                                END
                                            ), c.FirstName))
                            FOR XML PATH('')
                            ), 1, 2, ''), '') AS ClientNames,
                ISNULL((
                        SELECT ' - ' + t.NAME + ' - ' + ISNULL(CONVERT(VARCHAR(50), ROUND(ls.InterestRate * 100, 2)), '-') + '% ' + ISNULL((
                                    CASE ls.RateType
                                        WHEN ''
                                            THEN NULL
                                        ELSE (
                                                CASE 
                                                    WHEN ls.RateType_NumberMonths = 0
                                                        THEN 'Floating'
                                                    ELSE 'Fixed ' + (
                                                            CASE 
                                                                WHEN ls.RateType_NumberMonths % 12 = 0
                                                                    THEN CONVERT(VARCHAR(50), ls.RateType_NumberMonths / 12) + ' Year' + (
                                                                            CASE ls.RateType_NumberMonths
                                                                                WHEN 12
                                                                                    THEN ''
                                                                                ELSE 's'
                                                                                END
                                                                            )
                                                                ELSE CONVERT(VARCHAR(50), ls.RateType_NumberMonths) + ' Month' + (
                                                                        CASE ls.RateType_NumberMonths
                                                                            WHEN 1
                                                                                THEN ''
                                                                            ELSE 's'
                                                                            END
                                                                        )
                                                                END
                                                            )
                                                    END
                                                )
                                        END
                                    ), '') + ' - Payments $' + CONVERT(VARCHAR(50), CONVERT(MONEY, paymentamount), 1) + ' ' + RTRIM(f.FrequencyName)
                        FROM USR_CRM.dbo.Family_Loan_Structure ls
                        LEFT OUTER JOIN USR_CRM.dbo.CTRL_LoanStructureType t
                            ON ls.LoanStructureTypeID = t.LoanStructureTypeID
                        LEFT OUTER JOIN USR_CRM.dbo.API_Frequency f
                            ON ls.PaymentFrequencyID = f.FrequencyID
                        WHERE ls.LoanID = Fl.LoanID
                            AND ls.IsActive = 1
                            AND Amount > 0
                        ORDER BY FixedRateExpiry
                        FOR XML PATH('')
                        ), '') AS FixedExpiryDescription,
                LDAppExps.DATE,
                IIF(dbo.apif_Validate_FeatureAccess(@UserID, 76) = 1, LDSettled.DATE, ISNULL(LDSettled.DATE, LDEstSettled.DATE)),
                LDApproval.DATE,
                LDFinance.DATE,
                CASE 
                    WHEN ISNULL(FL.LoanStatusID, 0) = 0
                        THEN FL.LeadLoanStatusID
                    ELSE FL.LoanStatusID
                    END,
                CASE 
                    WHEN FL.IsElectronicallySubmitted = 1
                        AND Fl.Symmetry_PKLoanID IS NOT NULL
                        THEN FL.LoanID
                    ELSE NULL
                    END,
                CASE 
                    WHEN FL.IsElectronicallySubmitted = 1
                        AND Fl.Symmetry_PKLoanID IS NOT NULL
                        THEN 1
                    WHEN (
                            SELECT TOP 1 1
                            FROM USR_CRM.dbo.API_LoanApplication_NextGen
                            WHERE LoanApplicationID = LS.LoanScenarioID
                                AND (
                                    NextGenID IS NOT NULL
                                    OR DisplayID IS NOT NULL
                                    )
                            ) = 1
                        THEN 1
                    ELSE 0
                    END HasBeenSentToNextGen,
                (
                    SELECT SUM(s4.LMIPremium)
                    FROM USR_CRM.dbo.Family_Loan_Structure s4
                    WHERE s4.LoanID = Fl.LoanID
                        AND s4.IsActive = 1
                        AND s4.CapitaliseLMI = 1
                    ),
                (
                    CASE 
                        WHEN LDSettled.DATE IS NOT NULL
                            THEN 0
                        WHEN LDEstSettled.DATE IS NOT NULL
                            THEN 1
                        ELSE NULL
                        END
                    ) IsEstimated,
                CASE 
                    WHEN c.ConversionStatus IN (2, 9)
                        OR FL.LoanStatusID IN (1, 19)
                        THEN CLS.LoanDisplayName
                    ELSE --consider npw or settled
                        CASE 
                            WHEN c.PipelineCardsID IS NULL
                                THEN CASE 
                                        WHEN ISNULL(CLS.LoanStatusID, 0) = 0
                                            THEN CLS2.LoanDisplayName
                                        ELSE CLS.LoanDisplayName
                                        END
                            ELSE (
                                    SELECT LoanDisplayName
                                    FROM USR_CRM.dbo.CTRL_LoanStatus
                                    WHERE LoanStatusID = s.LinkToLoanStatusId
                                    )
                            END
                    END,
                CASE 
                    WHEN (
                            CLS.LoanStatusID IN (11, 12, 18, 19) --hard code npw statuses
                            OR CLS2.LoanStatusID IN (62)
                            )
                        THEN 19
                    ELSE CASE 
                            WHEN c.PipelineCardsID IS NULL
                                THEN CASE 
                                        WHEN ISNULL(CLS.LoanStatusID, 0) > 0
                                            THEN CLS.LoanStatusID
                                        ELSE CLS2.LoanStatusID
                                        END
                            ELSE CASE 
                                    WHEN CLS.LoanStatusID = 1
                                        THEN CLS.LoanStatusID
                                    ELSE s.LinkToLoanStatusId
                                    END
                            END
                    END,
                ISNULL(LS.IsNotShowLoanApp, 0),
                LS.Title,
                OD.ProposedLoanAmount,
                CASE 
                    WHEN @CountryID = 1
                        THEN CASE 
                                WHEN ISNULL(FL.LoanStatusID, 0) <> 8
                                    THEN 1
                                ELSE 0
                                END -- new app = 8
                    WHEN @CountryID = 2
                        THEN CASE 
                                WHEN FL.LoanStatusID IN (1, 4, 19, 20)
                                    THEN 1
                                ELSE 0
                                END
                    ELSE CASE 
                            WHEN FL.LoanStatusID IN (1)
                                THEN 1
                            ELSE 0
                            END
                    END,
                CASE 
                    WHEN ISNULL(LS.IsOpportunity, 0) = 1
                        THEN LS.IsOpportunity
                    ELSE CASE 
                            WHEN s.CategoryID IN (1, 3)
                                THEN 1
                            ELSE CASE 
                                    WHEN CLS.Category IN ('Opportunity', 'Lead')
                                        THEN 1
                                    ELSE 0
                                    END
                            END
                    END,
                LDNotProceeding.[Date],
                LDPreApproved.[Date],
                LDConditionally.[Date],
                LDEstSettled.[Date],
                FL.LendingCategoryID,
                FL.IsImportedLoan,
                FL.IsLoanFromOtherAggregator,
                CLC.LendingCategory,
                Cat.CategoryLender AS Category,
                Cat.CategoryLenderID,
                LSI.TypeName,
                LAN.IsSendToNPS,
                FL.Probability,
                FL.SubStatusId,
                PSS.SubStatusName,
                LDRepaid.DATE,
                LDVaried.DATE,
                ISNULL(FL.OrgPipelineStatusId, C.OrgPipelineStatusId),
                PL.ProductLenderID
            FROM @Temp T
            INNER JOIN USR_CRM.dbo.Family_Loan FL
                ON FL.LoanID = T.LoanID
            LEFT OUTER JOIN USR_CRM.dbo.API_ProductLender PL
                ON PL.ProductLenderID = FL.ProductLenderID
            LEFT OUTER JOIN USR_CRM.dbo.API_ProductLender_Metadata PLM
                ON PL.ProductLenderMetadataID = PLM.ProductLenderMetadataID
            OUTER APPLY (
                SELECT TOP 1 CategoryLender,
                    CategoryLenderID
                FROM USR_CRM.dbo.View_LenderCategory PLC
                WHERE PLC.ProductLenderID = PL.ProductLenderID
                ) Cat
            LEFT OUTER JOIN USR_CRM.dbo.CTRL_LoanStatus CLS
                ON CLS.LoanStatusID = FL.LoanStatusID
                    AND CLS.IsProspect IS NULL
            LEFT OUTER JOIN USR_CRM.dbo.CTRL_LoanStatus CLS2
                ON CLS2.LoanStatusID = FL.LeadLoanStatusID
                    AND CLS2.IsProspect IS NULL
            LEFT OUTER JOIN USR_CRM.dbo.API_Pipeline_Item_Client_Entity APICE
                ON APICE.ClientID = T.ClientID
            LEFT OUTER JOIN USR_CRM.dbo.API_LoanScenario LS
                ON LS.LoanID = FL.LoanID
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDSettled
                ON LDSettled.loanID = FL.loanID
                    AND LDSettled.TypeOfDateID = 1
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDEstSettled
                ON LDEstSettled.loanID = FL.loanID
                    AND LDEstSettled.TypeOfDateID = 12
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDApproval
                ON LDApproval.loanID = FL.loanID
                    AND LDApproval.TypeOfDateID = 8
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDFinance
                ON LDFinance.loanID = FL.loanID
                    AND LDFinance.TypeOfDateID = 2
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDSubmitted
                ON LDSubmitted.loanID = FL.loanID
                    AND LDSubmitted.TypeOfDateID = 5
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDAppExps
                ON LDAppExps.loanID = FL.loanID
                    AND LDAppExps.TypeOfDateID = 9
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDPreApproval
                ON LDPreApproval.loanID = FL.loanID
                    AND LDPreApproval.TypeOfDateID = 6
            LEFT OUTER JOIN USR_CRM.dbo.API_Pipeline_Cards c
                ON c.ClientFamilyID = t.familyID
                    AND c.LoanScenarioID = LS.LoanScenarioID
                    AND c.isActive = 1
            LEFT OUTER JOIN USR_CRM.dbo.API_CTRL_PipeLineStatus s
                ON c.CurrentStatusID = s.StatusID
            LEFT JOIN USR_CRM.dbo.API_LoanOpportunity_Details OD
                ON OD.LoanScenarioID = LS.LoanScenarioID
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDNotProceeding
                ON LDNotProceeding.loanID = FL.loanID
                    AND LDNotProceeding.TypeOfDateID = 4
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDPreApproved
                ON LDPreApproved.loanID = FL.loanID
                    AND LDPreApproved.TypeOfDateID = 6
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDConditionally
                ON LDConditionally.loanID = FL.loanID
                    AND LDConditionally.TypeOfDateID = 7
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDRepaid
                ON LDRepaid.loanID = FL.loanID
                    AND LDRepaid.TypeOfDateID = 22
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDVaried
                ON LDVaried.loanID = FL.loanID
                    AND LDVaried.TypeOfDateID = 23
            LEFT JOIN USR_CRM.dbo.API_CTRL_PipeLineSubStatus PSS
                ON PSS.PipelineSubStatusID = FL.SubStatusId
            INNER JOIN USR_CRM.dbo.Family_Login OWNEDBY
                ON OWNEDBY.FamilyID = FL.OwnedByAdviserID
            LEFT JOIN USR_CRM.dbo.API_CTRL_LendingCategory CLC
                ON CLC.LendingCategoryID = FL.LendingCategoryID
            LEFT OUTER JOIN USR_CRM.dbo.api_LoanApplication_NPS LAN
                ON FL.LoanID = LAN.LoanID
            OUTER APPLY (
                SELECT TOP 1 TypeName
                FROM USR_CRM.dbo.API_Loan_Security LS
                INNER JOIN USR_CRM.dbo.API_Loan_SecurityInfo LSI
                    ON LSI.LoanSecurityID = LS.LoanSecurityID
                INNER JOIN USR_CRM.dbo.API_CTRL_AssetType ATP
                    ON ATP.AssetTypeID = LSI.FinanceAssetTypeID
                WHERE LS.LoanID = FL.LoanID
                    AND LSI.IsActive = 1
                ORDER BY LSI.IsPrimarySecurity DESC
                ) LSI
        END
        ELSE
        BEGIN
            INSERT @Temp (
                LoanID,
                FamilyID,
                ClientID
                )
            SELECT FL.LoanID,
                F.FamilyID,
                FC.EntityID
            FROM USR_CRM.dbo.Family F
            INNER JOIN USR_CRM.dbo.Family_AssociatedEntity FC
                ON FC.FamilyID = F.FamilyID
            INNER JOIN USR_CRM.dbo.Family_Loan_Client FLC
                ON FC.EntityID = FLC.EntityID
            INNER JOIN USR_CRM.dbo.Family_Loan FL
                ON FL.LoanID = FLC.LoanID
            WHERE F.FamilyID = @FamilyID
                AND FC.IsActive = 1
                AND F.IsActive = 1
                AND FL.IsActive = 1
                AND (
                    FLC.IsApplicant = 1
                    OR FLC.IsGuarantor = 1
                    )

            INSERT INTO @Result (
                LoanId,
                LenderID,
                ProviderName,
                StatusName,
                LoanReference,
                ProductName,
                NextFixedExpiry,
                LoanAmount,
                StatusCategoryname,
                isPipelineLinked,
                ExpiryDate,
                FamilyFullName,
                AdviserName,
                CreatedDate,
                LoanPurpose,
                LoanScenarioID,
                SubmittedDate,
                Applicants,
                FixedExpiryDescription,
                PreApprovalExpiryDate,
                SettledDate,
                ApprovalDate,
                FinanceDate,
                LoanStatusId,
                SubmittedLoanID,
                HasBeenSentToNextGen,
                LMI,
                IsEstimated,
                LoanStatusDisplayName,
                LoanStatusDisplayID,
                IsNotShowLoanApp,
                LoanScenarioTitle,
                LoanOpportunityAmount,
                IsReadOnly,
                IsOpportunity,
                NotProceedingDate,
                PreApprovedDate,
                ConditionallyApprovedDate,
                EstimatedSettlementDate,
                LendingCategoryId,
                IsImportedLoan,
                IsLoanFromOtherAggregator,
                LendingCategoryName,
                Lenders_Category,
                Lenders_CategoryId,
                AssetType,
                IsNPSSurvey,
                Probability,
                SubStatusId,
                SubStatusName,
                RepaidDate,
                VariedDate,
                OrgPipelineStatusId,
                ProductLenderId
                )
            SELECT DISTINCT FL.LoanID,
                ISNULL(CAST(PLM.InternalReference AS INT), 0),
                LTRIM(RTRIM(ISNULL(PL.FullName, ''))),
                CASE 
                    WHEN ISNULL(FL.LoanStatusID, 0) = 0
                        THEN CLS2.LoanStatusName
                    ELSE LTRIM(RTRIM(CLS.LoanStatusName))
                    END,
                ISNULL(FL.LoanReferenceNumber, ''),
                STUFF((
                        SELECT DISTINCT ', ' + RTRIM(ISNULL((
                                        CASE @CountryID
                                            WHEN 2
                                                THEN pd3.ProductName
                                            WHEN 3
                                                THEN pd4.ProductName
                                            ELSE pd2.ProductName
                                            END
                                        ), ''))
                        FROM USR_CRM.dbo.Family_Loan_Structure s2
                        LEFT OUTER JOIN USR_CRM.dbo.API_NZ_Products pd2
                            ON s2.ProductID = pd2.ProductID
                                AND @CountryID = 1
                        LEFT OUTER JOIN USR_CRM.dbo.API_AU_Products pd3
                            ON s2.ProductID = pd3.ProductID
                                AND @CountryID = 2
                        LEFT OUTER JOIN USR_CRM.dbo.API_ID_Products pd4
                            ON s2.ProductID = pd4.ProductID
                                AND @CountryID = 3
                        WHERE s2.LoanID = Fl.LoanID
                            AND s2.IsActive = 1
                        FOR XML PATH('')
                        ), 1, 2, ''),
                (
                    SELECT MIN(s3.fixedrateexpiry)
                    FROM USR_CRM.dbo.Family_Loan_Structure s3
                    LEFT OUTER JOIN (
                        SELECT ProductID,
                            RateType,
                            Rate InterestRate
                        FROM USR_CRM.dbo.API_NZ_Products
                        WHERE @CountryID = 1
                        --Cant get RateTerm for NZ products
                        
                        UNION ALL
                        
                        SELECT ProductID,
                            InterestRateTypeInitial RateType,
                            InitialRate InterestRate
                        FROM USR_CRM.dbo.API_AU_Products
                        WHERE @CountryID = 2
                        
                        UNION ALL
                        
                        SELECT ProductID,
                            InterestRateTypeInitial RateType,
                            InitialRate InterestRate
                        FROM USR_CRM.dbo.API_ID_Products
                        WHERE @CountryID = 3
                        ) pd
                        ON pd.ProductID = s3.ProductID
                    WHERE s3.loanid = Fl.loanid
                        AND s3.isactive = 1
                        AND (
                            CASE 
                                WHEN NULLIF(s3.RateType, '') IS NULL
                                    THEN (
                                            CASE 
                                                WHEN CHARINDEX('Fixed', pd.RateType) > 0
                                                    THEN 'Fixed'
                                                WHEN s3.FixedRateExpiry IS NOT NULL
                                                    THEN 'Fixed'
                                                ELSE 'Floating'
                                                END
                                            )
                                ELSE s3.RateType
                                END
                            ) = 'Fixed'
                    ),
                (
                    SELECT SUM(s4.Amount)
                    FROM USR_CRM.dbo.Family_Loan_Structure s4
                    WHERE s4.LoanID = Fl.LoanID
                        AND s4.IsActive = 1
                    ),
                CASE 
                    WHEN c.PipelineCardsID IS NULL
                        OR FL.LoanStatusID IN (1, 19, 11, 12, 18)
                        OR FL.LoanStatusID IN (
                            SELECT LoanStatusId
                            FROM #PREVIOUSLOANSTATUSES
                            )
                        THEN --settled and NPW statuses
                            ISNULL(CLS.V2Category, CLS2.V2Category)
                    ELSE (
                            SELECT V2Category
                            FROM USR_CRM.dbo.CTRL_LoanStatus
                            WHERE LoanStatusID = s.LinkToLoanStatusId
                            )
                    END AS StatusCategoryName,
                (
                    CASE 
                        WHEN CLS.V2Category = 'InProgress'
                            AND APICE.PipelineItemID IS NOT NULL
                            THEN 1
                        WHEN (
                                ISNULL(FL.LeadLoanStatusId, 0) > 0
                                AND ISNULL(FL.LoanStatusID, 0) = 0
                                )
                            AND APICE.PipelineItemID IS NOT NULL
                            THEN 1
                        ELSE 0
                        END
                    ),
                (
                    CASE 
                        WHEN CLS.LoanStatusID = 3
                            THEN ISNULL(LDAppExps.DATE, DATEADD(MONTH, 3, LDPreApproval.DATE))
                        WHEN CLS.LoanStatusID = 10
                            THEN ISNULL(LDAppExps.DATE, DATEADD(MONTH, 3, LDApproval.DATE))
                        END
                    ),
                SYS_CRM.dbo.apif_Get_Family_FullName(t.FamilyID),
                SYS_CRM.dbo.apif_Get_User_FullName(FL.OwnedByAdviserID),
                FL.DateCreated,
                STUFF((
                        SELECT ', ' + p.Purpose
                        FROM USR_CRM.dbo.API_LoanScenario ls
                        INNER JOIN USR_CRM.dbo.API_LoanApplication_Objectives o
                            ON ls.LoanScenarioID = o.LoanApplicationID
                                AND o.QuestionID = 5 --5=PrimaryPurpose question
                        INNER JOIN USR_CRM.dbo.API_CTRL_LoanApplication_PrimaryPurpose p
                            ON o.AnswerInt = p.PurposeID
                        WHERE ls.LoanID = FL.LoanID
                            AND o.IsActive = 1
                        FOR XML PATH('')
                        ), 1, 1, ''),
                LS.LoanScenarioID,
                LDSubmitted.DATE,
                STUFF((
                        SELECT ', ' + ISNULL(fae.EntityName, (afc.FirstName + ' ' + afc.LastName))
                        FROM USR_CRM.dbo.Family_Loan_Client alc
                        LEFT JOIN USR_CRM.dbo.Family_Client afc
                            ON afc.ClientID = alc.ClientID
                                AND (
                                    alc.IsApplicant = 1
                                    OR alc.IsGuarantor = 1
                                    )
                                AND ISNULL(afc.Deceased, 0) <> 1
                                AND afc.RoleID = 1
                        LEFT JOIN USR_CRM.dbo.Family_AssociatedEntity fae
                            ON fae.EntityID = alc.EntityID
                                AND alc.IsApplicant = 1
                        WHERE alc.LoanID = FL.LoanID
                        FOR XML PATH('')
                        ), 1, 1, ''),
                ISNULL((
                        SELECT ' - ' + t.NAME + ' - ' + ISNULL(CONVERT(VARCHAR(50), ROUND(ls.InterestRate * 100, 2)), '-') + '% ' + ISNULL((
                                    CASE ls.RateType
                                        WHEN ''
                                            THEN NULL
                                        ELSE (
                                                CASE 
                                                    WHEN ls.RateType_NumberMonths = 0
                                                        THEN 'Floating'
                                                    ELSE 'Fixed ' + (
                                                            CASE 
                                                                WHEN ls.RateType_NumberMonths % 12 = 0
                                                                    THEN CONVERT(VARCHAR(50), ls.RateType_NumberMonths / 12) + ' Year' + (
                                                                            CASE ls.RateType_NumberMonths
                                                                                WHEN 12
                                                                                    THEN ''
                                                                                ELSE 's'
                                                                                END
                                                                            )
                                                                ELSE CONVERT(VARCHAR(50), ls.RateType_NumberMonths) + ' Month' + (
                                                                        CASE ls.RateType_NumberMonths
                                                                            WHEN 1
                                                                                THEN ''
                                                                            ELSE 's'
                                                                            END
                                                                        )
                                                                END
                                                            )
                                                    END
                                                )
                                        END
                                    ), '') + ' - Payments $' + CONVERT(VARCHAR(50), CONVERT(MONEY, paymentamount), 1) + ' ' + RTRIM(f.FrequencyName)
                        FROM USR_CRM.dbo.Family_Loan_Structure ls
                        LEFT OUTER JOIN USR_CRM.dbo.CTRL_LoanStructureType t
                            ON ls.LoanStructureTypeID = t.LoanStructureTypeID
                        LEFT OUTER JOIN USR_CRM.dbo.API_Frequency f
                            ON ls.PaymentFrequencyID = f.FrequencyID
                        WHERE ls.LoanID = Fl.LoanID
                            AND ls.IsActive = 1
                            AND Amount > 0
                        ORDER BY FixedRateExpiry
                        FOR XML PATH('')
                        ), '') AS FixedExpiryDescription,
                LDAppExps.DATE,
                IIF(dbo.apif_Validate_FeatureAccess(@UserID, 76) = 1, LDSettled.DATE, ISNULL(LDSettled.DATE, LDEstSettled.DATE)),
                LDApproval.DATE,
                LDFinance.DATE,
                CASE 
                    WHEN ISNULL(FL.LoanStatusID, 0) = 0
                        THEN FL.LeadLoanStatusID
                    ELSE FL.LoanStatusID
                    END,
                CASE 
                    WHEN FL.IsElectronicallySubmitted = 1
                        AND Fl.Symmetry_PKLoanID IS NOT NULL
                        THEN FL.LoanID
                    ELSE NULL
                    END,
                CASE 
                    WHEN FL.IsElectronicallySubmitted = 1
                        AND Fl.Symmetry_PKLoanID IS NOT NULL
                        THEN 1
                    WHEN (
                            SELECT TOP 1 1
                            FROM USR_CRM.dbo.API_LoanApplication_NextGen
                            WHERE LoanApplicationID = LS.LoanScenarioID
                                AND (
                                    NextGenID IS NOT NULL
                                    OR DisplayID IS NOT NULL
                                    )
                            ) = 1
                        THEN 1
                    ELSE 0
                    END HasBeenSentToNextGen,
                (
                    SELECT SUM(s4.LMIPremium)
                    FROM USR_CRM.dbo.Family_Loan_Structure s4
                    WHERE s4.LoanID = Fl.LoanID
                        AND s4.IsActive = 1
                        AND s4.CapitaliseLMI = 1
                    ),
                (
                    CASE 
                        WHEN LDSettled.DATE IS NOT NULL
                            THEN 0
                        WHEN LDEstSettled.DATE IS NOT NULL
                            THEN 1
                        ELSE NULL
                        END
                    ) IsEstimated,
                CASE 
                    WHEN c.ConversionStatus IN (2, 9)
                        OR FL.LoanStatusID IN (1, 19)
                        THEN CLS.LoanDisplayName
                    ELSE --consider npw or settled
                        CASE 
                            WHEN c.PipelineCardsID IS NULL
                                THEN CASE 
                                        WHEN ISNULL(CLS.LoanStatusID, 0) = 0
                                            THEN CLS2.LoanDisplayName
                                        ELSE CLS.LoanDisplayName
                                        END
                            ELSE (
                                    SELECT LoanDisplayName
                                    FROM USR_CRM.dbo.CTRL_LoanStatus
                                    WHERE LoanStatusID = s.LinkToLoanStatusId
                                    )
                            END
                    END,
                CASE 
                    WHEN (
                            CLS.LoanStatusID IN (11, 12, 18, 19) --hard code npw statuses
                            OR CLS2.LoanStatusID IN (62)
                            )
                        THEN 19
                    ELSE CASE 
                            WHEN c.PipelineCardsID IS NULL
                                THEN CASE 
                                        WHEN ISNULL(CLS.LoanStatusID, 0) > 0
                                            THEN CLS.LoanStatusID
                                        ELSE CLS2.LoanStatusID
                                        END
                            ELSE CASE 
                                    WHEN CLS.LoanStatusID = 1
                                        THEN CLS.LoanStatusID
                                    ELSE s.LinkToLoanStatusId
                                    END
                            END
                    END,
                ISNULL(LS.IsNotShowLoanApp, 0),
                LS.Title,
                OD.ProposedLoanAmount,
                CASE 
                    WHEN @CountryID = 1
                        THEN CASE 
                                WHEN ISNULL(FL.LoanStatusID, 0) <> 8
                                    THEN 1
                                ELSE 0
                                END -- new app = 8
                    WHEN @CountryID = 2
                        THEN CASE 
                                WHEN FL.LoanStatusID IN (1, 4, 19, 20)
                                    THEN 1
                                ELSE 0
                                END
                    ELSE CASE 
                            WHEN FL.LoanStatusID IN (1)
                                THEN 1
                            ELSE 0
                            END
                    END,
                CASE 
                    WHEN ISNULL(LS.IsOpportunity, 0) = 1
                        THEN LS.IsOpportunity
                    ELSE CASE 
                            WHEN s.CategoryID IN (1, 3)
                                THEN 1
                            ELSE CASE 
                                    WHEN CLS.Category IN ('Opportunity', 'Lead')
                                        THEN 1
                                    ELSE 0
                                    END
                            END
                    END,
                LDNotProceeding.[Date],
                LDPreApproved.[Date],
                LDConditionally.[Date],
                LDEstSettled.[Date],
                FL.LendingCategoryID,
                FL.IsImportedLoan,
                FL.IsLoanFromOtherAggregator,
                CLC.LendingCategory,
                Cat.CategoryLender AS Category,
                Cat.CategoryLenderID,
                LSI.TypeName,
                LAN.IsSendToNPS,
                FL.Probability,
                FL.SubStatusId,
                PSS.SubStatusName,
                LDRepaid.DATE,
                LDVaried.DATE,
                ISNULL(FL.OrgPipelineStatusId, C.OrgPipelineStatusId),
                PL.ProductLenderID
            FROM @Temp T
            INNER JOIN USR_CRM.dbo.Family_Loan FL
                ON FL.LoanID = T.LoanID
            LEFT OUTER JOIN USR_CRM.dbo.API_ProductLender PL
                ON PL.ProductLenderID = FL.ProductLenderID
            LEFT OUTER JOIN USR_CRM.dbo.API_ProductLender_Metadata PLM
                ON PL.ProductLenderMetadataID = PLM.ProductLenderMetadataID
            OUTER APPLY (
                SELECT TOP 1 CategoryLender,
                    CategoryLenderID
                FROM USR_CRM.dbo.View_LenderCategory PLC
                WHERE PLC.ProductLenderID = PL.ProductLenderID
                ) Cat
            LEFT OUTER JOIN USR_CRM.dbo.CTRL_LoanStatus CLS
                ON CLS.LoanStatusID = FL.LoanStatusID
                    AND CLS.IsProspect IS NULL
            LEFT OUTER JOIN USR_CRM.dbo.CTRL_LoanStatus CLS2
                ON CLS2.LoanStatusID = FL.LeadLoanStatusID
                    AND CLS2.IsProspect IS NULL
            LEFT OUTER JOIN USR_CRM.dbo.API_Pipeline_Item_Client_Entity APICE
                ON APICE.EntityID = T.EntityID
            LEFT OUTER JOIN USR_CRM.dbo.API_LoanScenario LS
                ON LS.LoanID = FL.LoanID
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDSettled
                ON LDSettled.loanID = FL.loanID
                    AND LDSettled.TypeOfDateID = 1
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDEstSettled
                ON LDEstSettled.loanID = FL.loanID
                    AND LDEstSettled.TypeOfDateID = 12
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDApproval
                ON LDApproval.loanID = FL.loanID
                    AND LDApproval.TypeOfDateID = 8
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDFinance
                ON LDFinance.loanID = FL.loanID
                    AND LDFinance.TypeOfDateID = 2
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDSubmitted
                ON LDSubmitted.loanID = FL.loanID
                    AND LDSubmitted.TypeOfDateID = 5
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDAppExps
                ON LDAppExps.loanID = FL.loanID
                    AND LDAppExps.TypeOfDateID = 9
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDPreApproval
                ON LDPreApproval.loanID = FL.loanID
                    AND LDPreApproval.TypeOfDateID = 6
            LEFT OUTER JOIN USR_CRM.dbo.API_Pipeline_Cards c
                ON c.ClientFamilyID = t.familyID
                    AND c.LoanScenarioID = LS.LoanScenarioID
                    AND c.isActive = 1
            LEFT OUTER JOIN USR_CRM.dbo.API_CTRL_PipeLineStatus s
                ON c.CurrentStatusID = s.StatusID
            LEFT JOIN USR_CRM.dbo.API_LoanOpportunity_Details OD
                ON OD.LoanScenarioID = LS.LoanScenarioID
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDNotProceeding
                ON LDNotProceeding.loanID = FL.loanID
                    AND LDNotProceeding.TypeOfDateID = 4
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDPreApproved
                ON LDPreApproved.loanID = FL.loanID
                    AND LDPreApproved.TypeOfDateID = 6
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDConditionally
                ON LDConditionally.loanID = FL.loanID
                    AND LDConditionally.TypeOfDateID = 7
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDRepaid
                ON LDRepaid.loanID = FL.loanID
                    AND LDRepaid.TypeOfDateID = 22
            LEFT OUTER JOIN USR_CRM.dbo.API_loanApplication_Dates LDVaried
                ON LDVaried.loanID = FL.loanID
                    AND LDVaried.TypeOfDateID = 23
            LEFT JOIN USR_CRM.dbo.API_CTRL_PipeLineSubStatus PSS
                ON PSS.PipelineSubStatusID = FL.SubStatusId
            INNER JOIN USR_CRM.dbo.Family_Login OWNEDBY
                ON OWNEDBY.FamilyID = FL.OwnedByAdviserID
            LEFT JOIN USR_CRM.dbo.API_CTRL_LendingCategory CLC
                ON CLC.LendingCategoryID = FL.LendingCategoryID
            LEFT OUTER JOIN USR_CRM.dbo.api_LoanApplication_NPS LAN
                ON FL.LoanID = LAN.LoanID
            OUTER APPLY (
                SELECT TOP 1 TypeName
                FROM USR_CRM.dbo.API_Loan_Security LS
                INNER JOIN USR_CRM.dbo.API_Loan_SecurityInfo LSI
                    ON LSI.LoanSecurityID = LS.LoanSecurityID
                INNER JOIN USR_CRM.dbo.API_CTRL_AssetType ATP
                    ON ATP.AssetTypeID = LSI.FinanceAssetTypeID
                WHERE LS.LoanID = FL.LoanID
                    AND LSI.IsActive = 1
                ORDER BY LSI.IsPrimarySecurity DESC
                ) LSI
        END

        UPDATE r
        SET r.PipelineCardsID = (
                SELECT TOP 1 c.PipelineCardsID
                FROM USR_CRM.dbo.API_LoanScenario ls
                INNER JOIN USR_CRM.dbo.API_Pipeline_Cards c
                    ON c.LoanScenarioID = ls.LoanScenarioID
                WHERE ls.LoanScenarioID = r.LoanScenarioID
                ORDER BY c.PipelineCardsID DESC
                ),
            r.PipelineStatusID = (
                SELECT TOP 1 s.StatusID
                FROM USR_CRM.dbo.API_LoanScenario ls
                INNER JOIN USR_CRM.dbo.API_Pipeline_Cards c
                    ON c.LoanScenarioID = ls.LoanScenarioID
                INNER JOIN USR_CRM.dbo.API_CTRL_PipeLineStatus s
                    ON c.CurrentStatusID = s.StatusID
                WHERE ls.LoanScenarioID = r.LoanScenarioID
                ORDER BY s.StatusID DESC
                ),
            r.PipelineStatus = (
                SELECT TOP 1 s.StatusName
                FROM USR_CRM.dbo.API_LoanScenario ls
                INNER JOIN USR_CRM.dbo.API_Pipeline_Cards c
                    ON c.LoanScenarioID = ls.LoanScenarioID
                INNER JOIN USR_CRM.dbo.API_CTRL_PipeLineStatus s
                    ON c.CurrentStatusID = s.StatusID
                WHERE ls.LoanScenarioID = r.LoanScenarioID
                ORDER BY s.StatusID DESC
                )
        FROM @Result r
    END

    UPDATE @Result
    SET IsOpportunity = 0
    WHERE LoanStatusId IN (
            SELECT LoanStatusId
            FROM #PREVIOUSLOANSTATUSES
            )

    SELECT LoanId,
        LenderID,
        ProviderName,
        StatusName,
        LoanReference,
        SettledDate,
        ApprovalDate,
        ProductName,
        NextFixedExpiry,
        LoanAmount,
        StatusCategoryname,
        isPipelineLinked,
        ExpiryDate,
        FamilyFullName,
        AdviserName,
        CreatedDate,
        LoanPurpose,
        LoanScenarioID,
        SubmittedDate,
        Applicants,
        FinanceDate,
        ClientName,
        FixedExpiryDescription,
        PipelineCardsID,
        PipelineStatusID,
        PipelineStatus,
        PreApprovalExpiryDate,
        LoanStatusId,
        SubmittedLoanID,
        HasBeenSentToNextGen,
        LMI,
        IsEstimated,
        LoanStatusDisplayName,
        LoanStatusDisplayID,
        IsNotShowLoanApp,
        LoanScenarioTitle,
        LoanOpportunityAmount,
        IsReadOnly,
        IsOpportunity,
        @CountryCode CountryCode,
        NotProceedingDate,
        PreApprovedDate,
        ConditionallyApprovedDate,
        EstimatedSettlementDate,
        LendingCategoryId,
        IsImportedLoan,
        IsLoanFromOtherAggregator,
        LendingCategoryName,
        Lenders_Category,
        Lenders_CategoryId,
        AssetType,
        IsNPSSurvey,
        Probability,
        SubStatusId,
        SubStatusName,
        RepaidDate,
        VariedDate,
        OrgPipelineStatusId,
        ProductLenderID
    FROM @Result
    ORDER BY CreatedDate,
        SettledDate DESC
END
GO
