#Requires -Version 5.1

<#
.SYNOPSIS
    Kavira MSP - Universal Branding Module (FIXED CSS RENDERING)
    
.DESCRIPTION
    Professional branding system for Kavira MSP automation platform.
    Provides consistent Kavira branding across all HTML outputs.
    
    CRITICAL FIX: CSS properly contained within <style> tags.
    No more CSS text escaping issues!
    
.AUTHOR
    Wim Knol - Kavira Technology
    
.VERSION
    1.1 - PowerShell 5.1 Compatible + CSS Rendering Fixed
    
.DATE
    2025-07-19
#>

# Export functions
Export-ModuleMember -Function @(
    'Get-KaviraLogo',
    'Get-KaviraCSS', 
    'New-KaviraHTMLPage',
    'Add-KaviraBranding'
)

function Get-KaviraLogo {
    <#
    .SYNOPSIS
        Returns the Kavira IT logo as SVG
    #>
    
    return @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 60" style="height: 50px; margin-bottom: 20px;">
  <defs>
    <linearGradient id="kaviraGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0078D4;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#106EBE;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- Background -->
  <rect width="200" height="60" fill="url(#kaviraGradient)" rx="8"/>
  
  <!-- Kavira Text -->
  <text x="20" y="35" font-family="Segoe UI, Arial, sans-serif" font-size="24" font-weight="600" fill="white">
    KAVIRA
  </text>
  
  <!-- IT Subtitle -->
  <text x="125" y="42" font-family="Segoe UI, Arial, sans-serif" font-size="14" fill="#E1F5FE">
    Technology
  </text>
  
  <!-- Accent Line -->
  <line x1="20" y1="45" x2="180" y2="45" stroke="#E1F5FE" stroke-width="2" opacity="0.7"/>
</svg>
"@
}

function Get-KaviraCSS {
    <#
    .SYNOPSIS
        Returns comprehensive CSS for Kavira branding
    .DESCRIPTION
        CRITICAL FIX: All CSS properly contained within single <style> block.
        No more CSS escaping or text rendering issues!
    #>
    
    return @"
<style>
/* Kavira MSP - Professional Styling (CSS Rendering FIXED) */

/* Reset and Base */
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
    background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
    min-height: 100vh;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    background: white;
    box-shadow: 0 10px 30px rgba(0,0,0,0.1);
    border-radius: 12px;
    margin-top: 20px;
    margin-bottom: 20px;
}

/* Header Styling */
h1 {
    color: #0078D4;
    font-size: 2.5em;
    margin-bottom: 10px;
    border-bottom: 3px solid #0078D4;
    padding-bottom: 10px;
}

h2 {
    color: #106EBE;
    font-size: 1.8em;
    margin: 25px 0 15px 0;
    border-left: 4px solid #0078D4;
    padding-left: 15px;
}

h3 {
    color: #2C5F8B;
    font-size: 1.4em;
    margin: 20px 0 10px 0;
}

/* Table Styling */
table {
    width: 100%;
    border-collapse: collapse;
    margin: 20px 0;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    border-radius: 8px;
    overflow: hidden;
}

