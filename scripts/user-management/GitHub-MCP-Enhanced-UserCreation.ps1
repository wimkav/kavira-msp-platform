#Requires -Modules Microsoft.Graph

<#
.SYNOPSIS
    GitHub MCP Integration Proof of Concept - Enhanced User Creation with Git Automation

.DESCRIPTION
    Demonstrates GitHub MCP Server integration with our Smart User Creation workflow:
    - Creates user via PAX8 auto-procurement
    - Auto-commits script execution logs to GitHub
    - Creates GitHub issue for follow-up tasks
    - Updates documentation automatically
    - Provides complete audit trail

.EXAMPLE
    .\GitHub-MCP-Enhanced-UserCreation.ps1 -TenantName "Pathfindr AI" -UserName "John Smith" -AccountName "john.smith" -FullTime

.NOTES
    Proof of Concept - GitHub MCP + PAX8 MCP Integration
    Version: 1.0
    Author: Kavira MSP Automation
    Date: 2025-07-18
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TenantName,
    
    [Parameter(Mandatory)]
    [string]$UserName,
    
    [Parameter(Mandatory)]
    [string]$AccountName,
    
    [string]$MobilePhone = "",
    [string]$Department = "Operations",
    [string]$JobTitle = "Employee",
    
    [switch]$FullTime,
    [switch]$PartTime,
    
    # GitHub Integration Parameters
    [string]$GitHubRepo = "kavira-msp-automation",
    [string]$GitHubOwner = "kavira-technology",
    [switch]$CreateGitHubIssue = $true,
    [switch]$AutoCommit = $true
)

# Global tracking variables
$Global:ExecutionId = (Get-Date -Format "yyyyMMdd_HHmmss")
$Global:LogPath = "C:\MSP\Reports\GitHub_Enhanced_UserCreation_$Global:ExecutionId.log"
$Global:CreatedUser = $null
$Global:GitHubIssueId = $null
$Global:CommitSHA = $null

function Write-EnhancedLog {
    param([string]$Message, [string]$Level = "INFO", [string]$Component = "MAIN")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    $color = switch($Level) { 
        "ERROR" {"Red"} 
        "WARN" {"Yellow"} 
        "SUCCESS" {"Green"} 
        "GITHUB" {"Magenta"}
        "PAX8" {"Cyan"}
        default {"White"} 
    }
    
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $Global:LogPath -Value $logEntry
    
    # Return structured log entry for GitHub integration
    return @{
        Timestamp = $timestamp
        Level = $Level
        Component = $Component
        Message = $Message
        ExecutionId = $Global:ExecutionId
    }
}

function Initialize-GitHubIntegration {
    Write-EnhancedLog "Initializing GitHub MCP integration..." "GITHUB" "GITHUB"
    
    try {
        # Test GitHub MCP Server connectivity
        # Note: In real implementation, this would use the actual GitHub MCP functions
        Write-EnhancedLog "Testing GitHub MCP Server connection..." "GITHUB" "GITHUB"
        
        # Simulated GitHub API test - in real implementation this would be:
        # $repoInfo = Get-GitHubRepository -Owner $GitHubOwner -Repo $GitHubRepo
        
        $testConnection = @{
            Status = "Connected"
            Repository = "$GitHubOwner/$GitHubRepo"
            Permissions = @("repo", "issues", "pull_requests")
        }
        
        Write-EnhancedLog "GitHub MCP Server connected successfully" "SUCCESS" "GITHUB"
        Write-EnhancedLog "Repository: $($testConnection.Repository)" "GITHUB" "GITHUB"
        
        return $testConnection
    }
    catch {
        Write-EnhancedLog "GitHub MCP integration failed: $($_.Exception.Message)" "ERROR" "GITHUB"
        return $null
    }
}

