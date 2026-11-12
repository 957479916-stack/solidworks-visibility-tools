# SolidWorks Visibility Tools Skill

A Codex Skill for building, validating, packaging, and explicitly authorized installation of a SolidWorks assembly visibility add-in across SW2017+ environments.

The generated add-in provides two commands:

- Show all hidden assembly components without resolving suppressed components.
- Restore component-level opacity in the active configuration while preserving colors.

## Compatibility

The add-in targets 64-bit SOLIDWORKS 2017 and later. The release contains C# source; `Install.ps1` detects a local SolidWorks installation and compiles against that installation's official `api\redist` Interop assemblies. This avoids shipping a DLL tied to another computer's SolidWorks type library. The current implementation was load-tested with SOLIDWORKS 2019 SP5; other releases should be tested before making release-specific verification claims.

## Install The Skill

Install the `solidworks-visibility-tools` subdirectory as a Codex Skill, or ask Codex to install this skill from the GitHub repository URL.

## Example Requests

```text
Use $solidworks-visibility-tools to build a clean release ZIP.
Use $solidworks-visibility-tools to verify an existing release directory.
Use $solidworks-visibility-tools to install the add-in after I close SolidWorks.
```

## Build A Release

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\solidworks-visibility-tools\scripts\build_release.ps1 `
  -OutputDirectory C:\Temp\SolidWorksVisibilityTools-Release
```

Building does not modify SolidWorks or the registry. Installation is a separate action and requires administrator rights.

## Repository Layout

```text
solidworks-visibility-tools/
  SKILL.md
  agents/openai.yaml
  scripts/build_release.ps1
  scripts/verify_release.ps1
  references/compatibility.md
  assets/plugin/VisibilityToolsAddin.cs
  assets/package/
```

## License

MIT
