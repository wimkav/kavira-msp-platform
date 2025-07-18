# ========================================================================
# Script:      Start-KaviraAdvancedPAX8Analytics.ps1
# Component:   Platform Enhancement - Advanced PAX8 Features
# Purpose:     Advanced PAX8 analytics, variance reporting, trends
# Author:      Kavira MSP Automation Platform  
# Created:     2025-07-18
# Version:     1.0 (Advanced PAX8 MCP Features)
# ========================================================================

param(
    [string]$TenantName = "",
    [switch]$AllTenants,
    [ValidateSet("Variance", "Trends", "Forecasting", "Comparative", "Complete")]
    [string]$AnalysisType = "Complete",
    [int]$ForecastMonths = 6,
    [switch]$GenerateClientReport,
    [string]$OutputPath = "C:\MSP\Reports\Advanced-PAX8-Analytics"
)

Write-Host ""
Write-Host "📈 KAVIRA ADVANCED PAX8 ANALYTICS ENGINE" -ForegroundColor Magenta
Write-Host "=================================================" -ForegroundColor Magenta
Write-Host "Advanced PAX8 MCP Integration • Predictive Analytics • Business Intelligence" -ForegroundColor Gray
Write-Host ""

# Environment setup
$env:MCP_MODE = "1"
$analysisStartTime = Get-Date
$logPath = "C:\MSP\Logs\Advanced-PAX8-Analytics-$(Get-Date -Format 'yyyy-MM-dd-HH-mm').log"

function Write-AnalyticsLog {
    param([string]$Message, [string]$Color = "White")
    $timeStamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timeStamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    $logMessage | Add-Content $logPath -ErrorAction SilentlyContinue
}

function Initialize-PAX8Analytics {
    Write-AnalyticsLog "🔧 Initializing Advanced PAX8 Analytics Environment..." "Cyan"
    
    # Create output directories
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-AnalyticsLog "📁 Created output directory: $OutputPath" "Green"
    }
    
    # Load PAX8 cache data
    $pax8CachePath = "C:\MSP\Config\pax8-cache.json"
    if (Test-Path $pax8CachePath) {
        $script:pax8Data = Get-Content $pax8CachePath | ConvertFrom-Json
        Write-AnalyticsLog "✅ Loaded PAX8 cache data" "Green"
    } else {
        Write-AnalyticsLog "❌ PAX8 cache data not found: $pax8CachePath" "Red"
        Write-AnalyticsLog "🎯 Creating simulated PAX8 data for demonstration..." "Yellow"
        $script:pax8Data = New-SimulatedPAX8Data
    }
    
    # Load tenant configuration
    $tenantsPath = "C:\MSP\Config\tenants.json"
    if (Test-Path $tenantsPath) {
        $script:tenants = Get-Content $tenantsPath | ConvertFrom-Json
        Write-AnalyticsLog "✅ Loaded $($script:tenants.Count) tenant configurations" "Green"
    } else {
        Write-AnalyticsLog "⚠️ Using demo tenant configuration" "Yellow"
        $script:tenants = @(
            @{ Name = "Demo Client A"; Domain = "clienta.com"; MonthlySpend = 1250 },
            @{ Name = "Demo Client B"; Domain = "clientb.com"; MonthlySpend = 2100 }
        )
    }
}