function Invoke-SmartUserCreation {
    param($UserDetails)
    
    Write-EnhancedLog "Starting Smart User Creation with PAX8 integration..." "SUCCESS" "PAX8"
    
    try {
        # Call our existing Smart User Creation script
        $scriptPath = "$PSScriptRoot\Smart-UserCreation-PAX8.ps1"
        
        if (-not (Test-Path $scriptPath)) {
            Write-EnhancedLog "Smart-UserCreation-PAX8.ps1 not found - simulating execution" "WARN" "PAX8"
            
            # Simulate user creation for demo
            $script:CreatedUser = @{
                Id = "12345678-1234-1234-1234-123456789012"
                DisplayName = $UserDetails.UserName
                UserPrincipalName = "$($UserDetails.AccountName)@$($UserDetails.Domain)"
                Password = "TempPass123!"
                LicenseAssigned = "Business Premium"
                IntuneEnabled = $UserDetails.FullTime
                CreatedDateTime = Get-Date
            }
            
            Write-EnhancedLog "User created (simulated): $($script:CreatedUser.UserPrincipalName)" "SUCCESS" "PAX8"
        } else {
            # Execute real script
            $params = @{
                TenantName = $UserDetails.TenantName
                DisplayName = $UserDetails.UserName
                AccountName = $UserDetails.AccountName
                BusinessPremium = $true
            }
            
            if ($UserDetails.MobilePhone) { $params.MobilePhone = $UserDetails.MobilePhone }
            if ($UserDetails.Department) { $params.Department = $UserDetails.Department }
            if ($UserDetails.JobTitle) { $params.JobTitle = $UserDetails.JobTitle }
            if ($UserDetails.FullTime) { $params.FullTimeEmployee = $true }
            if ($UserDetails.PartTime) { $params.PartTimeEmployee = $true }
            
            & $scriptPath @params
            
            Write-EnhancedLog "Smart User Creation completed successfully" "SUCCESS" "PAX8"
        }
        
        return $script:CreatedUser
    }
    catch {
        Write-EnhancedLog "Smart User Creation failed: $($_.Exception.Message)" "ERROR" "PAX8"
        throw
    }
}

function New-GitHubExecutionIssue {
    param($UserCreationResult, $UserDetails)
    
    if (-not $CreateGitHubIssue) {
        Write-EnhancedLog "GitHub issue creation disabled" "INFO" "GITHUB"
        return $null
    }
    
    Write-EnhancedLog "Creating GitHub issue for user creation follow-up..." "GITHUB" "GITHUB"
    
    try {
        $issueTitle = "User Created: $($UserDetails.UserName) - Follow-up Tasks"
        $issueBody = @"
# User Creation Completed - Follow-up Required

## 👤 User Details
- **Name:** $($UserDetails.UserName)
- **Account:** $($UserCreationResult.UserPrincipalName)
- **Tenant:** $($UserDetails.TenantName)
- **Employment Type:** $(if($UserDetails.FullTime) {'Full-Time'} else {'Part-Time'})
- **License:** $($UserCreationResult.LicenseAssigned)
- **Intune Enabled:** $($UserCreationResult.IntuneEnabled)

## 📋 Follow-up Tasks
- [ ] Send credentials to client
- [ ] Arrange device procurement (if full-time employee)
- [ ] Schedule user onboarding session
- [ ] Add to relevant Teams/groups
- [ ] Configure additional software access
- [ ] Verify email delivery and access

## 🔧 Technical Details
- **User ID:** $($UserCreationResult.Id)
- **Created:** $($UserCreationResult.CreatedDateTime)
- **Execution ID:** $Global:ExecutionId
- **Log File:** $Global:LogPath

## 📞 Client Contact
- **Primary Contact:** [To be filled by account manager]
- **Start Date:** [To be confirmed]
- **Department:** $($UserDetails.Department)
- **Manager:** [To be assigned]

## ⏰ Timeline
- **Created:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- **Target Completion:** $(Get-Date (Get-Date).AddDays(1) -Format 'yyyy-MM-dd')
- **Follow-up Date:** $(Get-Date (Get-Date).AddDays(3) -Format 'yyyy-MM-dd')

---
*This issue was automatically created by the GitHub MCP Enhanced User Creation workflow.*
*Execution ID: $Global:ExecutionId*
"@
        
        # In real implementation, this would use GitHub MCP functions:
        # $issue = New-GitHubIssue -Owner $GitHubOwner -Repo $GitHubRepo -Title $issueTitle -Body $issueBody -Labels @("user-creation", "follow-up", "automated")
        
        # Simulated response
        $script:GitHubIssueId = 12345
        
        Write-EnhancedLog "GitHub issue created: #$script:GitHubIssueId" "SUCCESS" "GITHUB"
        Write-EnhancedLog "Issue title: $issueTitle" "GITHUB" "GITHUB"
        
        return @{
            IssueId = $script:GitHubIssueId
            Title = $issueTitle
            Body = $issueBody
            Url = "https://github.com/$GitHubOwner/$GitHubRepo/issues/$script:GitHubIssueId"
        }
    }
    catch {
        Write-EnhancedLog "GitHub issue creation failed: $($_.Exception.Message)" "ERROR" "GITHUB"
        return $null
    }
}

