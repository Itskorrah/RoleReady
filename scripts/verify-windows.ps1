[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script:CheckCount = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Test-Requirement {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )

    $script:CheckCount += 1
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:Failures.Add($Message)
    }
}

function Read-RepositoryText {
    param([Parameter(Mandatory)] [string] $RelativePath)
    return [System.IO.File]::ReadAllText((Join-Path $Root $RelativePath))
}

Write-Host "RoleReady repository verification" -ForegroundColor Cyan
Write-Host "Root: $Root"

$requiredPaths = @(
    "RoleReady.xcodeproj/project.pbxproj",
    "RoleReady.xcodeproj/xcshareddata/xcschemes/RoleReady.xcscheme",
    "project.yml",
    "RoleReady/App/RoleReadyApp.swift",
    "RoleReady/App/AppShell.swift",
    "RoleReady/Models/DomainTypes.swift",
    "RoleReady/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "RoleReadyTests",
    "RoleReadyUITests",
    "scripts/test-ios.sh"
)

foreach ($relativePath in $requiredPaths) {
    Test-Requirement (Test-Path (Join-Path $Root $relativePath)) "Required path exists: $relativePath"
}

$swiftFiles = @(Get-ChildItem (Join-Path $Root "RoleReady") -Recurse -File -Filter "*.swift")
Test-Requirement ($swiftFiles.Count -ge 25) "App target contains a substantive Swift source set ($($swiftFiles.Count) files)"

$modelCount = 0
foreach ($file in $swiftFiles) {
    $modelCount += [regex]::Matches([System.IO.File]::ReadAllText($file.FullName), "(?m)^@Model\s*$").Count
}
Test-Requirement ($modelCount -eq 17) "Exactly 17 SwiftData models are declared"

$domainTypes = Read-RepositoryText "RoleReady/Models/DomainTypes.swift"
foreach ($tabCase in @("today", "resumes", "jobs", "interview", "career")) {
    Test-Requirement ($domainTypes -match "(?m)^\s*case\s+$tabCase\s*$") "Career-workspace tab model includes '$tabCase'"
}
Test-Requirement (-not ($domainTypes -match "(?m)^\s*case\s+(prepare|examples|practise|evidence|roles)\s*$")) "Obsolete primary tabs are absent"

$appShell = Read-RepositoryText "RoleReady/App/AppShell.swift"
Test-Requirement ($appShell.Contains("TabView(selection:")) "App shell uses the tab model"
Test-Requirement ($appShell.Contains(".privacySensitive()")) "App shell applies global privacy-sensitive coverage"

$projectYml = Read-RepositoryText "project.yml"
Test-Requirement ($projectYml.Contains('SWIFT_VERSION: "6.0"')) "project.yml selects Swift 6.0"
Test-Requirement ($projectYml -match "SWIFT_STRICT_CONCURRENCY:\s*complete") "project.yml enables complete strict concurrency"
Test-Requirement ($projectYml -match "SWIFT_TREAT_WARNINGS_AS_ERRORS:\s*YES") "project.yml treats Swift warnings as errors"
Test-Requirement ($projectYml.Contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME")) "project.yml uses the global accent-colour setting"
Test-Requirement ($projectYml -match "MARKETING_VERSION:\s*1\.0\.0") "project.yml declares marketing version 1.0.0"
Test-Requirement ($projectYml -match "CURRENT_PROJECT_VERSION:\s*1") "project.yml declares build number 1"

$pbxProject = Read-RepositoryText "RoleReady.xcodeproj/project.pbxproj"
$swiftVersions = [regex]::Matches($pbxProject, "SWIFT_VERSION\s*=\s*([^;]+);")
$strictConcurrency = [regex]::Matches($pbxProject, "SWIFT_STRICT_CONCURRENCY\s*=\s*([^;]+);")
$warningPolicies = [regex]::Matches($pbxProject, "SWIFT_TREAT_WARNINGS_AS_ERRORS\s*=\s*([^;]+);")
Test-Requirement ($swiftVersions.Count -ge 6 -and @($swiftVersions | Where-Object { $_.Groups[1].Value.Trim() -ne "6.0" }).Count -eq 0) "All checked-in Swift language settings use version 6.0"
Test-Requirement ($strictConcurrency.Count -ge 6 -and @($strictConcurrency | Where-Object { $_.Groups[1].Value.Trim() -ne "complete" }).Count -eq 0) "All checked-in concurrency settings use complete checking"
Test-Requirement ($warningPolicies.Count -ge 6 -and @($warningPolicies | Where-Object { $_.Groups[1].Value.Trim() -ne "YES" }).Count -eq 0) "All checked-in Swift build configurations treat warnings as errors"
Test-Requirement (-not $pbxProject.Contains("ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME")) "Legacy accent-colour setting is absent"
Test-Requirement ($pbxProject.Contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME")) "Checked-in project uses the global accent-colour setting"
Test-Requirement (-not $pbxProject.Contains("XCRemoteSwiftPackageReference")) "Project has no undeclared remote package dependency"

$assetCatalogs = @(Get-ChildItem (Join-Path $Root "RoleReady") -Recurse -File -Filter "Contents.json")
Test-Requirement ($assetCatalogs.Count -ge 3) "Asset catalog metadata is present"
foreach ($catalog in $assetCatalogs) {
    $validJson = $true
    try {
        $null = [System.IO.File]::ReadAllText($catalog.FullName) | ConvertFrom-Json
    } catch {
        $validJson = $false
    }
    $displayPath = $catalog.FullName.Substring($Root.Length).TrimStart([char[]]@('\', '/'))
    Test-Requirement $validJson "Asset metadata is valid JSON: $displayPath"
}

$appIconDirectory = Join-Path $Root "RoleReady/Resources/Assets.xcassets/AppIcon.appiconset"
$appIcons = @(Get-ChildItem $appIconDirectory -File -Filter "*.png")
Test-Requirement ($appIcons.Count -eq 3) "Default, dark, and tinted app icons are present"
foreach ($icon in $appIcons) {
    $bytes = [System.IO.File]::ReadAllBytes($icon.FullName)
    $isPng = $bytes.Length -ge 24 -and
        $bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47
    $width = if ($isPng) { [System.Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes, 16)) } else { 0 }
    $height = if ($isPng) { [System.Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes, 20)) } else { 0 }
    $colourType = if ($isPng) { $bytes[25] } else { 255 }
    Test-Requirement ($isPng -and $width -eq 1024 -and $height -eq 1024) "App icon is a 1024x1024 PNG: $($icon.Name)"
    Test-Requirement ($colourType -ne 4 -and $colourType -ne 6) "App icon PNG has no alpha channel: $($icon.Name)"
}

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "$($script:Failures.Count) of $script:CheckCount checks failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All $script:CheckCount repository checks passed." -ForegroundColor Green
Write-Host "This host-only verification does not compile Swift or run the iOS test suite; use scripts/test-ios.sh on macOS." -ForegroundColor Yellow
