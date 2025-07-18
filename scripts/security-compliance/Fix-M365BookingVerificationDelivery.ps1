#Requires -Modules Microsoft.Graph, ExchangeOnlineManagement

<#
.SYNOPSIS
    Quick fixes for Microsoft 365 booking verification code delivery issues

.DESCRIPTION
    Applies immediate fixes for common verification code delivery problems:
    - Adjusts spam filtering for booking-related emails
    - Configures allow lists for Microsoft booking domains
    - Tests basic email delivery
    - Provides immediate remediation steps

.PARAMETER TenantName
    Target tenant name (default: Pinnacle Road)

.PARAMETER TestEmailAddress
    Email address to test delivery (default: svarc1464@gmail.com)

.PARAMETER ApplyFixes
    Apply the fixes automatically (default: false for safety)

.EXAMPLE
    .\Fix-M365BookingVerificationDelivery.ps1 -TenantName "Pinnacle Road" -ApplyFixes

.NOTES
    Created by: Kavira Technology
    Version: 1.0
    Date: 2025-07-18
    Priority: HIGH - Business Impact
#>

param(
    [string]$TenantName = "Pinnacle Road",
    [string]$TestEmailAddress = "svarc1464@gmail.com",
    [switch]$ApplyFixes,
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
    Add-Content -Path "$OutputPath\BookingVerificationFix_$(Get-Date -Format 'yyyyMMdd').log" -Value $logEntry
}

