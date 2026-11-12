param(
    [Parameter(Mandatory = $true)]
    [string] $PackageDirectory
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PackageDirectory).Path
$required = @(
    'Install.cmd',
    'Install.ps1',
    'Uninstall.cmd',
    'Uninstall.ps1',
    '使用说明.md',
    'Source\VisibilityToolsAddin.cs'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing release file: $relative" }
}

$sourceText = [IO.File]::ReadAllText((Join-Path $root 'Source\VisibilityToolsAddin.cs'))
if ($sourceText -notmatch '0C6173E8-A351-4211-80A8-28D8518F7769') { throw 'Unexpected COM class GUID in source.' }
if ($sourceText -notmatch 'SwVisibilityTools\.Connect') { throw 'Unexpected ProgID in source.' }
foreach ($reference in @('SolidWorks.Interop.sldworks', 'SolidWorks.Interop.swconst', 'SolidWorks.Interop.swpublished')) {
    if ($sourceText -notmatch [regex]::Escape($reference)) { throw "Source is missing the strongly typed reference: $reference" }
}
if (Get-ChildItem -LiteralPath $root -Filter '*.dll' -Recurse -ErrorAction SilentlyContinue) {
    throw 'The release must not contain a precompiled plug-in DLL.'
}

foreach ($relative in @('Install.ps1', 'Uninstall.ps1')) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $root $relative))
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        throw "$relative must be UTF-8 with BOM."
    }
}

foreach ($relative in @('Install.cmd', 'Uninstall.cmd')) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $root $relative))
    $cr = @($bytes | Where-Object { $_ -eq 13 }).Count
    $lf = @($bytes | Where-Object { $_ -eq 10 }).Count
    if ($lf -eq 0 -or $cr -ne $lf) { throw "$relative must use Windows CRLF line endings." }
}

$installText = [IO.File]::ReadAllText((Join-Path $root 'Install.ps1'))
foreach ($token in @('api\redist', 'csc.exe', '/reference:', 'Major -lt 25', 'ProgramData', 'SolidWorksVisibilityTools', 'SolidWorksInstallDir')) {
    if ($installText -notmatch [regex]::Escape($token)) { throw "Install.ps1 is missing required install-time compilation logic: $token" }
}

foreach ($relative in @('Install.ps1', 'Uninstall.ps1')) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -ne 0) { throw "$relative has PowerShell parse errors: $($errors[0].Message)" }
}

Write-Output "PASS release validation: $root"
Write-Output 'PASS source-only release with install-time SolidWorks Interop compilation'
Write-Output 'PASS COM identity, API guard, PowerShell BOM, CMD CRLF, and ProgramData installation'