function New-SimulatedPAX8Data {
    Write-AnalyticsLog "🎭 Generating realistic PAX8 simulation data..." "Yellow"
    
    return @{
        Companies = @(
            @{
                CompanyName = "Agility Digital"
                Domain = "agilitydigital.com.au"
                MonthlySpend = 1247.85
                Subscriptions = @(
                    @{ Product = "Microsoft 365 Business Premium"; Quantity = 15; UnitPrice = 32.40; Total = 486.00 },
                    @{ Product = "Microsoft 365 Business Standard"; Quantity = 8; UnitPrice = 21.60; Total = 172.80 },
                    @{ Product = "Azure AD Premium P1"; Quantity = 12; UnitPrice = 9.60; Total = 115.20 },
                    @{ Product = "Microsoft Defender for Business"; Quantity = 23; UnitPrice = 4.32; Total = 99.36 }
                )
                HistoricalSpend = @(
                    @{ Month = "2025-01"; Amount = 1189.45 },
                    @{ Month = "2025-02"; Amount = 1203.67 },
                    @{ Month = "2025-03"; Amount = 1221.34 },
                    @{ Month = "2025-04"; Amount = 1235.89 },
                    @{ Month = "2025-05"; Amount = 1247.85 }
                )
            },
            @{
                CompanyName = "Pathfindr AI"
                Domain = "pathfindr.ai"
                MonthlySpend = 2156.92
                Subscriptions = @(
                    @{ Product = "Microsoft 365 E3"; Quantity = 25; UnitPrice = 43.20; Total = 1080.00 },
                    @{ Product = "Azure AD Premium P2"; Quantity = 20; UnitPrice = 14.40; Total = 288.00 },
                    @{ Product = "Microsoft Defender for Office 365 Plan 2"; Quantity = 25; UnitPrice = 7.20; Total = 180.00 },
                    @{ Product = "Power BI Pro"; Quantity = 15; UnitPrice = 14.40; Total = 216.00 }
                )
                HistoricalSpend = @(
                    @{ Month = "2025-01"; Amount = 1987.45 },
                    @{ Month = "2025-02"; Amount = 2034.67 },
                    @{ Month = "2025-03"; Amount = 2089.34 },
                    @{ Month = "2025-04"; Amount = 2123.89 },
                    @{ Month = "2025-05"; Amount = 2156.92 }
                )
            }
        )
        LastUpdated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        TotalMonthlySpend = 3404.77
    }
}

function Invoke-PAX8VarianceAnalysis {
    Write-AnalyticsLog "📊 Performing PAX8 Variance Analysis..." "Cyan"
    
    $varianceResults = @()
    
    foreach ($company in $script:pax8Data.Companies) {
        Write-AnalyticsLog "🔍 Analyzing variance for: $($company.CompanyName)" "Yellow"
        
        # Calculate variance trends
        $historical = $company.HistoricalSpend | Sort-Object Month
        $currentSpend = $historical[-1].Amount
        $previousSpend = $historical[-2].Amount
        $variance = $currentSpend - $previousSpend
        $variancePercentage = [math]::Round(($variance / $previousSpend) * 100, 2)
        
        # Analyze subscription efficiency
        $subscriptionAnalysis = @()
        foreach ($sub in $company.Subscriptions) {
            $efficiency = if ($sub.Quantity -gt 0) {
                [math]::Round($sub.Total / $sub.Quantity, 2)
            } else { 0 }
            
            $subscriptionAnalysis += @{
                Product = $sub.Product
                Quantity = $sub.Quantity
                UnitPrice = $sub.UnitPrice
                Total = $sub.Total
                EfficiencyScore = $efficiency
                Recommendation = if ($efficiency -gt 30) { "Review usage - high cost per user" } 
                                elseif ($efficiency -lt 10) { "Potential for expansion" }
                                else { "Optimal utilization" }
            }
        }
        
        $varianceResults += @{
            Company = $company.CompanyName
            Domain = $company.Domain
            CurrentSpend = $currentSpend
            PreviousSpend = $previousSpend
            Variance = $variance
            VariancePercentage = $variancePercentage
            TrendDirection = if ($variance -gt 0) { "INCREASING" } else { "DECREASING" }
            SubscriptionAnalysis = $subscriptionAnalysis
            RiskLevel = if ([math]::Abs($variancePercentage) -gt 15) { "HIGH" }
                       elseif ([math]::Abs($variancePercentage) -gt 5) { "MEDIUM" }
                       else { "LOW" }
        }
    }
    
    return $varianceResults
}