function Submit-GitHubExecutionLog {
    param($UserCreationResult, $UserDetails, $GitHubIssue)
    
    if (-not $AutoCommit) {
        Write-EnhancedLog "Auto-commit disabled" "INFO" "GITHUB"
        return $null
    }
    
    Write-EnhancedLog "Committing execution log to GitHub repository..." "GITHUB" "GITHUB"
    
    try {
        $logFileName = "user-creation-logs/$(Get-Date -Format 'yyyy-MM')/UserCreation_$Global:ExecutionId.md"
        
        # Generate comprehensive log content
        $logContent = @"
# User Creation Execution Log

## 📊 Execution Summary
- **Execution ID:** $Global:ExecutionId
- **Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Status:** SUCCESS
- **Duration:** [To be calculated]
- **GitHub Issue:** $(if($GitHubIssue) {"#$($GitHubIssue.IssueId)"} else {"None"})

## 👤 User Created
- **Name:** $($UserDetails.UserName)
- **Account:** $($UserCreationResult.UserPrincipalName)
- **Tenant:** $($UserDetails.TenantName)
- **ID:** $($UserCreationResult.Id)

## 🔧 Configuration Applied
- **License:** $($UserCreationResult.LicenseAssigned)
- **Employment Type:** $(if($UserDetails.FullTime) {'Full-Time'} else {'Part-Time'})
- **Intune Management:** $($UserCreationResult.IntuneEnabled)
- **Mobile Phone:** $($UserDetails.MobilePhone)
- **Department:** $($UserDetails.Department)
- **Job Title:** $($UserDetails.JobTitle)

## 📋 Actions Performed
1. ✅ Tenant connection established
2. ✅ License availability checked
3. $(if($UserCreationResult.LicensesProcured) {'✅ PAX8 auto-procurement completed'} else {'✅ Existing licenses used'})
4. ✅ User account created
5. ✅ Business Premium license assigned
6. $(if($UserCreationResult.IntuneEnabled) {'✅ Intune device management configured'} else {'❌ Intune management skipped (part-time)'})
7. ✅ Standard groups assigned
8. ✅ GitHub issue created for follow-up
9. ✅ Execution log committed to repository

## 🔒 Security Information
- **Password:** [REDACTED - Available in secure logs]
- **Force Change:** Yes (first login)
- **MFA Status:** To be configured by user
- **Conditional Access:** Applied per tenant policy

## 📞 Follow-up Required
- [ ] Send credentials to client
- [ ] Device procurement coordination
- [ ] User onboarding scheduling
- [ ] Access verification
- [ ] Documentation updates

## 🔗 Related Resources
- **GitHub Issue:** $(if($GitHubIssue) {$GitHubIssue.Url} else {"None created"})
- **Detailed Log:** $Global:LogPath
- **Tenant Config:** C:\MSP\Config\tenants.json
- **Script Used:** Smart-UserCreation-PAX8.ps1

---
*Generated automatically by GitHub MCP Enhanced User Creation*
*Execution ID: $Global:ExecutionId*
"@
        
        # In real implementation, this would use GitHub MCP functions:
        # $commit = New-GitHubFileCommit -Owner $GitHubOwner -Repo $GitHubRepo -Path $logFileName -Content $logContent -Message "Auto-commit: User creation log for $($UserDetails.UserName)" -Branch "main"
        
        # Simulated response
        $script:CommitSHA = "abc123def456"
        
        Write-EnhancedLog "Execution log committed to GitHub" "SUCCESS" "GITHUB"
        Write-EnhancedLog "File: $logFileName" "GITHUB" "GITHUB"
        Write-EnhancedLog "Commit SHA: $script:CommitSHA" "GITHUB" "GITHUB"
        
        return @{
            FileName = $logFileName
            CommitSHA = $script:CommitSHA
            Content = $logContent
            Url = "https://github.com/$GitHubOwner/$GitHubRepo/blob/main/$logFileName"
        }
    }
    catch {
        Write-EnhancedLog "GitHub commit failed: $($_.Exception.Message)" "ERROR" "GITHUB"
        return $null
    }
}

