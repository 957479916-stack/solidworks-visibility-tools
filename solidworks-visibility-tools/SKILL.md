---
name: solidworks-visibility-tools
description: Build, validate, package, install, or uninstall the SolidWorks 2017+ assembly visibility add-in that shows hidden components and restores component opacity. Use for this add-in and its source-based release artifacts, not for unrelated SolidWorks automation.
---

# SolidWorks Visibility Tools

Use the strongly typed source in `assets/plugin/VisibilityToolsAddin.cs`. The release installer must compile it against the target computer's own SolidWorks `api\redist` assemblies. Preserve these behavioral boundaries:

- `ShowAllHiddenComponents` changes hidden components to visible but never resolves suppressed components.
- `RestoreAllOpacity` clears component-level transparency in the active configuration and direct material channel while preserving colors. It does not remove face, body, part, or glass-material transparency.
- Keep the COM class GUID `0C6173E8-A351-4211-80A8-28D8518F7769` and ProgID `SwVisibilityTools.Connect` so an install upgrades the existing add-in instead of creating a duplicate.
- Do not distribute one precompiled DLL as universal. Runtime late binding produced `TYPE_E_ELEMENTNOTFOUND` on SW2019. Cross-version compatibility comes from install-time compilation against the selected local SolidWorks Interop assemblies.
- Target x64 .NET Framework 4.x and SolidWorks 2017 or later. State which versions were actually tested; do not describe untested releases as physically verified.

## Build Or Verify

Run `scripts/build_release.ps1` with a new output directory. It packages source and installer templates, validates them, and creates a ZIP. Use optional `-SolidWorksInstallDir` for a local compile smoke test. Do not overwrite an unrelated existing directory.

Run `scripts/verify_release.ps1` directly when reviewing an existing release directory. Treat a precompiled plug-in DLL, COM identity mismatch, missing install-time compiler/API guard, invalid PowerShell BOM, or non-CRLF CMD file as a release blocker.

Read [references/compatibility.md](references/compatibility.md) before changing COM declarations, API calls, compatibility claims, or installation behavior.

## Install Or Uninstall

Building and verification are read-only with respect to SolidWorks and the registry. Installation and uninstallation are separate, state-changing operations.

- Install or uninstall only when the user explicitly requests it.
- Require all `SLDWORKS.exe` processes to be closed; never force-close SolidWorks because models may have unsaved work.
- Use the generated `Install.cmd` or `Uninstall.cmd`. The installer detects the highest installed SolidWorks version by default; pass `-SolidWorksInstallDir` to `Install.ps1` to select another installation.
- The installer compiles and registers `%ProgramData%\SolidWorksVisibilityTools\SwVisibilityTools.dll`, with matching Interop DLLs copied beside it. One CLSID can target only one compiled installation at a time.
- Report registration or load failures exactly. Do not suggest disabling Windows security controls.

## Validation

At minimum, verify the package structurally with `verify_release.ps1`. When a supported SolidWorks installation is available and the user authorizes installation, also verify that SolidWorks remains responsive, the add-in appears in `Tools > Add-Ins`, and the `Assembly Display` command tab is created. Functional model tests should use a disposable assembly or a user-authorized copy.