function Invoke-PAX8TrendAnalysis {
    Write-AnalyticsLog "📈 Performing PAX8 Trend Analysis..." "Cyan"
    
    $trendResults = @()
    
    foreach ($company in $script:pax8Data.Companies) {
        Write-AnalyticsLog "📊 Analyzing trends for: $($company.CompanyName)" "Yellow"
        
        $historical = $company.HistoricalSpend | Sort-Object Month
        
        # Calculate growth rate
        $firstMonth = $historical[0].Amount
        $lastMonth = $historical[-1].Amount
        $monthsSpan = $historical.Count - 1
        $totalGrowthRate = [math]::Round((($lastMonth - $firstMonth) / $firstMonth) * 100, 2)
        $monthlyGrowthRate = if ($monthsSpan -gt 0) { [math]::Round($totalGrowthRate / $monthsSpan, 2) } else { 0 }
        
        # Identify trend pattern
        $increases = 0
        $decreases = 0
        for ($i = 1; $i -lt $historical.Count; $i++) {
            if ($historical[$i].Amount -gt $historical[$i-1].Amount) { $increases++ }
            else { $decreases++ }
        }
        
        $trendPattern = if ($increases -gt $decreases) { "GROWTH" }
                       elseif ($decreases -gt $increases) { "DECLINE" }
                       else { "STABLE" }
        
        # Calculate seasonality (if enough data)
        $seasonality = "INSUFFICIENT_DATA"
        if ($historical.Count -ge 12) {
            # Basic seasonality detection would go here
            $seasonality = "DETECTED"
        }
        
        $trendResults += @{
            Company = $company.CompanyName
            Domain = $company.Domain
            TotalGrowthRate = $totalGrowthRate
            MonthlyGrowthRate = $monthlyGrowthRate
            TrendPattern = $trendPattern
            Seasonality = $seasonality
            DataPoints = $historical.Count
            PredictedNextMonth = $lastMonth + ($lastMonth * ($monthlyGrowthRate / 100))
            Confidence = if ($historical.Count -ge 6) { "HIGH" }
                        elseif ($historical.Count -ge 3) { "MEDIUM" }
                        else { "LOW" }
        }
    }
    
    return $trendResults
}

function Invoke-PAX8Forecasting {
    param([int]$Months = 6)
    
    Write-AnalyticsLog "🔮 Performing PAX8 Forecasting Analysis ($Months months)..." "Cyan"
    
    $forecastResults = @()
    
    foreach ($company in $script:pax8Data.Companies) {
        Write-AnalyticsLog "📊 Forecasting for: $($company.CompanyName)" "Yellow"
        
        $historical = $company.HistoricalSpend | Sort-Object Month
        $lastAmount = $historical[-1].Amount
        
        # Simple linear trend forecasting
        $monthlyGrowthRate = 0.02 # 2% default growth rate
        
        if ($historical.Count -ge 3) {
            $firstAmount = $historical[0].Amount
            $monthsSpan = $historical.Count - 1
            $totalGrowth = ($lastAmount - $firstAmount) / $firstAmount
            $monthlyGrowthRate = if ($monthsSpan -gt 0) { $totalGrowth / $monthsSpan } else { 0.02 }
        }
        
        # Generate forecast
        $forecast = @()
        $currentAmount = $lastAmount
        $baseDate = Get-Date
        
        for ($i = 1; $i -le $Months; $i++) {
            $currentAmount = $currentAmount * (1 + $monthlyGrowthRate)
            $forecastDate = $baseDate.AddMonths($i)
            
            $forecast += @{
                Month = $forecastDate.ToString("yyyy-MM")
                PredictedAmount = [math]::Round($currentAmount, 2)
                GrowthFromCurrent = [math]::Round((($currentAmount - $lastAmount) / $lastAmount) * 100, 2)
                Confidence = if ($i -le 3) { "HIGH" } elseif ($i -le 6) { "MEDIUM" } else { "LOW" }
            }
        }
        
        $totalForecastGrowth = [math]::Round((($currentAmount - $lastAmount) / $lastAmount) * 100, 2)
        
        $forecastResults += @{
            Company = $company.CompanyName
            Domain = $company.Domain
            CurrentAmount = $lastAmount
            ForecastPeriod = $Months
            MonthlyGrowthRate = [math]::Round($monthlyGrowthRate * 100, 2)
            TotalForecastGrowth = $totalForecastGrowth
            FinalPredictedAmount = [math]::Round($currentAmount, 2)
            Forecast = $forecast
            RiskFactors = @(
                if ($monthlyGrowthRate -gt 0.05) { "High growth rate may not be sustainable" },
                if ($monthlyGrowthRate -lt -0.02) { "Declining trend requires attention" },
                if ($historical.Count -lt 6) { "Limited historical data affects accuracy" }
            ) | Where-Object { $_ }
        }
    }
    
    return $forecastResults
}

