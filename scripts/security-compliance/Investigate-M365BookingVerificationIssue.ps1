#Requires -Modules Microsoft.Graph, ExchangeOnlineManagement

<#
.SYNOPSIS
    Investigates Microsoft 365 meeting booking verification code delivery issues for Pinnacle Road

.DESCRIPTION
    This script diagnoses issues with verification code delivery for Microsoft 365 booking services.
    It checks Exchange mail flow, Bookings configuration, security settings, and external email delivery.

.PARAMETER TenantName
    Target tenant name (default: Pinnacle Road)

.PARAMETER UserEmail
    Specific user email to investigate (e.g., svarc1464@gmail.com)

.PARAMETER TestVerificationFlow
    Test the complete verification flow if enabled

.EXAMPLE
    .\Investigate-M365BookingVerificationIssue.ps1 -TenantName "Pinnacle Road" -UserEmail "svarc1464@gmail.com" -TestVerificationFlow

.NOTES
    Created by: Kavira Technology
    Created for: Pinnacle Road verification code delivery issue
    Version: 1.0
    Date: 2025-07-18
#>

param(
    [string]$TenantName = "Pinnacle Road",
    [string]$UserEmail = "svarc1464@gmail.com",
    [switch]$TestVerificationFlow,
    [string]$OutputPath = "C:\MSP\Reports\"
)

# Import required modules
Import-Module "$PSScriptRoot\KaviraMSP-Connect.psm1" -Force
Import-Module "$PSScriptRoot\KaviraMSP-Utils.psm1" -Force

function Write-KaviraLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} default {"White"} })
    Add-Content -Path "$OutputPath\M365BookingDiagnostic_$(Get-Date -Format 'yyyyMMdd').log" -Value $logEntry
}

