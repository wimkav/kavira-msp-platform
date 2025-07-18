# KAVIRA EXECUTIVE DASHBOARD GENERATOR
# Professional client-facing reports with multi-tenant data aggregation
# Built by Claude for Kavira MSP

param(
    [string]$TenantName = "All",
    [string]$OutputPath = "C:\MSP\Reports\Executive",
    [switch]$OpenInBrowser,
    [string]$ClientName = "",
    [string]$ReportPeriod = "Monthly"
)

# Import required modules
Import-Module "C:\MSP\Scripts\KaviraMSP-Connect.psm1" -Force
Import-Module "C:\MSP\Scripts\KaviraMSP-HealthCheck.psm1" -Force
Import-Module "C:\MSP\Scripts\KaviraMSP-Users.psm1" -Force
Import-Module "C:\MSP\Scripts\KaviraMSP-Devices.psm1" -Force

Write-Host "🎯 KAVIRA EXECUTIVE DASHBOARD GENERATOR" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Building professional client report..." -ForegroundColor Gray

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Load tenant configuration
$configPath = "C:\MSP\Config\tenants.json"
if (-not (Test-Path $configPath)) {
    Write-Host "❌ Tenant configuration not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$tenants = if ($TenantName -eq "All") { $config } else { $config | Where-Object { $_.Name -like "*$TenantName*" -or $_.Domain -like "*$TenantName*" } }

Write-Host "📊 Analyzing $($tenants.Count) tenant(s)..." -ForegroundColor Yellow

# Initialize report data
$reportData = @{
    GeneratedDate = Get-Date
    ReportPeriod = $ReportPeriod
    ClientName = if ($ClientName) { $ClientName } else { "Kavira MSP Client" }
    Tenants = @()
    Summary = @{
        TotalUsers = 0
        ActiveUsers = 0
        TotalDevices = 0
        CompliantDevices = 0
        SecurityScore = 0
        LicenseUtilization = 0
    }
}

# Collect data from each tenant
foreach ($tenant in $tenants) {
    Write-Host "   🔍 Processing: $($tenant.Domain)" -ForegroundColor Blue
    
    try {
        # Connect to tenant - Direct Graph connection
        try {
            Connect-MgGraph -ClientId "16979a25-45b3-4be5-a1f4-821735ab7f8c" -TenantId $tenant.TenantId -CertificateThumbprint "024A4100F81EC25203998B5831A0751971611DA9" -NoWelcome
            # Get user statistics
            $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,SignInActivity
            $activeUsers = $users | Where-Object { $_.AccountEnabled -eq $true }
            $recentSignIns = $users | Where-Object { 
                $_.SignInActivity.LastSignInDateTime -gt (Get-Date).AddDays(-30) 
            }
            
            # Get device statistics
            $devices = Get-MgDevice -All
            $compliantDevices = $devices | Where-Object { $_.AccountEnabled -eq $true }
            
            # Get license information
            $licenses = Get-MgSubscribedSku
            $totalLicenses = ($licenses | Measure-Object -Property ConsumedUnits -Sum).Sum
            $availableLicenses = ($licenses | ForEach-Object { $_.PrepaidUnits.Enabled } | Measure-Object -Sum).Sum
            
            # Calculate health scores
            $userHealthScore = if ($users.Count -gt 0) { 
                [math]::Round(($activeUsers.Count / $users.Count) * 100, 1)
            } else { 0 }
            
            $deviceHealthScore = if ($devices.Count -gt 0) {
                [math]::Round(($compliantDevices.Count / $devices.Count) * 100, 1)
            } else { 100 }
            
            $licenseUtilization = if ($availableLicenses -gt 0) {
                [math]::Round(($totalLicenses / $availableLicenses) * 100, 1)
            } else { 0 }
            
            # Store tenant data
            $tenantData = @{
                Domain = $tenant.Domain
                DisplayName = $tenant.DisplayName
                Users = @{
                    Total = $users.Count
                    Active = $activeUsers.Count
                    RecentSignIns = $recentSignIns.Count
                    HealthScore = $userHealthScore
                }
                Devices = @{
                    Total = $devices.Count
                    Compliant = $compliantDevices.Count
                    HealthScore = $deviceHealthScore
                }
                Licenses = @{
                    Total = $availableLicenses
                    Consumed = $totalLicenses
                    Utilization = $licenseUtilization
                }
                SecurityScore = [math]::Round(($userHealthScore + $deviceHealthScore) / 2, 1)
            }
            
            $reportData.Tenants += $tenantData
            
            # Update summary
            $reportData.Summary.TotalUsers += $users.Count
            $reportData.Summary.ActiveUsers += $activeUsers.Count
            $reportData.Summary.TotalDevices += $devices.Count
            $reportData.Summary.CompliantDevices += $compliantDevices.Count
            
            Write-Host "     ✅ Users: $($users.Count) | Devices: $($devices.Count) | Health: $($tenantData.SecurityScore)%" -ForegroundColor Green
        } catch {
            Write-Host "     ❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "     ❌ Error processing $($tenant.Domain): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Calculate overall summary scores
if ($reportData.Tenants.Count -gt 0) {
    $reportData.Summary.SecurityScore = [math]::Round(
        ($reportData.Tenants | Measure-Object -Property SecurityScore -Average).Average, 1
    )
    
    $reportData.Summary.LicenseUtilization = if ($reportData.Summary.TotalUsers -gt 0) {
        [math]::Round(($reportData.Summary.TotalUsers / 
        ($reportData.Tenants | ForEach-Object { $_.Licenses.Total } | Measure-Object -Sum).Sum) * 100, 1)
    } else { 0 }
}

Write-Host "`n📄 GENERATING EXECUTIVE REPORT..." -ForegroundColor Yellow

# Generate professional HTML report
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$reportPath = "$OutputPath\Executive-Dashboard-$timestamp.html"

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$($reportData.ClientName) - Executive Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        
        .header {
            background: white;
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 30px;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 { color: #2c3e50; font-size: 2.5em; margin-bottom: 10px; }
        .header .subtitle { color: #7f8c8d; font-size: 1.2em; }
        .report-info { color: #95a5a6; margin-top: 15px; }
        
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .metric-card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        .metric-card:hover { transform: translateY(-5px); }
        
        .metric-value {
            font-size: 3em;
            font-weight: bold;
            margin: 15px 0;
            color: #2c3e50;
        }
        .metric-label {
            color: #7f8c8d;
            font-size: 1.1em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .metric-change {
            margin-top: 10px;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
        }
        .positive { background: #d4edda; color: #155724; }
        .neutral { background: #e2e3e5; color: #6c757d; }
        
        .score-good { color: #27ae60; }
        .score-warning { color: #f39c12; }
        .score-critical { color: #e74c3c; }
        
        .section {
            background: white;
            margin-bottom: 30px;
            border-radius: 15px;
            overflow: hidden;
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
        }
        .section-header {
            background: #34495e;
            color: white;
            padding: 20px 30px;
            font-size: 1.3em;
            font-weight: bold;
        }
        .section-content { padding: 30px; }
        
        .tenant-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }
        
        .tenant-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            border-left: 5px solid #3498db;
        }
        .tenant-name {
            font-size: 1.3em;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 15px;
        }
        .tenant-stats {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
            margin-top: 15px;
        }
        .tenant-stat {
            text-align: center;
            padding: 10px;
            background: white;
            border-radius: 8px;
        }
        .stat-value {
            font-size: 1.5em;
            font-weight: bold;
            color: #2c3e50;
        }
        .stat-label {
            font-size: 0.9em;
            color: #7f8c8d;
            margin-top: 5px;
        }
        
        .footer {
            background: white;
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            margin-top: 30px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
        }
        .footer-logo {
            font-size: 1.5em;
            font-weight: bold;
            color: #3498db;
            margin-bottom: 10px;
        }
        .footer-text { color: #7f8c8d; }
        
        @media (max-width: 768px) {
            .summary-grid { grid-template-columns: 1fr; }
            .tenant-grid { grid-template-columns: 1fr; }
            .header h1 { font-size: 2em; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$($reportData.ClientName)</h1>
            <div class="subtitle">Executive Technology Dashboard</div>
            <div class="report-info">
                Generated on $($reportData.GeneratedDate.ToString("MMMM dd, yyyy")) at $($reportData.GeneratedDate.ToString("HH:mm")) • 
                Reporting Period: $($reportData.ReportPeriod)
            </div>
        </div>
        
        <div class="summary-grid">
            <div class="metric-card">
                <div class="metric-label">Total Users</div>
                <div class="metric-value">$($reportData.Summary.TotalUsers)</div>
                <div class="metric-change positive">$($reportData.Summary.ActiveUsers) Active</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Managed Devices</div>
                <div class="metric-value">$($reportData.Summary.TotalDevices)</div>
                <div class="metric-change positive">$($reportData.Summary.CompliantDevices) Compliant</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Security Score</div>
                <div class="metric-value $(if($reportData.Summary.SecurityScore -ge 80){'score-good'}elseif($reportData.Summary.SecurityScore -ge 60){'score-warning'}else{'score-critical'})">$($reportData.Summary.SecurityScore)%</div>
                <div class="metric-change neutral">Overall Health</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">License Efficiency</div>
                <div class="metric-value $(if($reportData.Summary.LicenseUtilization -le 90){'score-good'}elseif($reportData.Summary.LicenseUtilization -le 95){'score-warning'}else{'score-critical'})">$($reportData.Summary.LicenseUtilization)%</div>
                <div class="metric-change neutral">Utilization</div>
            </div>
        </div>
        
        <div class="section">
            <div class="section-header">
                📊 Tenant Overview ($($reportData.Tenants.Count) Environments)
            </div>
            <div class="section-content">
                <div class="tenant-grid">
"@

# Add tenant details
foreach ($tenant in $reportData.Tenants) {
    $html += @"
                    <div class="tenant-card">
                        <div class="tenant-name">$($tenant.DisplayName)</div>
                        <div style="color: #7f8c8d; margin-bottom: 10px;">$($tenant.Domain)</div>
                        <div class="tenant-stats">
                            <div class="tenant-stat">
                                <div class="stat-value">$($tenant.Users.Total)</div>
                                <div class="stat-label">Users</div>
                            </div>
                            <div class="tenant-stat">
                                <div class="stat-value">$($tenant.Devices.Total)</div>
                                <div class="stat-label">Devices</div>
                            </div>
                            <div class="tenant-stat">
                                <div class="stat-value $(if($tenant.SecurityScore -ge 80){'score-good'}elseif($tenant.SecurityScore -ge 60){'score-warning'}else{'score-critical'})">$($tenant.SecurityScore)%</div>
                                <div class="stat-label">Health</div>
                            </div>
                        </div>
                    </div>
"@
}

$html += @"
                </div>
            </div>
        </div>
        
        <div class="footer">
            <div class="footer-logo">🚀 Kavira MSP</div>
            <div class="footer-text">Professional Technology Management & Automation</div>
            <div class="footer-text" style="margin-top: 5px;">Report generated by Kavira Executive Dashboard System</div>
        </div>
    </div>
</body>
</html>
"@

# Save report
$html | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n✅ EXECUTIVE DASHBOARD GENERATED!" -ForegroundColor Green
Write-Host "📄 Report saved: $reportPath" -ForegroundColor Cyan
Write-Host "📊 Summary:" -ForegroundColor Yellow
Write-Host "   Users: $($reportData.Summary.TotalUsers) total, $($reportData.Summary.ActiveUsers) active" -ForegroundColor White
Write-Host "   Devices: $($reportData.Summary.TotalDevices) total, $($reportData.Summary.CompliantDevices) compliant" -ForegroundColor White
Write-Host "   Security Score: $($reportData.Summary.SecurityScore)%" -ForegroundColor White
Write-Host "   License Utilization: $($reportData.Summary.LicenseUtilization)%" -ForegroundColor White

if ($OpenInBrowser) {
    Write-Host "`n🌐 Opening dashboard..." -ForegroundColor Yellow
    Start-Process $reportPath
}

Write-Host "`n🎯 EXECUTIVE DASHBOARD COMPLETE!" -ForegroundColor Green