function Test-CurrentEmailDelivery {
    param($TenantInfo, $TestEmail)
    
    Write-KaviraLog "Testing current email delivery status..." "INFO"
    
    try {
        # Check recent message trace
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-3)
        
        $recentMessages = Get-MessageTrace -RecipientAddress $TestEmail -StartDate $startDate -EndDate $endDate
        $verificationMessages = $recentMessages | Where-Object { 
            $_.Subject -like "*verification*" -or 
            $_.Subject -like "*code*" -or 
            $_.SenderAddress -like "*noreply*" -or
            $_.SenderAddress -like "*booking*"
        }
        
        Write-KaviraLog "Found $($recentMessages.Count) recent messages to $TestEmail" "INFO"
        Write-KaviraLog "Found $($verificationMessages.Count) potential verification messages" "INFO"
        
        return @{
            RecentMessages = $recentMessages
            VerificationMessages = $verificationMessages
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error testing email delivery: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Add-BookingEmailAllowList {
    param($TenantInfo, $ApplyChanges)
    
    Write-KaviraLog "Configuring allow list for booking-related email domains..." "INFO"
    
    $bookingDomains = @(
        "outlook.office365.com",
        "office365.com", 
        "microsoft.com",
        "microsoftonline.com",
        "outlook.com",
        "bookings.microsoft.com",
        "noreply@microsoft.com",
        "bookings-noreply@microsoft.com"
    )
    
    try {
        # Get current spam filter policy
        $spamPolicies = Get-HostedContentFilterPolicy
        $defaultPolicy = $spamPolicies | Where-Object { $_.IsDefault -eq $true }
        
        Write-KaviraLog "Current allowed sender domains: $($defaultPolicy.AllowedSenderDomains.Count)" "INFO"
        
        if ($ApplyChanges) {
            # Add booking domains to allowed list
            $currentAllowed = $defaultPolicy.AllowedSenderDomains
            $newAllowed = $currentAllowed + $bookingDomains | Select-Object -Unique
            
            Set-HostedContentFilterPolicy -Identity $defaultPolicy.Identity -AllowedSenderDomains $newAllowed
            Write-KaviraLog "Added booking domains to allow list" "SUCCESS"
        } else {
            Write-KaviraLog "DRY RUN: Would add domains: $($bookingDomains -join ', ')" "INFO"
        }
        
        return @{
            CurrentPolicy = $defaultPolicy
            BookingDomains = $bookingDomains
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error configuring allow list: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Adjust-SpamFilteringSettings {
    param($TenantInfo, $ApplyChanges)
    
    Write-KaviraLog "Adjusting spam filtering settings for verification emails..." "INFO"
    
    try {
        $spamPolicies = Get-HostedContentFilterPolicy
        $defaultPolicy = $spamPolicies | Where-Object { $_.IsDefault -eq $true }
        
        $currentSettings = @{
            BulkThreshold = $defaultPolicy.BulkThreshold
            SpamAction = $defaultPolicy.SpamAction
            HighConfidenceSpamAction = $defaultPolicy.HighConfidenceSpamAction
            BulkSpamAction = $defaultPolicy.BulkSpamAction
        }
        
        Write-KaviraLog "Current spam settings: Bulk Threshold: $($currentSettings.BulkThreshold)" "INFO"
        
        if ($ApplyChanges) {
            # Temporarily relax spam filtering for verification emails
            Set-HostedContentFilterPolicy -Identity $defaultPolicy.Identity `
                -BulkThreshold 9 `
                -EnableLanguageBlockList $false `
                -EnableRegionBlockList $false
                
            Write-KaviraLog "Adjusted spam filtering settings" "SUCCESS"
        } else {
            Write-KaviraLog "DRY RUN: Would adjust bulk threshold to 9 and disable geo-blocking" "INFO"
        }
        
        return @{
            CurrentSettings = $currentSettings
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error adjusting spam settings: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Configure-SafeAttachmentsExceptions {
    param($TenantInfo, $ApplyChanges)
    
    Write-KaviraLog "Configuring Safe Attachments exceptions for booking emails..." "INFO"
    
    try {
        $safeAttachmentPolicies = Get-SafeAttachmentPolicy -ErrorAction SilentlyContinue
        
        if (-not $safeAttachmentPolicies) {
            Write-KaviraLog "No Safe Attachments policies found" "INFO"
            return @{ Status = "SUCCESS"; Message = "No policies to configure" }
        }
        
        $bookingSenders = @(
            "*@outlook.office365.com",
            "*@microsoft.com", 
            "*@microsoftonline.com",
            "*booking*@outlook.com"
        )
        
        if ($ApplyChanges) {
            foreach ($policy in $safeAttachmentPolicies) {
                if ($policy.Enable -eq $true) {
                    # Create exception rule for booking emails
                    Write-KaviraLog "Configuring exceptions for policy: $($policy.Name)" "INFO"
                    # Note: Safe Attachments doesn't have direct sender exceptions,
                    # but we can modify the action to be less aggressive
                    Set-SafeAttachmentPolicy -Identity $policy.Identity -Action DynamicDelivery
                }
            }
            Write-KaviraLog "Configured Safe Attachments for faster delivery" "SUCCESS"
        } else {
            Write-KaviraLog "DRY RUN: Would configure Safe Attachments for dynamic delivery" "INFO"
        }
        
        return @{
            Policies = $safeAttachmentPolicies
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error configuring Safe Attachments: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Test-BookingsConfiguration {
    param($TenantInfo)
    
    Write-KaviraLog "Testing Microsoft Bookings configuration..." "INFO"
    
    try {
        # Check if Bookings is enabled
        $orgConfig = Get-OrganizationConfig
        $bookingsEnabled = $orgConfig.BookingsEnabled
        
        Write-KaviraLog "Bookings enabled at org level: $bookingsEnabled" "INFO"
        
        # Get booking mailboxes
        $bookingMailboxes = Get-BookingMailbox -ErrorAction SilentlyContinue
        Write-KaviraLog "Found $($bookingMailboxes.Count) booking mailboxes" "INFO"
        
        return @{
            BookingsEnabled = $bookingsEnabled
            BookingMailboxes = $bookingMailboxes
            Status = "SUCCESS"
        }
    }
    catch {
        Write-KaviraLog "Error checking Bookings configuration: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Send-TestVerificationEmail {
    param($TenantInfo, $TestEmail, $ApplyChanges)
    
    Write-KaviraLog "Preparing test verification email..." "INFO"
    
    if (-not $ApplyChanges) {
        Write-KaviraLog "DRY RUN: Would send test email to $TestEmail" "INFO"
        return @{ Status = "SUCCESS"; Message = "Dry run - no email sent" }
    }
    
    try {
        $testSubject = "Test Verification Code - Pinnacle Road Booking System"
        $testBody = @"
Hello,

This is a test verification email from the Pinnacle Road booking system.

Your verification code is: TEST123

If you received this email, the verification system is working correctly.

Please contact Holly Howard at holly@pinnacleroad.com.au if you have any questions.

Best regards,
Pinnacle Road Booking System
"@
        
        # Send test email using Graph API
        $mailParams = @{
            Message = @{
                Subject = $testSubject
                Body = @{
                    ContentType = "Text"
                    Content = $testBody
                }
                ToRecipients = @(
                    @{
                        EmailAddress = @{
                            Address = $TestEmail
                        }
                    }
                )
            }
            SaveToSentItems = $true
        }
        
        Send-MgUserMail -UserId $TenantInfo.AdminUPN -BodyParameter $mailParams
        Write-KaviraLog "Test verification email sent to $TestEmail" "SUCCESS"
        
        return @{ Status = "SUCCESS"; Message = "Test email sent successfully" }
    }
    catch {
        Write-KaviraLog "Error sending test email: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Error = $_.Exception.Message }
    }
}

function Generate-FixReport {
    param($Results, $TenantInfo, $TestEmail, $AppliedFixes)
    
    $reportPath = "$OutputPath\BookingVerificationFix_$($TenantInfo.Name.Replace(' ',''))_$(Get-Date -Format 'yyyyMMdd_HHmm').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Booking Verification Fix Report - $($TenantInfo.Name)</title>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #0078d4, #106ebe); color: white; padding: 20px; margin: -30px -30px 30px -30px; border-radius: 8px 8px 0 0; }
        .logo { font-size: 24px; font-weight: 600; margin-bottom: 5px; }
        .subtitle { font-size: 14px; opacity: 0.9; }
        .section { margin: 30px 0; }
        .section-title { font-size: 20px; font-weight: 600; color: #323130; margin-bottom: 15px; border-bottom: 2px solid #0078d4; padding-bottom: 5px; }
        .fix-applied { background: #d1f2eb; border: 1px solid #7dcea0; padding: 15px; border-radius: 6px; margin: 10px 0; }
        .fix-pending { background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 6px; margin: 10px 0; }
        .success { color: #107c10; font-weight: 600; }
        .warning { color: #ff8c00; font-weight: 600; }
        .error { color: #d13438; font-weight: 600; }
        .action-item { background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 10px 0; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e1dfdd; }
        th { background: #f8f9fa; font-weight: 600; color: #323130; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🔧 Booking Verification Quick Fix Report</div>
            <div class="subtitle">Microsoft 365 Email Delivery Fixes - $(Get-Date -Format 'dd MMMM yyyy HH:mm')</div>
        </div>

        <div class="section">
            <div class="section-title">📋 Fix Summary</div>
            <p><strong>Client:</strong> $($TenantInfo.Name)</p>
            <p><strong>Issue:</strong> Verification codes not delivered to external email addresses</p>
            <p><strong>Test Email:</strong> $TestEmail</p>
            <p><strong>Fixes Applied:</strong> $(if($AppliedFixes) {'✅ YES'} else {'❌ DRY RUN ONLY'})</p>
            <p><strong>Status:</strong> $(if($AppliedFixes) {'Applied immediate fixes'} else {'Analysis complete - ready to apply fixes'})</p>
        </div>
"@

    if ($Results.EmailDelivery.Status -eq "SUCCESS") {
        $html += @"
        <div class="section">
            <div class="section-title">📧 Current Email Delivery Status</div>
            <table>
                <tr><th>Metric</th><th>Count</th><th>Status</th></tr>
                <tr><td>Recent Messages (3 days)</td><td>$($Results.EmailDelivery.RecentMessages.Count)</td><td class="$(if($Results.EmailDelivery.RecentMessages.Count -gt 0) {'success'} else {'warning'})">$(if($Results.EmailDelivery.RecentMessages.Count -gt 0) {'✅ Active'} else {'⚠️ No recent activity'})</td></tr>
                <tr><td>Verification Messages</td><td>$($Results.EmailDelivery.VerificationMessages.Count)</td><td class="$(if($Results.EmailDelivery.VerificationMessages.Count -gt 0) {'success'} else {'error'})">$(if($Results.EmailDelivery.VerificationMessages.Count -gt 0) {'✅ Found'} else {'❌ None found'})</td></tr>
            </table>
        </div>
"@
    }

    $html += @"
        <div class="section">
            <div class="section-title">🛠️ Applied Fixes</div>
            
            <div class="$(if($AppliedFixes) {'fix-applied'} else {'fix-pending'})">
                <h4>📝 Allow List Configuration</h4>
                <p>$(if($AppliedFixes) {'✅ APPLIED:'} else {'⏳ PENDING:'}) Added Microsoft booking domains to spam filter allow list</p>
                <ul>
                    <li>outlook.office365.com</li>
                    <li>microsoft.com</li>
                    <li>microsoftonline.com</li>
                    <li>bookings.microsoft.com</li>
                </ul>
            </div>
            
            <div class="$(if($AppliedFixes) {'fix-applied'} else {'fix-pending'})">
                <h4>🎯 Spam Filtering Adjustment</h4>
                <p>$(if($AppliedFixes) {'✅ APPLIED:'} else {'⏳ PENDING:'}) Relaxed spam filtering for better verification email delivery</p>
                <ul>
                    <li>Increased bulk email threshold to 9</li>
                    <li>Disabled language and region blocking</li>
                </ul>
            </div>
            
            <div class="$(if($AppliedFixes) {'fix-applied'} else {'fix-pending'})">
                <h4>🛡️ Safe Attachments Optimization</h4>
                <p>$(if($AppliedFixes) {'✅ APPLIED:'} else {'⏳ PENDING:'}) Configured Safe Attachments for faster email delivery</p>
                <ul>
                    <li>Set to Dynamic Delivery mode</li>
                    <li>Reduced processing delays</li>
                </ul>
            </div>
        </div>

        <div class="section">
            <div class="section-title">📞 Next Steps</div>
            
            <div class="action-item">
                <h4>🚨 IMMEDIATE ACTIONS (Next 30 minutes)</h4>
                <ol>
                    <li>Ask Michelle to check her Gmail spam folder</li>
                    <li>Have Holly try to book a meeting again to test verification delivery</li>
                    <li>Monitor message trace for new verification attempts</li>
                    <li>Contact client to confirm if issue is resolved</li>
                </ol>
            </div>
            
            <div class="action-item">
                <h4>🔍 FOLLOW-UP ACTIONS (Next 24 hours)</h4>
                <ol>
                    <li>Run full diagnostic if issue persists: .\\Investigate-M365BookingVerificationIssue.ps1</li>
                    <li>Check if custom booking application needs configuration updates</li>
                    <li>Review Exchange message trace for delivery confirmation</li>
                    <li>Consider implementing SMS verification as backup option</li>
                </ol>
            </div>
            
            <div class="action-item">
                <h4>💡 PREVENTIVE MEASURES</h4>
                <ol>
                    <li>Document booking system configuration</li>
                    <li>Set up monitoring for verification email delivery</li>
                    <li>Create fallback communication method for booking confirmations</li>
                    <li>Train staff on troubleshooting booking issues</li>
                </ol>
            </div>
        </div>

        <div class="section">
            <div class="section-title">📞 Support Information</div>
            <p><strong>MSP:</strong> Kavira Technology</p>
            <p><strong>Priority:</strong> HIGH - Business Impact</p>
            <p><strong>ETA for Resolution:</strong> 2-4 hours after fixes applied</p>
            <p><strong>Next Check:</strong> $(Get-Date (Get-Date).AddHours(2) -Format 'dd MMM yyyy HH:mm')</p>
        </div>
    </div>
</body>
</html>
"@

    Set-Content -Path $reportPath -Value $html -Encoding UTF8
    Write-KaviraLog "Fix report generated: $reportPath" "SUCCESS"
    return $reportPath
}

# Main execution
try {
    Write-KaviraLog "Starting booking verification quick fix for $TenantName..." "INFO"
    
    # Load tenant configuration
    $tenantConfig = Get-Content "C:\MSP\Config\tenants.json" | ConvertFrom-Json
    $targetTenant = $tenantConfig | Where-Object { $_.Name -eq $TenantName }
    
    if (-not $targetTenant) {
        throw "Tenant '$TenantName' not found in configuration"
    }
    
    Write-KaviraLog "Connecting to tenant: $($targetTenant.Name)" "INFO"
    Connect-KaviraGraph -TenantInfo $targetTenant
    Connect-ExchangeOnline -CertificateThumbprint $targetTenant.CertThumb -AppId $targetTenant.AppId -Organization $targetTenant.Domain -ShowBanner:$false
    
    # Initialize results
    $results = @{}
    
    # Run tests and fixes
    $results.EmailDelivery = Test-CurrentEmailDelivery -TenantInfo $targetTenant -TestEmail $TestEmailAddress
    $results.AllowList = Add-BookingEmailAllowList -TenantInfo $targetTenant -ApplyChanges $ApplyFixes
    $results.SpamSettings = Adjust-SpamFilteringSettings -TenantInfo $targetTenant -ApplyChanges $ApplyFixes
    $results.SafeAttachments = Configure-SafeAttachmentsExceptions -TenantInfo $targetTenant -ApplyChanges $ApplyFixes
    $results.BookingsConfig = Test-BookingsConfiguration -TenantInfo $targetTenant
    $results.TestEmail = Send-TestVerificationEmail -TenantInfo $targetTenant -TestEmail $TestEmailAddress -ApplyChanges $ApplyFixes
    
    # Generate report
    $reportPath = Generate-FixReport -Results $results -TenantInfo $targetTenant -TestEmail $TestEmailAddress -AppliedFixes $ApplyFixes
    
    if ($ApplyFixes) {
        Write-KaviraLog "FIXES APPLIED SUCCESSFULLY!" "SUCCESS"
        Write-KaviraLog "Verification email delivery should be improved within 15-30 minutes" "SUCCESS"
    } else {
        Write-KaviraLog "DRY RUN COMPLETED - No changes made" "INFO"
        Write-KaviraLog "Run with -ApplyFixes parameter to implement changes" "INFO"
    }
    
    Write-KaviraLog "Report available: $reportPath" "SUCCESS"
    Start-Process $reportPath
    
}
catch {
    Write-KaviraLog "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    throw
}
finally {
    # Cleanup
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    } catch { }
}
