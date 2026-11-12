param(
    [string] $SolidWorksInstallDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Get-SolidWorksTarget {
    param([string] $RequestedPath)

    if ($RequestedPath) {
        $candidate = [IO.Path]::GetFullPath($RequestedPath.TrimEnd('\'))
        return [pscustomobject]@{ Year = 0; Path = $candidate; Source = '命令行指定' }
    }

    $candidates = @()
    foreach ($root in @('HKLM:\SOFTWARE\SolidWorks', 'HKLM:\SOFTWARE\WOW6432Node\SolidWorks')) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            if ($key.PSChildName -notmatch '^SOLIDWORKS (20\d\d)$') { continue }
            $year = [int]$Matches[1]
            if ($year -lt 2017) { continue }
            $setup = Join-Path $key.PSPath 'Setup'
            $path = (Get-ItemProperty -LiteralPath $setup -Name 'SolidWorks Folder' -ErrorAction SilentlyContinue).'SolidWorks Folder'
            if ($path) {
                $candidates += [pscustomobject]@{ Year = $year; Path = $path.TrimEnd('\'); Source = $key.Name }
            }
        }
    }
    $selected = $candidates | Sort-Object Year -Descending | Select-Object -First 1
    if (-not $selected) {
        throw '未找到 SOLIDWORKS 2017 或更高版本。可使用 -SolidWorksInstallDir 指定 SOLIDWORKS 主目录。'
    }
    return $selected
}

try {
    if (Get-Process SLDWORKS -ErrorAction SilentlyContinue) {
        throw '请先保存工作并完整退出 SolidWorks，再安装插件。'
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
        if ($SolidWorksInstallDir) {
            $arguments += ' -SolidWorksInstallDir "{0}"' -f $SolidWorksInstallDir
        }
        $child = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        exit $child.ExitCode
    }

    $target = Get-SolidWorksTarget -RequestedPath $SolidWorksInstallDir
    $redist = Join-Path $target.Path 'api\redist'
    $sldworksInterop = Join-Path $redist 'SolidWorks.Interop.sldworks.dll'
    $swconstInterop = Join-Path $redist 'SolidWorks.Interop.swconst.dll'
    $swpublishedInterop = Join-Path $redist 'SolidWorks.Interop.swpublished.dll'
    $solidWorksExe = Join-Path $target.Path 'SLDWORKS.exe'
    foreach ($required in @($solidWorksExe, $sldworksInterop, $swconstInterop, $swpublishedInterop)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "SolidWorks 安装目录不完整，缺少：$required" }
    }

    $apiVersion = [Reflection.AssemblyName]::GetAssemblyName($sldworksInterop).Version
    if ($apiVersion.Major -lt 25) {
        throw "SolidWorks API 版本为 $apiVersion，低于 SW2017 所需的 API 25。"
    }

    $source = Join-Path $PSScriptRoot 'Source\VisibilityToolsAddin.cs'
    if (-not (Test-Path -LiteralPath $source)) { throw "安装包不完整，缺少：$source" }
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $regasm = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe'
    if (-not (Test-Path -LiteralPath $compiler)) { throw '未找到 64 位 .NET Framework 4.x csc.exe。' }
    if (-not (Test-Path -LiteralPath $regasm)) { throw '未找到 64 位 .NET Framework 4.x RegAsm.exe。' }

    $installDir = Join-Path $env:ProgramData 'SolidWorksVisibilityTools'
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    foreach ($oldDll in @('SwVisibilityTools.dll', 'SwVisibilityTools-Universal.dll')) {
        $oldPath = Join-Path $installDir $oldDll
        if (Test-Path -LiteralPath $oldPath) { & $regasm $oldPath /unregister /silent | Out-Null }
    }
    Get-ChildItem -LiteralPath $installDir -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse

    $installedSource = Join-Path $installDir 'VisibilityToolsAddin.cs'
    $installedDll = Join-Path $installDir 'SwVisibilityTools.dll'
    Copy-Item -LiteralPath $source -Destination $installedSource -Force
    Copy-Item -LiteralPath $sldworksInterop -Destination (Join-Path $installDir 'SolidWorks.Interop.sldworks.dll') -Force
    Copy-Item -LiteralPath $swconstInterop -Destination (Join-Path $installDir 'SolidWorks.Interop.swconst.dll') -Force
    Copy-Item -LiteralPath $swpublishedInterop -Destination (Join-Path $installDir 'SolidWorks.Interop.swpublished.dll') -Force

    $compileArguments = @(
        '/nologo', '/target:library', '/platform:x64', '/optimize+', "/out:$installedDll",
        '/reference:System.dll', '/reference:System.Core.dll', '/reference:System.Windows.Forms.dll',
        "/reference:$sldworksInterop", "/reference:$swconstInterop", "/reference:$swpublishedInterop",
        $installedSource
    )
    & $compiler $compileArguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $installedDll)) {
        throw "插件编译失败，错误码：$LASTEXITCODE"
    }

    & $regasm $installedDll /codebase /tlb
    if ($LASTEXITCODE -ne 0) { throw "插件注册失败，错误码：$LASTEXITCODE" }

    $guid = '{0C6173E8-A351-4211-80A8-28D8518F7769}'
    $addin = "HKLM:\SOFTWARE\SolidWorks\Addins\$guid"
    $startup = "HKCU:\Software\SolidWorks\AddInsStartup\$guid"
    New-Item $addin -Force | Out-Null
    Set-Item $addin -Value 0
    New-ItemProperty $addin -Name Title -Value 'SolidWorks 装配体显示工具' -PropertyType String -Force | Out-Null
    New-ItemProperty $addin -Name Description -Value '一键显示隐藏零部件，一键恢复组件不透明' -PropertyType String -Force | Out-Null
    New-Item $startup -Force | Out-Null
    Set-Item $startup -Value 1

    $info = @(
        "SolidWorksPath=$($target.Path)",
        "SolidWorksYear=$($target.Year)",
        "InteropVersion=$apiVersion",
        "InstalledDll=$installedDll"
    )
    [IO.File]::WriteAllLines((Join-Path $installDir 'install-info.txt'), $info, [Text.Encoding]::UTF8)
    $yearText = if ($target.Year -gt 0) { "SW$($target.Year)" } else { '所选 SolidWorks' }
    [Windows.Forms.MessageBox]::Show("安装完成。`n目标：$yearText`nAPI：$apiVersion`n路径：$($target.Path)`n`n现在可以启动 SolidWorks。", '安装完成') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show($_.Exception.Message, '安装未完成') | Out-Null
    exit 1
}