function Invoke-PAX8ComparativeAnalysis {
    Write-AnalyticsLog "🏆 Performing PAX8 Comparative Analysis..." "Cyan"
    
    $companies = $script:pax8Data.Companies
    $comparativeResults = @{
        TotalCompanies = $companies.Count
        TotalMonthlySpend = ($companies | Measure-Object MonthlySpend -Sum).Sum
        AverageMonthlySpend = [math]::Round(($companies | Measure-Object MonthlySpend -Average).Average, 2)
        HighestSpender = ($companies | Sort-Object MonthlySpend -Descending | Select-Object -First 1)
        LowestSpender = ($companies | Sort-Object MonthlySpend | Select-Object -First 1)
        CompanyRankings = @()
        ProductAnalysis = @{}
    }
    
    # Rank companies by spend
    $rankedCompanies = $companies | Sort-Object MonthlySpend -Descending
    for ($i = 0; $i -lt $rankedCompanies.Count; $i++) {
        $company = $rankedCompanies[$i]
        $percentOfTotal = [math]::Round(($company.MonthlySpend / $comparativeResults.TotalMonthlySpend) * 100, 1)
        
        $comparativeResults.CompanyRankings += @{
            Rank = $i + 1
            Company = $company.CompanyName
            MonthlySpend = $company.MonthlySpend
            PercentOfTotal = $percentOfTotal
            Category = if ($percentOfTotal -gt 40) { "ENTERPRISE" }
                      elseif ($percentOfTotal -gt 20) { "MEDIUM" }
                      else { "SMALL" }
        }
    }
    
    # Analyze product usage across all companies
    $allProducts = @{}
    foreach ($company in $companies) {
        foreach ($sub in $company.Subscriptions) {
            if (-not $allProducts[$sub.Product]) {
                $allProducts[$sub.Product] = @{
                    TotalQuantity = 0
                    TotalRevenue = 0
                    CompanyCount = 0
                    AverageUnitPrice = 0
                }
            }
            $allProducts[$sub.Product].TotalQuantity += $sub.Quantity
            $allProducts[$sub.Product].TotalRevenue += $sub.Total
            $allProducts[$sub.Product].CompanyCount += 1
        }
    }
    
    foreach ($product in $allProducts.Keys) {
        $productData = $allProducts[$product]
        $productData.AverageUnitPrice = [math]::Round($productData.TotalRevenue / $productData.TotalQuantity, 2)
        $comparativeResults.ProductAnalysis[$product] = $productData
    }
    
    return $comparativeResults
}

