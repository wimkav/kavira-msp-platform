#Requires -Modules Microsoft.Graph

<#
.SYNOPSIS
    Easy deployment wrapper for Smart User Creation with PAX8 auto-procurement

.DESCRIPTION
    Simplified interface for the Smart User Creation workflow.
    Handles Business Premium license auto-procurement and Intune setup.

.EXAMPLE
    .\Deploy-BusinessUser.ps1 -TenantName "Pathfindr AI" -Name "John Smith" -Account "john.smith" -Mobile "0400123456" -FullTime

.EXAMPLE
    .\Deploy-BusinessUser.ps1 -TenantName "Pinnacle Road" -Name "Jane Doe" -Account "jane.doe" -PartTime
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TenantName,
    
    [Parameter(Mandatory)]
    [string]$Name,
    
    [Parameter(Mandatory)]
    [string]$Account,
    
    [string]$Mobile = "",
    [string]$Department = "Operations",
    [string]$JobTitle = "Employee",
    
    [switch]$FullTime,   # Full-time = Business Premium + Intune
    [switch]$PartTime    # Part-time = Business Premium but no Intune
)

function Write-DeployLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch($Level) { 
        "ERROR" {"Red"} 
        "WARN" {"Yellow"} 
        "SUCCESS" {"Green"} 
        default {"Cyan"} 
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

try {
    Write-DeployLog "🚀 DEPLOYING BUSINESS USER WITH PAX8 AUTO-PROCUREMENT" "SUCCESS"
    Write-DeployLog "" "INFO"
    
    # Validate employment type
    if (-not $FullTime -and -not $PartTime) {
        Write-DeployLog "⚠️  Employment type not specified. Defaulting to Full-Time (includes Intune)" "WARN"
        $FullTime = $true
    }
    
    $employmentType = if ($FullTime) { "Full-Time" } else { "Part-Time" }
    
    # Display configuration
    Write-DeployLog "📋 DEPLOYMENT CONFIGURATION:" "INFO"
    Write-DeployLog "   Tenant: $TenantName" "INFO"
    Write-DeployLog "   User: $Name ($Account)" "INFO"
    Write-DeployLog "   Mobile: $(if($Mobile) {$Mobile} else {'Not provided'})" "INFO"
    Write-DeployLog "   Department: $Department" "INFO"
    Write-DeployLog "   Employment: $employmentType" "INFO"
    Write-DeployLog "   License: Business Premium (auto-procured if needed)" "INFO"
    Write-DeployLog "   Intune: $(if($FullTime) {'✅ Enabled'} else {'❌ Disabled'})" "INFO"
    Write-DeployLog "" "INFO"
    
    # Confirmation
    $confirm = Read-Host "Continue with user deployment? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-DeployLog "❌ Deployment cancelled by user" "WARN"
        return
    }
    
    Write-DeployLog "🎯 Starting Smart User Creation..." "SUCCESS"
    
    # Build parameters for smart creation script
    $smartParams = @{
        TenantName = $TenantName
        DisplayName = $Name
        AccountName = $Account
        Department = $Department
        JobTitle = $JobTitle
        BusinessPremium = $true  # Always use Business Premium
    }
    
    if ($Mobile) {
        $smartParams.MobilePhone = $Mobile
    }
    
    if ($FullTime) {
        $smartParams.FullTimeEmployee = $true
    } else {
        $smartParams.PartTimeEmployee = $true
    }
    
    # Execute smart user creation
    $scriptPath = "$PSScriptRoot\Smart-UserCreation-PAX8.ps1"
    
    if (Test-Path $scriptPath) {
        & $scriptPath @smartParams
        Write-DeployLog "✅ Smart User Creation completed successfully!" "SUCCESS"
    } else {
        throw "Smart-UserCreation-PAX8.ps1 not found at $scriptPath"
    }
    
    Write-DeployLog "" "INFO"
    Write-DeployLog "🎉 USER DEPLOYMENT COMPLETED!" "SUCCESS"
    Write-DeployLog "" "INFO"
    Write-DeployLog "📋 WHAT HAPPENED:" "INFO"
    Write-DeployLog "   ✅ User account created" "INFO"
    Write-DeployLog "   ✅ Business Premium license assigned (auto-procured if needed)" "INFO"
    Write-DeployLog "   ✅ Standard groups configured" "INFO"
    Write-DeployLog "   $(if($FullTime) {'✅ Intune device management enabled'} else {'❌ Intune management disabled (part-time)'})" "INFO"
    Write-DeployLog "" "INFO"
    Write-DeployLog "📞 NEXT STEPS:" "INFO"
    Write-DeployLog "   1. Send credentials to client" "INFO"
    Write-DeployLog "   2. $(if($FullTime) {'Arrange device procurement if needed'} else {'User ready for BYOD/Cloud PC'})" "INFO"
    Write-DeployLog "   3. User can start on designated date" "INFO"
    
}
catch {
    Write-DeployLog "❌ DEPLOYMENT FAILED: $($_.Exception.Message)" "ERROR"
    Write-DeployLog "Check the detailed log for more information" "ERROR"
}

Write-DeployLog "" "INFO"
Write-DeployLog "📊 For detailed logs, check: C:\MSP\Reports\SmartUserCreation_*.log" "INFO"
