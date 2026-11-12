$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
try {
    if (Get-Process SLDWORKS -ErrorAction SilentlyContinue) { throw '请先完整退出 SolidWorks，再卸载插件。' }
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
        $child = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        exit $child.ExitCode
    }

    $installDir = Join-Path $env:ProgramData 'SolidWorksVisibilityTools'
    $regasm = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe'
    $guid = '{0C6173E8-A351-4211-80A8-28D8518F7769}'
    $inproc = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\CLSID\$guid\InprocServer32"
    $codeBase = (Get-ItemProperty -LiteralPath $inproc -ErrorAction SilentlyContinue).CodeBase
    if ($codeBase) {
        try {
            $registeredDll = ([Uri]$codeBase).LocalPath
            if (Test-Path -LiteralPath $registeredDll) { & $regasm $registeredDll /unregister /silent | Out-Null }
        } catch { }
    }
    foreach ($name in @('SwVisibilityTools.dll', 'SwVisibilityTools-Universal.dll')) {
        $dll = Join-Path $installDir $name
        if (Test-Path -LiteralPath $dll) { & $regasm $dll /unregister /silent | Out-Null }
    }
    Remove-Item -LiteralPath "HKLM:\SOFTWARE\SolidWorks\Addins\$guid" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "HKCU:\Software\SolidWorks\AddInsStartup\$guid" -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $installDir) { Remove-Item -LiteralPath $installDir -Recurse -Force }
    [Windows.Forms.MessageBox]::Show('SolidWorks 装配体显示工具已卸载。', '卸载完成') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show($_.Exception.Message, '卸载未完成') | Out-Null
    exit 1
}