function Get-M365BookingsConfiguration {
    param($TenantInfo)
    
    Write-KaviraLog "Checking Microsoft Bookings configuration..." "INFO"
    
    try {
        # Connect to tenant
        Connect-KaviraGraph -TenantInfo $TenantInfo
        
        # Get Bookings apps
        $bookingsApps = Get-MgApplication -Filter "displayName eq 'Microsoft Bookings'" -ErrorAction SilentlyContinue
        
        # Get Exchange Online Bookings settings
        $exoBookingsPolicy = Get-BookingMailbox -ErrorAction SilentlyContinue
        
        # Get organization config for Bookings
        $orgConfig = Get-OrganizationConfig | Select-Object BookingsEnabled, BookingsPaymentsEnabled
        
        return @{
            BookingsApps = $bookingsApps
            BookingsMailboxes = $exoBookingsPolicy
            OrganizationConfig = $orgConfig
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error checking Bookings configuration: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Test-ExchangeMailFlow {
    param($TenantInfo, $UserEmail)
    
    Write-KaviraLog "Testing Exchange Online mail flow for verification emails..." "INFO"
    
    try {
        # Connect to Exchange Online
        Connect-ExchangeOnline -CertificateThumbprint $TenantInfo.CertThumb -AppId $TenantInfo.AppId -Organization $TenantInfo.Domain -ShowBanner:$false
        
        # Check mail flow rules that might block verification emails
        $mailRules = Get-TransportRule | Where-Object { 
            $_.State -eq "Enabled" -and 
            ($_.SenderAddressLocation -contains "Header" -or $_.BlockedSenderDomains -contains "*")
        }
        
        # Check spam filter policies
        $spamPolicies = Get-HostedContentFilterPolicy
        
        # Check outbound spam policy
        $outboundSpamPolicy = Get-HostedOutboundSpamFilterPolicy
        
        # Check message trace for recent verification emails
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-7)
        
        $messageTrace = Get-MessageTrace -RecipientAddress $UserEmail -StartDate $startDate -EndDate $endDate |
                       Where-Object { $_.Subject -like "*verification*" -or $_.Subject -like "*code*" -or $_.SenderAddress -like "*noreply*" }
        
        # Check connector settings
        $connectors = Get-OutboundConnector | Where-Object { $_.Enabled -eq $true }
        
        return @{
            MailRules = $mailRules
            SpamPolicies = $spamPolicies
            OutboundSpamPolicy = $outboundSpamPolicy
            RecentVerificationEmails = $messageTrace
            Connectors = $connectors
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error testing Exchange mail flow: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Test-SecuritySettings {
    param($TenantInfo)
    
    Write-KaviraLog "Checking security settings that might affect verification email delivery..." "INFO"
    
    try {
        # Check conditional access policies
        $caPolicies = Get-MgIdentityConditionalAccessPolicy | Where-Object { $_.State -eq "enabled" }
        
        # Check MFA settings
        $mfaSettings = Get-MgPolicyAuthenticationMethodPolicy
        
        # Check tenant security defaults
        $securityDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
        
        # Check Safe Attachments and Safe Links policies
        $safeAttachmentPolicies = Get-SafeAttachmentPolicy -ErrorAction SilentlyContinue
        $safeLinksPolicies = Get-SafeLinksPolicy -ErrorAction SilentlyContinue
        
        return @{
            ConditionalAccessPolicies = $caPolicies
            MFASettings = $mfaSettings
            SecurityDefaults = $securityDefaults
            SafeAttachmentPolicies = $safeAttachmentPolicies
            SafeLinksPolicies = $safeLinksPolicies
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error checking security settings: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Test-ExternalEmailDelivery {
    param($UserEmail)
    
    Write-KaviraLog "Testing external email delivery to $UserEmail..." "INFO"
    
    try {
        # Check if email domain has SPF, DKIM, DMARC records
        $userDomain = ($UserEmail -split "@")[1]
        
        # Test DNS resolution
        $mxRecords = Resolve-DnsName -Name $userDomain -Type MX -ErrorAction SilentlyContinue
        $spfRecord = Resolve-DnsName -Name $userDomain -Type TXT -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Strings -like "*v=spf1*" }
        $dmarcRecord = Resolve-DnsName -Name "_dmarc.$userDomain" -Type TXT -ErrorAction SilentlyContinue
        
        # Check recent message trace to external domain
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-3)
        
        $externalMessages = Get-MessageTrace -RecipientAddress $UserEmail -StartDate $startDate -EndDate $endDate
        
        return @{
            UserDomain = $userDomain
            MXRecords = $mxRecords
            SPFRecord = $spfRecord
            DMARCRecord = $dmarcRecord
            RecentExternalMessages = $externalMessages
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error testing external email delivery: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Test-BookingPageConfiguration {
    param($TenantInfo)
    
    Write-KaviraLog "Checking booking page configuration and settings..." "INFO"
    
    try {
        # Get all booking mailboxes/calendars
        $bookingMailboxes = Get-BookingMailbox -ErrorAction SilentlyContinue
        
        $bookingDetails = @()
        foreach ($booking in $bookingMailboxes) {
            $details = Get-BookingMailbox -Identity $booking.Identity -ErrorAction SilentlyContinue
            $bookingDetails += $details
        }
        
        # Check if there are any custom booking applications
        $customBookingApps = Get-MgApplication -Filter "displayName like '%booking%' or displayName like '%schedule%'" -ErrorAction SilentlyContinue
        
        return @{
            BookingMailboxes = $bookingMailboxes
            BookingDetails = $bookingDetails
            CustomBookingApps = $customBookingApps
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error checking booking page configuration: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Generate-DiagnosticReport {
    param($Results, $TenantInfo, $UserEmail)
    
    $reportPath = "$OutputPath\M365BookingDiagnostic_$($TenantInfo.Name.Replace(' ',''))_$(Get-Date -Format 'yyyyMMdd_HHmm').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Microsoft 365 Booking Verification Issue - Diagnostic Report</title>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #0078d4, #106ebe); color: white; padding: 20px; margin: -30px -30px 30px -30px; border-radius: 8px 8px 0 0; }
        .logo { font-size: 24px; font-weight: 600; margin-bottom: 5px; }
        .subtitle { font-size: 14px; opacity: 0.9; }
        .section { margin: 30px 0; }
        .section-title { font-size: 20px; font-weight: 600; color: #323130; margin-bottom: 15px; border-bottom: 2px solid #0078d4; padding-bottom: 5px; }
        .issue-summary { background: #fff3cd; border: 1px solid #ffeaa7; padding: 20px; border-radius: 6px; margin: 20px 0; }
        .recommendation { background: #d1ecf1; border: 1px solid #bee5eb; padding: 20px; border-radius: 6px; margin: 20px 0; }
        .success { color: #107c10; font-weight: 600; }
        .warning { color: #ff8c00; font-weight: 600; }
        .error { color: #d13438; font-weight: 600; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .info-card { background: #f8f9fa; border: 1px solid #e9ecef; padding: 15px; border-radius: 6px; }
        .info-label { font-weight: 600; color: #323130; }
        .info-value { margin-top: 5px; color: #605e5c; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e1dfdd; }
        th { background: #f8f9fa; font-weight: 600; color: #323130; }
        .status-ok { color: #107c10; }
        .status-warn { color: #ff8c00; }
        .status-error { color: #d13438; }
        .code-block { background: #f6f8fa; border: 1px solid #e1e4e8; padding: 15px; border-radius: 6px; font-family: monospace; font-size: 14px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🔍 Microsoft 365 Booking Diagnostic Report</div>
            <div class="subtitle">Verification Code Delivery Investigation - $(Get-Date -Format 'dd MMMM yyyy HH:mm')</div>
        </div>

        <div class="issue-summary">
            <h3>📋 Issue Summary</h3>
            <p><strong>Client:</strong> $($TenantInfo.Name)</p>
            <p><strong>Domain:</strong> $($TenantInfo.Domain)</p>
            <p><strong>Affected User:</strong> $UserEmail</p>
            <p><strong>Issue:</strong> Verification codes for meeting booking are not being delivered to external email addresses</p>
            <p><strong>Impact:</strong> External users cannot complete meeting bookings due to missing verification codes</p>
        </div>

        <div class="section">
            <div class="section-title">🏢 Tenant Information</div>
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Tenant Name</div>
                    <div class="info-value">$($TenantInfo.Name)</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Domain</div>
                    <div class="info-value">$($TenantInfo.Domain)</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Tenant ID</div>
                    <div class="info-value">$($TenantInfo.TenantId)</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Admin UPN</div>
                    <div class="info-value">$($TenantInfo.AdminUPN)</div>
                </div>
            </div>
        </div>
"@

    # Add Bookings Configuration section
    if ($Results.BookingsConfig.Status -eq "SUCCESS") {
        $html += @"
        <div class="section">
            <div class="section-title">📅 Microsoft Bookings Configuration</div>
            <table>
                <tr><th>Setting</th><th>Value</th><th>Status</th></tr>
                <tr><td>Bookings Enabled (Organization)</td><td>$($Results.BookingsConfig.OrganizationConfig.BookingsEnabled)</td><td class="$(if($Results.BookingsConfig.OrganizationConfig.BookingsEnabled) {'status-ok'} else {'status-error'})">$(if($Results.BookingsConfig.OrganizationConfig.BookingsEnabled) {'✅ Enabled'} else {'❌ Disabled'})</td></tr>
                <tr><td>Bookings Payments Enabled</td><td>$($Results.BookingsConfig.OrganizationConfig.BookingsPaymentsEnabled)</td><td class="status-ok">ℹ️ Info</td></tr>
                <tr><td>Bookings Mailboxes Count</td><td>$($Results.BookingsConfig.BookingMailboxes.Count)</td><td class="status-ok">ℹ️ Info</td></tr>
            </table>
        </div>
"@
    }

    # Add Mail Flow section
    if ($Results.MailFlow.Status -eq "SUCCESS") {
        $html += @"
        <div class="section">
            <div class="section-title">📧 Exchange Online Mail Flow Analysis</div>
            <table>
                <tr><th>Component</th><th>Count/Status</th><th>Issues Found</th></tr>
                <tr><td>Transport Rules (Enabled)</td><td>$($Results.MailFlow.MailRules.Count)</td><td class="$(if($Results.MailFlow.MailRules.Count -gt 5) {'status-warn'} else {'status-ok'})">$(if($Results.MailFlow.MailRules.Count -gt 5) {'⚠️ High count - review for blocking rules'} else {'✅ Normal'})</td></tr>
                <tr><td>Spam Filter Policies</td><td>$($Results.MailFlow.SpamPolicies.Count)</td><td class="status-ok">ℹ️ Check for aggressive filtering</td></tr>
                <tr><td>Recent Verification Emails</td><td>$($Results.MailFlow.RecentVerificationEmails.Count)</td><td class="$(if($Results.MailFlow.RecentVerificationEmails.Count -eq 0) {'status-error'} else {'status-ok'})">$(if($Results.MailFlow.RecentVerificationEmails.Count -eq 0) {'❌ No verification emails found'} else {'✅ Verification emails detected'})</td></tr>
                <tr><td>Outbound Connectors</td><td>$($Results.MailFlow.Connectors.Count)</td><td class="status-ok">ℹ️ Check connector routing</td></tr>
            </table>
        </div>
"@
    }

    # Add Security Settings section
    if ($Results.SecuritySettings.Status -eq "SUCCESS") {
        $html += @"
        <div class="section">
            <div class="section-title">🔒 Security Configuration Analysis</div>
            <table>
                <tr><th>Security Feature</th><th>Status</th><th>Potential Impact</th></tr>
                <tr><td>Conditional Access Policies</td><td>$($Results.SecuritySettings.ConditionalAccessPolicies.Count) enabled</td><td class="$(if($Results.SecuritySettings.ConditionalAccessPolicies.Count -gt 3) {'status-warn'} else {'status-ok'})">$(if($Results.SecuritySettings.ConditionalAccessPolicies.Count -gt 3) {'⚠️ Review for email blocking'} else {'✅ Normal'})</td></tr>
                <tr><td>Security Defaults</td><td>$($Results.SecuritySettings.SecurityDefaults.IsEnabled)</td><td class="status-ok">ℹ️ Standard setting</td></tr>
                <tr><td>Safe Attachments Policies</td><td>$($Results.SecuritySettings.SafeAttachmentPolicies.Count)</td><td class="status-ok">ℹ️ Check for email delays</td></tr>
                <tr><td>Safe Links Policies</td><td>$($Results.SecuritySettings.SafeLinksPolicies.Count)</td><td class="status-ok">ℹ️ Check for link rewriting</td></tr>
            </table>
        </div>
"@
    }

    # Add External Email Delivery section
    if ($Results.ExternalEmail.Status -eq "SUCCESS") {
        $html += @"
        <div class="section">
            <div class="section-title">🌐 External Email Delivery Analysis</div>
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Target Domain</div>
                    <div class="info-value">$($Results.ExternalEmail.UserDomain)</div>
                </div>
                <div class="info-card">
                    <div class="info-label">MX Records</div>
                    <div class="info-value">$(if($Results.ExternalEmail.MXRecords) {'✅ Found'} else {'❌ Missing'})</div>
                </div>
                <div class="info-card">
                    <div class="info-label">SPF Record</div>
                    <div class="info-value">$(if($Results.ExternalEmail.SPFRecord) {'✅ Found'} else {'❌ Missing'})</div>
                </div>
                <div class="info-card">
                    <div class="info-label">DMARC Record</div>
                    <div class="info-value">$(if($Results.ExternalEmail.DMARCRecord) {'✅ Found'} else {'❌ Missing'})</div>
                </div>
            </div>
            <table>
                <tr><th>Recent External Messages</th><th>Count</th><th>Status</th></tr>
                <tr><td>Messages to $UserEmail (Last 3 days)</td><td>$($Results.ExternalEmail.RecentExternalMessages.Count)</td><td class="$(if($Results.ExternalEmail.RecentExternalMessages.Count -eq 0) {'status-warn'} else {'status-ok'})">$(if($Results.ExternalEmail.RecentExternalMessages.Count -eq 0) {'⚠️ No recent emails'} else {'✅ Email delivery working'})</td></tr>
            </table>
        </div>
"@
    }

    # Add Recommendations section
    $html += @"
        <div class="section">
            <div class="section-title">💡 Recommendations & Next Steps</div>
            <div class="recommendation">
                <h4>🔍 Investigation Actions Required:</h4>
                <ol>
                    <li><strong>Check Bookings Application:</strong> Verify if a custom booking application is being used vs. native Microsoft Bookings</li>
                    <li><strong>Review Mail Flow Rules:</strong> Check for transport rules that might block verification emails from no-reply addresses</li>
                    <li><strong>Test Email Delivery:</strong> Send a test verification email to $UserEmail manually</li>
                    <li><strong>Check Spam Filtering:</strong> Review spam filter policies for overly aggressive filtering</li>
                    <li><strong>Verify Application Settings:</strong> If using a third-party booking system, check SMTP settings and authentication</li>
                </ol>
            </div>
            
            <div class="recommendation">
                <h4>🛠️ Potential Solutions:</h4>
                <ol>
                    <li><strong>Whitelist Verification Emails:</strong> Add sender domains to allowed list in spam filtering</li>
                    <li><strong>Adjust Transport Rules:</strong> Modify mail flow rules to allow verification emails</li>
                    <li><strong>Configure External Sharing:</strong> Ensure external sharing settings allow booking confirmations</li>
                    <li><strong>Test Alternative Delivery:</strong> Consider SMS verification as backup option</li>
                    <li><strong>Update Booking Configuration:</strong> Review and update booking page settings</li>
                </ol>
            </div>
        </div>

        <div class="section">
            <div class="section-title">📞 Support Contact</div>
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">MSP Support</div>
                    <div class="info-value">Kavira Technology</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Ticket Priority</div>
                    <div class="info-value">High - Business Impact</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Next Review</div>
                    <div class="info-value">$(Get-Date (Get-Date).AddHours(24) -Format 'dd MMM yyyy HH:mm')</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Report Generated</div>
                    <div class="info-value">$(Get-Date -Format 'dd MMM yyyy HH:mm')</div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
"@

    Set-Content -Path $reportPath -Value $html -Encoding UTF8
    Write-KaviraLog "Diagnostic report generated: $reportPath" "SUCCESS"
    return $reportPath
}

# Main execution
try {
    Write-KaviraLog "Starting Microsoft 365 Booking verification code diagnostic..." "INFO"
    
    # Load tenant configuration
    $tenantConfig = Get-Content "C:\MSP\Config\tenants.json" | ConvertFrom-Json
    $targetTenant = $tenantConfig | Where-Object { $_.Name -eq $TenantName }
    
    if (-not $targetTenant) {
        throw "Tenant '$TenantName' not found in configuration"
    }
    
    Write-KaviraLog "Target tenant: $($targetTenant.Name) ($($targetTenant.Domain))" "INFO"
    Write-KaviraLog "Investigating verification code issue for user: $UserEmail" "INFO"
    
    # Initialize results object
    $results = @{}
    
    # Run diagnostics
    Write-KaviraLog "Running comprehensive diagnostics..." "INFO"
    
    $results.BookingsConfig = Get-M365BookingsConfiguration -TenantInfo $targetTenant
    $results.MailFlow = Test-ExchangeMailFlow -TenantInfo $targetTenant -UserEmail $UserEmail
    $results.SecuritySettings = Test-SecuritySettings -TenantInfo $targetTenant
    $results.ExternalEmail = Test-ExternalEmailDelivery -UserEmail $UserEmail
    $results.BookingPages = Test-BookingPageConfiguration -TenantInfo $targetTenant
    
    # Generate comprehensive report
    $reportPath = Generate-DiagnosticReport -Results $results -TenantInfo $targetTenant -UserEmail $UserEmail
    
    Write-KaviraLog "Diagnostic completed successfully!" "SUCCESS"
    Write-KaviraLog "Report available at: $reportPath" "SUCCESS"
    
    # Open report automatically
    Start-Process $reportPath
    
    # Update memory bank with the issue
    $memoryUpdate = @"

## Microsoft 365 Booking Verification Issue - $(Get-Date -Format 'yyyy-MM-dd')

**Client:** Pinnacle Road
**Issue:** Verification codes not being delivered for meeting bookings
**Affected User:** svarc1464@gmail.com
**Diagnostic Script:** Investigate-M365BookingVerificationIssue.ps1
**Report Generated:** $reportPath

**Key Areas Investigated:**
- Microsoft Bookings configuration
- Exchange Online mail flow
- Security settings (CA policies, Safe Attachments/Links)
- External email delivery (DNS, SPF, DMARC)
- Booking page configuration

**Status:** Investigation complete, awaiting remediation based on findings.

"@
    
    Add-Content -Path "C:\MSP\memory-bank\CLAUDE-STARTUP-INSTRUCTIONS.md" -Value $memoryUpdate
    
}
catch {
    Write-KaviraLog "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    Write-KaviraLog "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    throw
}
finally {
    # Disconnect sessions
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore cleanup errors
    }
}