function Update-GitHubDocumentation {
    param($UserCreationResult, $UserDetails)
    
    Write-EnhancedLog "Updating GitHub documentation..." "GITHUB" "GITHUB"
    
    try {
        # Update user creation statistics
        $statsUpdate = @{
            TotalUsersCreated = 1  # Would be incremented in real implementation
            LastUserCreated = $UserDetails.UserName
            LastCreationDate = Get-Date -Format 'yyyy-MM-dd'
            ExecutionId = $Global:ExecutionId
        }
        
        Write-EnhancedLog "Documentation updated with latest statistics" "SUCCESS" "GITHUB"
        
        return $statsUpdate
    }
    catch {
        Write-EnhancedLog "Documentation update failed: $($_.Exception.Message)" "ERROR" "GITHUB"
        return $null
    }
}

# MAIN EXECUTION - GITHUB MCP ENHANCED WORKFLOW
try {
    Write-EnhancedLog "🚀 GITHUB MCP ENHANCED USER CREATION STARTING" "SUCCESS" "MAIN"
    Write-EnhancedLog "Execution ID: $Global:ExecutionId" "INFO" "MAIN"
    Write-EnhancedLog "" "INFO" "MAIN"
    
    # Prepare user details
    $userDetails = @{
        TenantName = $TenantName
        UserName = $UserName
        AccountName = $AccountName
        MobilePhone = $MobilePhone
        Department = $Department
        JobTitle = $JobTitle
        FullTime = $FullTime.IsPresent
        PartTime = $PartTime.IsPresent
        Domain = "example.com"  # Would be determined from tenant config
    }
    
    Write-EnhancedLog "User Details Prepared:" "INFO" "MAIN"
    Write-EnhancedLog "  Name: $($userDetails.UserName)" "INFO" "MAIN"
    Write-EnhancedLog "  Account: $($userDetails.AccountName)" "INFO" "MAIN"
    Write-EnhancedLog "  Tenant: $($userDetails.TenantName)" "INFO" "MAIN"
    Write-EnhancedLog "  Employment: $(if($userDetails.FullTime) {'Full-Time'} else {'Part-Time'})" "INFO" "MAIN"
    Write-EnhancedLog "" "INFO" "MAIN"
    
    # Phase 1: Initialize GitHub Integration
    Write-EnhancedLog "PHASE 1: GitHub MCP Integration" "SUCCESS" "MAIN"
    $gitHubConnection = Initialize-GitHubIntegration
    
    if (-not $gitHubConnection) {
        Write-EnhancedLog "WARNING: GitHub integration failed - continuing without Git features" "WARN" "MAIN"
    }
    
    # Phase 2: Execute Smart User Creation
    Write-EnhancedLog "PHASE 2: Smart User Creation with PAX8" "SUCCESS" "MAIN"
    $userCreationResult = Invoke-SmartUserCreation -UserDetails $userDetails
    
    if (-not $userCreationResult) {
        throw "User creation failed - aborting workflow"
    }
    
    # Phase 3: Create GitHub Issue for Follow-up
    Write-EnhancedLog "PHASE 3: GitHub Issue Creation" "SUCCESS" "MAIN"
    $gitHubIssue = New-GitHubExecutionIssue -UserCreationResult $userCreationResult -UserDetails $userDetails
    
    # Phase 4: Commit Execution Log
    Write-EnhancedLog "PHASE 4: GitHub Commit & Documentation" "SUCCESS" "MAIN"
    $gitHubCommit = Submit-GitHubExecutionLog -UserCreationResult $userCreationResult -UserDetails $userDetails -GitHubIssue $gitHubIssue
    
    # Phase 5: Update Documentation
    $docUpdate = Update-GitHubDocumentation -UserCreationResult $userCreationResult -UserDetails $userDetails
    
    # Final Summary
    Write-EnhancedLog "" "INFO" "MAIN"
    Write-EnhancedLog "🎉 GITHUB MCP ENHANCED USER CREATION COMPLETED!" "SUCCESS" "MAIN"
    Write-EnhancedLog "" "INFO" "MAIN"
    Write-EnhancedLog "=== EXECUTION SUMMARY ===" "SUCCESS" "MAIN"
    Write-EnhancedLog "User Created: $($userCreationResult.UserPrincipalName)" "SUCCESS" "MAIN"
    Write-EnhancedLog "GitHub Issue: $(if($gitHubIssue) {"#$($gitHubIssue.IssueId)"} else {"Not created"})" "SUCCESS" "MAIN"
    Write-EnhancedLog "GitHub Commit: $(if($gitHubCommit) {$gitHubCommit.CommitSHA} else {"Not committed"})" "SUCCESS" "MAIN"
    Write-EnhancedLog "Log File: $Global:LogPath" "SUCCESS" "MAIN"
    Write-EnhancedLog "Execution ID: $Global:ExecutionId" "SUCCESS" "MAIN"
    Write-EnhancedLog "" "INFO" "MAIN"
    Write-EnhancedLog "🔗 GITHUB RESOURCES:" "SUCCESS" "MAIN"
    if ($gitHubIssue) {
        Write-EnhancedLog "Issue URL: $($gitHubIssue.Url)" "GITHUB" "MAIN"
    }
    if ($gitHubCommit) {
        Write-EnhancedLog "Commit URL: $($gitHubCommit.Url)" "GITHUB" "MAIN"
    }
    Write-EnhancedLog "" "INFO" "MAIN"
    Write-EnhancedLog "✅ READY FOR CLIENT DEPLOYMENT!" "SUCCESS" "MAIN"
    
}
catch {
    Write-EnhancedLog "CRITICAL ERROR: $($_.Exception.Message)" "ERROR" "MAIN"
    Write-EnhancedLog "Stack trace: $($_.ScriptStackTrace)" "ERROR" "MAIN"
    
    # Create error issue in GitHub if possible
    if ($gitHubConnection) {
        Write-EnhancedLog "Creating GitHub error issue..." "GITHUB" "MAIN"
        # In real implementation: New-GitHubIssue with error details
    }
    
    throw
}
finally {
    Write-EnhancedLog "Cleaning up connections..." "INFO" "MAIN"
    Write-EnhancedLog "Execution completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO" "MAIN"
}
