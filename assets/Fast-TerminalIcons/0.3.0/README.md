# Fast-TerminalIcons

Fast-TerminalIcons is a high-performance C# binary PowerShell module that adds
Terminal-Icons-compatible icons and colors to `Get-ChildItem` display without replacing
its output objects. `Where-Object`, `Select-Object`, `Remove-Item`, and other pipeline
operations continue to receive ordinary `System.IO.FileInfo` and
`System.IO.DirectoryInfo` instances.

The embedded default theme is generated from Terminal-Icons 0.11.0's `devblackops`
icon and color themes. Import does not load the 9,253-entry glyph table, scan theme
directories, read preferences, or write CLIXML.

## Architecture

- `tools/Generate-ThemeData.ps1` resolves the upstream named glyphs and RGB values at
  build-data generation time. The committed C# output contains 132 referenced glyph
  strings, 45 special-directory icons, 73 special-filename icons, and 281 extension
  icons rather than the full 9,253-entry glyph table. Its header records SHA-256 hashes
  for all three Terminal-Icons source files.
- Six case-insensitive C# dictionaries hold pre-resolved icon and ANSI color strings.
  Exact filenames are checked first; extension suffixes are checked longest first.
  The dictionaries initialize lazily on first formatting and require no runtime data
  files.
- The binary initializer builds one public `ExtendedTypeDefinition` and, on PowerShell
  7.4-7.6, prepends its compiled view through a version-gated copy-on-write overlay of
  the in-memory format database. This avoids `Update-FormatData` on the fast path. The
  packaged 1.8 KB format XML is the supported fallback for other PowerShell versions.
- The formatter receives the original `FileInfo` or `DirectoryInfo`. Normal entries use
  the attributes already populated by `Get-ChildItem`; only reparse points resolve link
  type and target. No wrapper object or replacement `Get-ChildItem` command is involved.

## Requirements

