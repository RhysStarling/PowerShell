# Requires -Modules ImportExcel, Az.Accounts

# Email Parameters
$from = ""
$to = ""

# Log in to Azure
Connect-AzAccount -ServicePrincipal -Credential $Secret:psu_CarbonReportPSCred -TenantId $tenantId -WarningAction Ignore


# Get Subscriptions
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }


# Calculate Target Month 
$today       = Get-Date
$targetMonth = $today.AddMonths(-1)
$startDate   = Get-Date -Year $targetMonth.Year -Month $targetMonth.Month -Day 1
$endDate     = ($startDate.AddMonths(1)).AddDays(-1)

Write-Host "Generating carbon emissions report for:"
Write-Host "From: $($startDate.ToString('yyyy-MM-dd'))"
Write-Host "To:   $($endDate.ToString('yyyy-MM-dd'))`n"


# Collect Emissions Data
$allResults = @()

foreach ($sub in $subscriptions) {
    Write-Host "Processing: $($sub.Name) ($($sub.Id))"

    $queryFilterParams = @{
        CarbonScopeList     = @('Scope1', 'Scope2', 'Scope3')
        DateRangeStart      = $startDate
        DateRangeEnd        = $endDate
        SubscriptionList    = $sub.Id
    }

    $queryFilter = New-AzCarbonMonthlySummaryReportQueryFilterObject @queryFilterParams
    $report      = Get-AzCarbonEmissionReport -QueryParameter $queryFilter

    foreach ($item in $report.Value) {
        $obj = [PSCustomObject]@{
            SubscriptionName                 = $sub.Name
            Date                             = $item.Date
            LatestMonthEmission              = $item.LatestMonthEmission
            PreviousMonthEmission            = $item.PreviousMonthEmission
            MonthlyEmissionsChangeValue      = $item.MonthlyEmissionsChangeValue
            MonthOverMonthEmissionsChangeRatio = $item.MonthOverMonthEmissionsChangeRatio
            LatestMonthEmissionFormatted     = "$($item.LatestMonthEmission) tCO2e"
            PreviousMonthEmissionFormatted   = "$($item.PreviousMonthEmission) tCO2e"
            MonthlyEmissionsChangeFormatted  = "$($item.MonthlyEmissionsChangeValue) tCO2e"
            MonthOverMonthChangePercentFormatted = "{0:N2}%" -f $item.MonthOverMonthEmissionsChangeRatio
        }
        $allResults += $obj
    }
}

# Export to Excel
$reportFileName = "Carbon Emissions Report-$($startDate.ToString('yyyy-MM')).xlsx"
$reportFilePath = Join-Path -Path $env:TEMP -ChildPath $reportFileName

$excelParams = @{
    Path          = $reportFilePath
    WorksheetName = 'Emissions Report'
    AutoSize      = $true
    BoldTopRow    = $true
    FreezeTopRow  = $true
    TableName     = 'EmissionsData'
    TableStyle    = 'Light1'
    ClearSheet    = $true
}

$allResults | Select-Object `
    SubscriptionName,
    Date,
    LatestMonthEmission,
    PreviousMonthEmission,
    MonthlyEmissionsChangeValue,
    MonthOverMonthEmissionsChangeRatio |
    Export-Excel @excelParams

Write-Host "Excel report saved to: $reportFilePath"


# Build HTML Table
$htmlTableRows = $allResults | ForEach-Object {
    "<tr>
        <td>$($_.SubscriptionName)</td>
        <td>$($_.Date)</td>
        <td>$($_.LatestMonthEmissionFormatted)</td>
        <td>$($_.PreviousMonthEmissionFormatted)</td>
        <td>$($_.MonthlyEmissionsChangeFormatted)</td>
        <td>$($_.MonthOverMonthChangePercentFormatted)</td>
    </tr>"
}

$computerName = $env:COMPUTERNAME

$htmlBody = @"
<html>
<head>
    <style>
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #dddddd; text-align: center; padding: 6px; white-space: nowrap; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <p>Hello,</p>
    <p>Please find attached the carbon emissions report for $($startDate.ToString('MMMM yyyy')). Below is a quick summary:</p>
    <table>
        <tr>
            <th>Subscription Name</th>
            <th>Date</th>
            <th>Latest Month Emission (tCO2e)</th>
            <th>Previous Month Emission (tCO2e)</th>
            <th>Monthly Emissions Change (tCO2e)</th>
            <th>Month-over-Month Change (%)</th>
        </tr>
        $($htmlTableRows -join "`n")
    </table>
    <p>Regards,<br>Hosting Team</p>
    <p><small>Sent from $computerName</small></p>
</body>
</html>
"@


# Send Email
$emailParams = @{
    From        = $from
    To          = $to
    Subject     = "Carbon Emissions Report - $($startDate.ToString('MMMM yyyy'))"
    Body        = $htmlBody
    BodyAsHtml  = $true
    SmtpServer  = $SmtpServer
    Attachments = $reportFilePath
    WarningAction = "Ignore"
}

Send-MailMessage @emailParams


Remove-Item $reportFilePath -Force