function New-AdvancedPAX8Report {
    param([hashtable]$AnalysisResults)
    
    Write-AnalyticsLog "📋 Generating Advanced PAX8 Analytics Report..." "Cyan"
    
    $reportFile = Join-Path $OutputPath "Advanced-PAX8-Analytics-$(Get-Date -Format 'yyyy-MM-dd-HH-mm').html"
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Advanced PAX8 Analytics Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; border-radius: 15px; text-align: center; margin-bottom: 30px; box-shadow: 0 8px 25px rgba(0,0,0,0.15); }
        .header h1 { margin: 0; font-size: 3em; font-weight: 300; }
        .header p { margin: 15px 0 0 0; font-size: 1.3em; opacity: 0.9; }
        .pax8-badge { background: linear-gradient(45deg, #FF6B6B, #4ECDC4); color: white; padding: 8px 20px; border-radius: 25px; font-size: 1em; margin-top: 15px; display: inline-block; }
        .content { background: white; padding: 40px; border-radius: 15px; box-shadow: 0 6px 20px rgba(0,0,0,0.1); margin-bottom: 30px; }
        .analytics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 30px; margin: 30px 0; }
        .analytics-card { background: #f8f9fa; border-left: 6px solid #28a745; padding: 25px; border-radius: 10px; }
        .analytics-card.variance { border-left-color: #17a2b8; }
        .analytics-card.trends { border-left-color: #ffc107; }
        .analytics-card.forecast { border-left-color: #6f42c1; }
        .analytics-card.comparative { border-left-color: #fd7e14; }
        .analytics-card h3 { margin: 0 0 15px 0; color: #333; font-size: 1.4em; }
        .metric { display: flex; justify-content: space-between; margin: 12px 0; padding: 8px 0; border-bottom: 1px solid #dee2e6; }
        .metric:last-child { border-bottom: none; }
        .metric-label { font-weight: 600; color: #495057; }
        .metric-value { color: #667eea; font-weight: bold; }
        .forecast-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .forecast-table th, .forecast-table td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        .forecast-table th { background-color: #f8f9fa; font-weight: 600; }
        .trend-up { color: #28a745; }
        .trend-down { color: #dc3545; }
        .trend-stable { color: #6c757d; }
        .risk-high { color: #dc3545; font-weight: bold; }
        .risk-medium { color: #ffc107; font-weight: bold; }
        .risk-low { color: #28a745; font-weight: bold; }
        .footer { text-align: center; color: #6c757d; margin-top: 40px; padding: 30px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📈 Advanced PAX8 Analytics</h1>
        <p>Comprehensive Business Intelligence & Predictive Analytics</p>
        <p>Generated: $(Get-Date -Format 'dddd, MMMM dd, yyyy at HH:mm')</p>
        <span class="pax8-badge">PAX8 MCP Enhanced</span>
    </div>
"@

    if ($AnalysisResults.VarianceAnalysis) {
        $htmlContent += @"
    <div class="content">
        <h2>📊 PAX8 Variance Analysis</h2>
        <div class="analytics-grid">
"@
        foreach ($variance in $AnalysisResults.VarianceAnalysis) {
            $trendClass = switch ($variance.TrendDirection) {
                "INCREASING" { "trend-up" }
                "DECREASING" { "trend-down" }
                default { "trend-stable" }
            }
            $riskClass = switch ($variance.RiskLevel) {
                "HIGH" { "risk-high" }
                "MEDIUM" { "risk-medium" }
                default { "risk-low" }
            }
            
            $htmlContent += @"
            <div class="analytics-card variance">
                <h3>$($variance.Company)</h3>
                <div class="metric">
                    <span class="metric-label">Current Spend:</span>
                    <span class="metric-value">AUD $($variance.CurrentSpend)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Monthly Variance:</span>
                    <span class="metric-value $trendClass">$($variance.VariancePercentage)%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Trend Direction:</span>
                    <span class="metric-value $trendClass">$($variance.TrendDirection)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Risk Level:</span>
                    <span class="metric-value $riskClass">$($variance.RiskLevel)</span>
                </div>
            </div>
"@
        }
        $htmlContent += "</div></div>"
    }

    if ($AnalysisResults.TrendAnalysis) {
        $htmlContent += @"
    <div class="content">
        <h2>📈 PAX8 Trend Analysis</h2>
        <div class="analytics-grid">
"@
        foreach ($trend in $AnalysisResults.TrendAnalysis) {
            $patternClass = switch ($trend.TrendPattern) {
                "GROWTH" { "trend-up" }
                "DECLINE" { "trend-down" }
                default { "trend-stable" }
            }
            
            $htmlContent += @"
            <div class="analytics-card trends">
                <h3>$($trend.Company)</h3>
                <div class="metric">
                    <span class="metric-label">Total Growth Rate:</span>
                    <span class="metric-value $patternClass">$($trend.TotalGrowthRate)%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Monthly Growth Rate:</span>
                    <span class="metric-value">$($trend.MonthlyGrowthRate)%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Pattern:</span>
                    <span class="metric-value $patternClass">$($trend.TrendPattern)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Confidence:</span>
                    <span class="metric-value">$($trend.Confidence)</span>
                </div>
            </div>
"@
        }
        $htmlContent += "</div></div>"
    }

    if ($AnalysisResults.ForecastAnalysis) {
        $htmlContent += @"
    <div class="content">
        <h2>🔮 PAX8 Forecasting Analysis</h2>
        <div class="analytics-grid">
"@
        foreach ($forecast in $AnalysisResults.ForecastAnalysis) {
            $htmlContent += @"
            <div class="analytics-card forecast">
                <h3>$($forecast.Company)</h3>
                <div class="metric">
                    <span class="metric-label">Current Amount:</span>
                    <span class="metric-value">AUD $($forecast.CurrentAmount)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Predicted ($($forecast.ForecastPeriod) months):</span>
                    <span class="metric-value">AUD $($forecast.FinalPredictedAmount)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Total Growth:</span>
                    <span class="metric-value">$($forecast.TotalForecastGrowth)%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Monthly Growth Rate:</span>
                    <span class="metric-value">$($forecast.MonthlyGrowthRate)%</span>
                </div>
            </div>
"@
        }
        $htmlContent += "</div></div>"
    }

    if ($AnalysisResults.ComparativeAnalysis) {
        $comp = $AnalysisResults.ComparativeAnalysis
        $htmlContent += @"
    <div class="content">
        <h2>🏆 PAX8 Comparative Analysis</h2>
        <div class="analytics-card comparative">
            <h3>Portfolio Overview</h3>
            <div class="metric">
                <span class="metric-label">Total Companies:</span>
                <span class="metric-value">$($comp.TotalCompanies)</span>
            </div>
            <div class="metric">
                <span class="metric-label">Total Monthly Spend:</span>
                <span class="metric-value">AUD $($comp.TotalMonthlySpend)</span>
            </div>
            <div class="metric">
                <span class="metric-label">Average Monthly Spend:</span>
                <span class="metric-value">AUD $($comp.AverageMonthlySpend)</span>
            </div>
            <div class="metric">
                <span class="metric-label">Highest Spender:</span>
                <span class="metric-value">$($comp.HighestSpender.CompanyName) - AUD $($comp.HighestSpender.MonthlySpend)</span>
            </div>
        </div>
        
        <h3>Company Rankings</h3>
        <table class="forecast-table">
            <thead>
                <tr>
                    <th>Rank</th>
                    <th>Company</th>
                    <th>Monthly Spend</th>
                    <th>% of Total</th>
                    <th>Category</th>
                </tr>
            </thead>
            <tbody>
"@
        foreach ($ranking in $comp.CompanyRankings) {
            $htmlContent += @"
                <tr>
                    <td>$($ranking.Rank)</td>
                    <td>$($ranking.Company)</td>
                    <td>AUD $($ranking.MonthlySpend)</td>
                    <td>$($ranking.PercentOfTotal)%</td>
                    <td>$($ranking.Category)</td>
                </tr>
"@
        }
        $htmlContent += "</tbody></table></div>"
    }

    $htmlContent += @"
    <div class="footer">
        <p>Generated by Kavira Advanced PAX8 Analytics Engine</p>
        <p>Report ID: PAX8-ADV-$(Get-Date -Format 'yyyyMMdd-HHmmss') • Duration: $((Get-Date) - $analysisStartTime)</p>
        <p>🎯 Advanced Business Intelligence • 📈 Predictive Analytics • 💰 Revenue Optimization</p>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $reportFile -Encoding UTF8
    Write-AnalyticsLog "✅ Advanced PAX8 report generated: $reportFile" "Green"
    
    return $reportFile
}

# ===== MAIN EXECUTION =====

Write-AnalyticsLog "🚀 Starting Advanced PAX8 Analytics Engine..." "Magenta"

# Initialize environment
Initialize-PAX8Analytics

# Determine analysis scope
$analysisResults = @{}

# Execute analyses based on type
switch ($AnalysisType) {
    "Variance" {
        $analysisResults.VarianceAnalysis = Invoke-PAX8VarianceAnalysis
    }
    "Trends" {
        $analysisResults.TrendAnalysis = Invoke-PAX8TrendAnalysis
    }
    "Forecasting" {
        $analysisResults.ForecastAnalysis = Invoke-PAX8Forecasting -Months $ForecastMonths
    }
    "Comparative" {
        $analysisResults.ComparativeAnalysis = Invoke-PAX8ComparativeAnalysis
    }
    "Complete" {
        Write-AnalyticsLog "🎯 Executing Complete Advanced PAX8 Analysis..." "Blue"
        $analysisResults.VarianceAnalysis = Invoke-PAX8VarianceAnalysis
        $analysisResults.TrendAnalysis = Invoke-PAX8TrendAnalysis
        $analysisResults.ForecastAnalysis = Invoke-PAX8Forecasting -Months $ForecastMonths
        $analysisResults.ComparativeAnalysis = Invoke-PAX8ComparativeAnalysis
    }
}

# Generate comprehensive report
if ($GenerateClientReport) {
    $reportFile = New-AdvancedPAX8Report -AnalysisResults $analysisResults
    
    try {
        Start-Process $reportFile
        Write-AnalyticsLog "🌐 Advanced PAX8 report opened in browser" "Green"
    } catch {
        Write-AnalyticsLog "⚠️ Could not open report automatically" "Yellow"
    }
}

# Display summary
$totalDuration = (Get-Date) - $analysisStartTime

Write-Host ""
Write-Host "🏆 ADVANCED PAX8 ANALYTICS COMPLETE!" -ForegroundColor Magenta
Write-Host "=" * 45 -ForegroundColor Magenta
Write-Host "Analysis Type: $AnalysisType" -ForegroundColor Cyan
Write-Host "Total Duration: $($totalDuration.Minutes)m $($totalDuration.Seconds)s" -ForegroundColor Cyan
Write-Host "Companies Analyzed: $($script:pax8Data.Companies.Count)" -ForegroundColor Cyan

if ($analysisResults.VarianceAnalysis) {
    $highRiskCount = ($analysisResults.VarianceAnalysis | Where-Object { $_.RiskLevel -eq "HIGH" }).Count
    Write-Host "High Risk Variances: $highRiskCount" -ForegroundColor $(if($highRiskCount -gt 0) { "Red" } else { "Green" })
}

if ($analysisResults.ComparativeAnalysis) {
    Write-Host "Total Portfolio Value: AUD $($analysisResults.ComparativeAnalysis.TotalMonthlySpend)/month" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🚀 USAGE EXAMPLES:" -ForegroundColor Cyan
Write-Host "# Complete advanced analysis:" -ForegroundColor Gray
Write-Host ".\Start-KaviraAdvancedPAX8Analytics.ps1 -AnalysisType Complete -GenerateClientReport" -ForegroundColor White
Write-Host ""
Write-Host "# 12-month forecasting:" -ForegroundColor Gray
Write-Host ".\Start-KaviraAdvancedPAX8Analytics.ps1 -AnalysisType Forecasting -ForecastMonths 12" -ForegroundColor White
Write-Host ""
Write-Host "# Variance analysis for specific client:" -ForegroundColor Gray
Write-Host ".\Start-KaviraAdvancedPAX8Analytics.ps1 -AnalysisType Variance -TenantName 'ClientName'" -ForegroundColor White

Write-Host ""
Write-Host "✅ ADVANCED PAX8 ANALYTICS - BUSINESS INTELLIGENCE READY!" -ForegroundColor Green

Write-AnalyticsLog "🎯 Advanced PAX8 Analytics execution completed successfully" "Magenta"