- Windows x64
- PowerShell 7.4, 7.5, or 7.6 (PowerShell 5.1 is best-effort compatible)
- A [Nerd Font](https://www.nerdfonts.com/) configured in the terminal, such as
  CaskaydiaCove Nerd Font or MesloLGS NF

Unicode glyphs are embedded as .NET UTF-16 strings, including surrogate pairs for
supplementary-plane Nerd Font characters. ANSI true-color sequences are emitted as
terminal control sequences, not counted as file-name content; PowerShell 7 handles
their display width and strips or preserves ANSI according to `$PSStyle.OutputRendering`.

## Build and install

```powershell
pwsh -NoProfile -File .\Build.ps1 -Configuration Release

$source = '.\artifacts\Fast-TerminalIcons\0.3.0'
$destination = Join-Path $HOME 'Documents\PowerShell\Modules\Fast-TerminalIcons\0.3.0'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item "$source\*" $destination -Recurse -Force
Import-Module (Join-Path $destination 'Fast-TerminalIcons.dll')
```

Use the exact binary path instead of installing when evaluating locally:

```powershell
Import-Module .\artifacts\Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll
Get-ChildItem
```

For Profile use, add the exact binary path after validating the module interactively:

```powershell
$fastTerminalIcons = Join-Path $HOME 'Documents\PowerShell\Modules\Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll'
Import-Module $fastTerminalIcons
```

The package includes and tests a conventional `Fast-TerminalIcons.psd1` manifest.
`Import-Module Fast-TerminalIcons` and importing that manifest are functionally valid,
but PowerShell's manifest-to-binary dispatch adds about 62 ms on the benchmark runner.
The DLL is itself a native PowerShell binary module and is the documented performance
entry point used for the cold-import acceptance target.

## Bordered table

`Format-FastTerminalTable` buffers a directory listing and renders a width-aware,
Nushell-style table with rounded borders, compact file types, human-readable IEC sizes,
timestamps, and the embedded icons:

```powershell
Get-ChildItem | Format-FastTerminalTable
Get-ChildItem -Force | Format-FastTerminalTable
```

The bordered command intentionally returns one rendered string. Keep ordinary
`Get-ChildItem` for object pipelines such as `Where-Object`, `Select-Object`, and
`Remove-Item`. A convenient profile can expose bordered `ls`, `ll`, and `la` functions
while reserving `lso` for the unformatted object stream.

Do not import Terminal-Icons and Fast-TerminalIcons in the same session: both register
a default file-system format view, and whichever view has precedence controls display.

## Read-only configuration

Set these environment variables **before the first formatted item in a process**. They
are read once and never persisted:

- `FAST_TERMINALICONS_PLAIN=1`: disable icons and ANSI colors.
- `FAST_TERMINALICONS_NO_ICONS=1`: keep colors but omit glyphs.
- `FAST_TERMINALICONS_NO_COLOR=1` or standard `NO_COLOR=1`: keep glyphs but omit ANSI.

PowerShell cannot reliably detect the font selected by its host. If no Nerd Font is
installed, glyphs may appear as boxes; use `FAST_TERMINALICONS_PLAIN=1` as the fallback.

## Resolution behavior

Resolution is case-insensitive with `StringComparer.OrdinalIgnoreCase`:

1. symlink or junction mapping, when applicable;
2. exact special filename;
3. longest matching compound extension;
4. ordinary extension;
5. default file or directory icon.

Directories use exact special-directory names followed by the default directory icon.
Icon and color maps resolve independently, matching Terminal-Icons behavior when only
one theme contains an exact key. Reparse-point target lookup occurs only for links;
normal entries require no additional per-entry filesystem query.

## Differences from Terminal-Icons 0.11.0

- The default `devblackops` theme is immutable and embedded. There is no theme editor,
  preference migration, or CLIXML persistence.
- PowerShell 7.4-7.6 receives a version-gated in-memory format-database overlay so import
  does not parse XML or rebuild all format data. Other PowerShell versions use the
  packaged format XML through the supported API; PowerShell 5.1 therefore works but is
  slower and remains best-effort.
- Longest compound extensions are checked before ordinary extensions. This fixes the
  original script's last-extension-first behavior while retaining all 0.11.0 mappings.
- The concise default table view is icon-enabled. Explicit `Format-List`/`Format-Wide`
  use PowerShell's standard views.
- Configuration is process-local and read-only through environment variables.

## Regenerate embedded data

The generated C# file is committed, so normal builds do not require Terminal-Icons.
To reproduce it from an installed 0.11.0 module:

```powershell
pwsh -NoProfile -File .\tools\Generate-ThemeData.ps1 `
  -TerminalIconsPath 'C:\path\to\Terminal-Icons\0.11.0'
```

The generated header records SHA-256 hashes of all three source files. See
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) for attribution.

## Test and benchmark

```powershell
pwsh -NoProfile -File .\tests\Test-Module.ps1
pwsh -NoProfile -File .\benchmarks\Benchmark.ps1 -Iterations 25
```

The benchmark starts a fresh `pwsh -NoProfile` process for every import sample. It
reports the binary entry point, manifest wrapper, and Terminal-Icons independently;
in-process import duration is separate from end-to-end process duration and a no-import
process baseline. Hot-path timing compares 100/1,000/10,000 already-enumerated items.

### Measured result on the acceptance runner

Windows x64, PowerShell 7.6.4 / .NET 10.0.10, AMD64 Family 26 Model 68. Import values
are 25 fresh-process samples; hot values are 7 samples; p95 uses nearest rank. The four
cold cases rotate execution order and use separate `APPDATA`/`LOCALAPPDATA`/`HOME`
sandboxes. Full raw samples and method metadata are in
`benchmarks/results/latest.json`.

| Import inside fresh process | p50 | p95 |
| --- | ---: | ---: |
| Fast direct binary | 10.171 ms | 11.401 ms |
| Fast manifest wrapper | 72.148 ms | 75.684 ms |
| Terminal-Icons 0.11.0 | 412.636 ms | 437.032 ms |

The direct binary is 40.57× faster than Terminal-Icons at p50 and satisfies both the
≤40 ms acceptance target and ≤25 ms ideal target. Parent-observed end-to-end process
p50/p95 was 200.568/245.850 ms for no import, 244.706/304.048 ms for the direct binary,
300.114/350.608 ms for the manifest wrapper, and 653.097/718.507 ms for Terminal-Icons.
Process startup is therefore reported rather than attributed to module import.

| Already-enumerated items | Fast p50 / p95 | Terminal-Icons p50 / p95 | p50 speedup |
| ---: | ---: | ---: | ---: |
| 100 | 0.518 / 3.362 ms | 10.911 / 13.691 ms | 21.06× |
| 1,000 | 5.527 / 8.459 ms | 79.465 / 106.693 ms | 14.38× |
| 10,000 | 46.078 / 48.258 ms | 682.736 / 819.102 ms | 14.82× |

After 25 cold imports, both Fast entry points left 0 files / 0 bytes in their isolated
configuration sandboxes. Terminal-Icons left 4 files / 184,300 bytes.

## Uninstall, rollback, and replacement

```powershell
Remove-Module Fast-TerminalIcons -ErrorAction SilentlyContinue
Remove-Item (Join-Path $HOME 'Documents\PowerShell\Modules\Fast-TerminalIcons') -Recurse
```

To roll back, remove the Fast-TerminalIcons import from the Profile, start a new
PowerShell process (format tables are process-scoped), and import Terminal-Icons again.
Always validate replacement in a fresh shell before changing the Profile.

For a safe replacement, keep Terminal-Icons installed initially. In a fresh
`pwsh -NoProfile` process, import the exact Fast DLL path, run `Get-ChildItem`, and test a
pipeline such as `Get-ChildItem | Where-Object Extension -eq '.ps1'`. Only after that
succeeds should you manually replace the Terminal-Icons import in your Profile with the
exact Fast DLL import shown above. Never load both modules in that Profile. Roll back by
restoring the original Terminal-Icons line and starting another fresh process.
