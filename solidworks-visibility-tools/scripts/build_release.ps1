param(
    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,
    [string] $ZipPath,
    [string] $SolidWorksInstallDir
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "Output directory already exists: $output" }
if (-not $ZipPath) { $ZipPath = $output + '.zip' }
$zip = [IO.Path]::GetFullPath($ZipPath)
if (Test-Path -LiteralPath $zip) { throw "ZIP already exists: $zip" }

$sourceDirectory = Join-Path $output 'Source'
New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $skillRoot 'assets\plugin\VisibilityToolsAddin.cs') `
    -Destination (Join-Path $sourceDirectory 'VisibilityToolsAddin.cs') -Force

$template = Join-Path $skillRoot 'assets\package'
foreach ($name in @('Install.cmd', 'Install.ps1', 'Uninstall.cmd', 'Uninstall.ps1', '使用说明.md')) {
    Copy-Item -LiteralPath (Join-Path $template $name) -Destination (Join-Path $output $name) -Force
}

& (Join-Path $PSScriptRoot 'verify_release.ps1') -PackageDirectory $output

if ($SolidWorksInstallDir) {
    $redist = Join-Path ([IO.Path]::GetFullPath($SolidWorksInstallDir)) 'api\redist'
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $smokeDll = Join-Path $env:TEMP ('SwVisibilityTools-smoke-' + [Guid]::NewGuid().ToString('N') + '.dll')
    $compileArguments = @(
        '/nologo', '/target:library', '/platform:x64', "/out:$smokeDll",
        '/reference:System.dll', '/reference:System.Core.dll', '/reference:System.Windows.Forms.dll',
        "/reference:$(Join-Path $redist 'SolidWorks.Interop.sldworks.dll')",
        "/reference:$(Join-Path $redist 'SolidWorks.Interop.swconst.dll')",
        "/reference:$(Join-Path $redist 'SolidWorks.Interop.swpublished.dll')",
        (Join-Path $sourceDirectory 'VisibilityToolsAddin.cs')
    )
    try {
        & $compiler $compileArguments
        if ($LASTEXITCODE -ne 0) { throw "Local compile smoke test failed with exit code $LASTEXITCODE." }
        Write-Output "PASS local compile smoke test: $SolidWorksInstallDir"
    } finally {
        Remove-Item -LiteralPath $smokeDll -Force -ErrorAction SilentlyContinue
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($output, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
Write-Output "RELEASE_DIRECTORY=$output"
Write-Output "RELEASE_ZIP=$zip"
