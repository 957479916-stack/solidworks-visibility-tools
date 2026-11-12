# Compatibility Notes

## Architecture

The add-in uses the official strongly typed SolidWorks Interop assemblies. The GitHub release contains source instead of a precompiled plug-in DLL. During installation, it compiles against the selected computer's own `<SolidWorks>\api\redist` files, copies those exact dependencies beside the plug-in, and then registers the result.

This design replaces the failed late-bound design. A locally declared `ISwAddin` could instantiate, but dynamic SolidWorks API calls failed on SW2019 with `TYPE_E_ELEMENTNOTFOUND (0x8002802B)`.

Stable identifiers:

- Add-in class: `0C6173E8-A351-4211-80A8-28D8518F7769`
- ProgID: `SwVisibilityTools.Connect`
- Command group: `20261120`

The required methods existed by SolidWorks 2017: `SetAddinCallbackInfo2`, `GetCommandManager`, `CreateCommandGroup2`, `AddCommandItem2`, `GetComponents`, `GetMaterialPropertyValues2`, `SetMaterialPropertyValues2`, `ForceRebuild3`, and `GraphicsRedraw2`.

## Supported Environment

- 64-bit Windows and 64-bit SolidWorks 2017 or later
- .NET Framework 4.x with 64-bit `RegAsm.exe`
- Administrator rights for HKLM COM/add-in registration

The installer requires Interop API major version 25 or later, corresponding to SW2017+. It chooses the highest detected SolidWorks year by default. `-SolidWorksInstallDir` selects a different installation. Because the COM class has one CLSID and one `CodeBase`, a single installation can target only one SolidWorks Interop set at a time.

SW2019 SP5 with Interop `27.5.0.72` is the physically tested target. Treat other releases as architecturally supported until they are tested.

## Release Invariants

- The release must contain `Source\VisibilityToolsAddin.cs`, not a precompiled plug-in DLL.
- The installer must compile against the selected local `SolidWorks.Interop.*` assemblies and copy them beside the compiled plug-in.
- `Install.ps1` and `Uninstall.ps1` must be UTF-8 with BOM for Windows PowerShell 5.1.
- `Install.cmd` and `Uninstall.cmd` must be ASCII with CRLF line endings.
- The installer must compile to `%ProgramData%\SolidWorksVisibilityTools` before `RegAsm /codebase`.
- Never distribute the failed late-bound DLL or old SW2019-specific V1/V2 DLLs in the cross-version release.