th {
    background: linear-gradient(135deg, #0078D4 0%, #106EBE 100%);
    color: white;
    padding: 15px 12px;
    text-align: left;
    font-weight: 600;
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

td {
    padding: 12px;
    border-bottom: 1px solid #e0e6ed;
    vertical-align: top;
}

tr:nth-child(even) {
    background-color: #f8f9fa;
}

tr:hover {
    background-color: #e3f2fd;
    transition: background-color 0.3s ease;
}

/* Card Styling */
.card {
    background: white;
    border-radius: 12px;
    padding: 25px;
    margin: 20px 0;
    box-shadow: 0 6px 20px rgba(0,0,0,0.1);
    border-left: 5px solid #0078D4;
}

.card-header {
    background: linear-gradient(135deg, #0078D4 0%, #106EBE 100%);
    color: white;
    padding: 20px;
    border-radius: 8px 8px 0 0;
    margin: -25px -25px 20px -25px;
    font-size: 1.3em;
    font-weight: 600;
}

/* Alert Styling */
.alert {
    padding: 15px 20px;
    margin: 15px 0;
    border-radius: 8px;
    border-left: 5px solid;
}

.alert-success {
    background-color: #d4edda;
    border-color: #28a745;
    color: #155724;
}

.alert-warning {
    background-color: #fff3cd;
    border-color: #ffc107;
    color: #856404;
}

.alert-danger {
    background-color: #f8d7da;
    border-color: #dc3545;
    color: #721c24;
}

.alert-info {
    background-color: #d1ecf1;
    border-color: #17a2b8;
    color: #0c5460;
}

/* Status Badges */
.badge {
    display: inline-block;
    padding: 6px 12px;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
    border-radius: 20px;
    letter-spacing: 0.5px;
}

.badge-success { background: #28a745; color: white; }
.badge-warning { background: #ffc107; color: #212529; }
.badge-danger { background: #dc3545; color: white; }
.badge-info { background: #17a2b8; color: white; }
.badge-primary { background: #0078D4; color: white; }

/* Progress Bars */
.progress {
    background-color: #e9ecef;
    border-radius: 20px;
    overflow: hidden;
    height: 24px;
    margin: 10px 0;
}

.progress-bar {
    background: linear-gradient(90deg, #0078D4 0%, #106EBE 100%);
    height: 100%;
    border-radius: 20px;
    text-align: center;
    line-height: 24px;
    color: white;
    font-weight: 600;
    font-size: 12px;
    transition: width 0.6s ease;
}

/* Footer */
.footer {
    margin-top: 40px;
    padding: 25px 0;
    border-top: 2px solid #e0e6ed;
    text-align: center;
    color: #6c757d;
    font-size: 14px;
}

.footer strong {
    color: #0078D4;
}

/* Responsive */
@media (max-width: 768px) {
    .container { padding: 15px; margin: 10px; }
    h1 { font-size: 2em; }
    h2 { font-size: 1.5em; }
    table { font-size: 14px; }
    th, td { padding: 8px; }
}

/* Print Styling */
@media print {
    body { background: white; }
    .container { box-shadow: none; }
    .progress-bar { background: #666 !important; }
}
</style>
"@
}

function New-KaviraHTMLPage {
    <#
    .SYNOPSIS
        Creates a complete HTML page with Kavira branding
    .PARAMETER Title
        Page title
    .PARAMETER Content
        HTML content
    .PARAMETER AddFooter
        Include Kavira footer
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Content,
        
        [switch]$AddFooter
    )
    
    $logo = Get-KaviraLogo
    $css = Get-KaviraCSS
    
    $footer = if ($AddFooter) {
        @"
<div class="footer">
    <strong>Kavira Technology</strong> | Professional MSP Services<br>
    Generated on $(Get-Date -Format 'dd/MM/yyyy HH:mm')
</div>
"@
    } else { "" }
    
    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title - Kavira MSP</title>
    $css
</head>
<body>
    <div class="container">
        $logo
        <h1>$Title</h1>
        $Content
        $footer
    </div>
</body>
</html>
"@
}

function Add-KaviraBranding {
    <#
    .SYNOPSIS
        Adds Kavira branding to existing HTML content
    .PARAMETER HTMLContent
        Existing HTML content
    .PARAMETER Title
        Page title
    .PARAMETER AddFooter
        Include footer
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$HTMLContent,
        
        [string]$Title = "Kavira MSP Report",
        [switch]$AddFooter
    )
    
    return New-KaviraHTMLPage -Title $Title -Content $HTMLContent -AddFooter:$AddFooter
}

Write-Host "Kavira MSP Branding Module v1.1 loaded successfully!" -ForegroundColor Green
Write-Host "✅ PowerShell 5.1 Compatible" -ForegroundColor Green
Write-Host "✅ CSS Rendering Fixed" -ForegroundColor Green
Write-Host "✅ Professional HTML Output Ready" -ForegroundColor Green