# KTX2 to PNG Converter

A PowerShell command-line tool for batch converting `.ktx2` texture files from a source directory into `.png` files in a target directory, using the [NVIDIA Texture Tools Exporter](https://developer.nvidia.com/texture-tools-exporter).

---

> **Note:** This is a personal tool released as-is. It has not been thoroughly tested. Use at your own risk. Pull requests, feature requests and issue reports are not accepted. Feel free to fork.

## Features

- Batch converts all `.ktx2` files in a source directory to `.png`
- Handles double-extension filenames (e.g. `TEXTURE.PNG.KTX2`) automatically
- Interactive menu with colored output and per-file progress bar
- Settings are saved to `userConfig.ini` — no command-line arguments needed
- Skips existing output files (configurable)
- Writes a `logfile.txt` for traceability

---

## Requirements

> **Windows only** — this tool depends on `nvtt_export.exe` which is a Windows-only application.

- Windows 10 or later
- PowerShell 5.1 or later
- [NVIDIA Texture Tools Exporter](https://developer.nvidia.com/texture-tools-exporter) (`nvtt_export.exe`)

---

## Installation

1. Download `Convert-KTX2-to-PNG.bat` and `Convert-KTX2-to-PNG.ps1`
2. Place both files in the same folder
3. Double-click `Convert-KTX2-to-PNG.bat` to launch

> Advanced users can also run the `.ps1` directly from PowerShell.

---

## First Run

On first launch, no `userConfig.ini` exists yet. The tool goes directly to the **Settings** screen:

```
  +---------------------------------------------------------+
  |  _  _ _____ _  _  ___     |
  | | |/ /_   _\ \/ /___ \    |
  | | ' /  | |  >  <  __) |   |
  | | . \  | | / /\ \/ __/    |
  | |_|\_\ |_|/_/  \_\_____|  |
  |                           |
  |  KTX2 -> PNG Converter  v0.3
  +---------------------------------------------------------+

  SETTINGS

  [1]  nvtt_export.exe        : C:\Program Files\NVIDIA Corporation\...
  [2]  Source path (KTX2)     : UNDEFINED
  [3]  Target path (PNG)      : UNDEFINED
  [4]  Overwrite              : ON
  [5]  Log file               : C:\...\logfile.txt

  +---------------------------------------------------------+
  [S]  Save & back
  [X]  Cancel
  +---------------------------------------------------------+
```

---

## Settings

| Key | Description |
|-----|-------------|
| `nvtt_export.exe` | Path to the NVIDIA Texture Tools executable. You can enter the folder path — the tool appends `\nvtt_export.exe` automatically. |
| `Source path (KTX2)` | Directory containing the `.ktx2` files to convert. |
| `Target path (PNG)` | Directory where converted `.png` files will be saved. Created automatically if it does not exist. |
| `Overwrite` | `ON` — existing `.png` files are overwritten. `OFF` — existing files are skipped. Toggle with key `4`. |
| `Log file` | Path to the log file. Defaults to `logfile.txt` in the script directory. |

Settings are stored in `userConfig.ini` next to the script:

```ini
AppVersion=0.3
NvttExePath=F:\Tools\NVIDIA Texture Tools\nvtt_export.exe
InputDir=F:\Textures\KTX2
OutputDir=F:\Textures\PNG
OverwriteExisting=ON
LogFile=F:\Tools\converter\logfile.txt
```

---

## Conversion

Press `1` in the main menu to start. The tool shows a progress bar for each file:

```
  CONVERSION

  Source  : F:\Textures\KTX2
  Target  : F:\Textures\PNG
  Files   : 7

  +---------------------------------------------------------+

  [########--------------------------------]  2/7  (28%)
  TEXTURE_ALBEDO.PNG.KTX2
  >> OK

  [################------------------------]  4/7  (57%)
  TEXTURE_NORMAL.PNG.KTX2
  >> OK

  ...

  +---------------------------------------------------------+

  DONE

  OK            : 7
  Errors        : 0
  Skipped       : 0
```

---

## How it handles double-extension filenames

Some KTX2 textures use double extensions like `TEXTURE.PNG.KTX2`.  
NVIDIA's FreeImage library identifies file formats by extension and fails on `.PNG.KTX2`.

The tool works around this by copying each file to `%TEMP%` with a clean `.ktx2` extension before passing it to `nvtt_export.exe`, then deletes the temp file afterwards.

---

## Files

| File | Description |
|------|-------------|
| `Convert-KTX2-to-PNG.bat` | Launcher - double-click to run |
| `Convert-KTX2-to-PNG.ps1` | Main script |
| `userConfig.ini` | Settings file (auto-generated on first save) |
| `logfile.txt` | Conversion log (auto-generated) |

---

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Disclaimer

This tool is an independent, unofficial utility and is not affiliated with, endorsed by,
or associated with any third-party software vendor.

- This tool requires a third-party texture export utility (`nvtt_export.exe`) which must be downloaded and installed independently. This tool does not include or distribute any third-party software.
- The user is solely responsible for ensuring their use of this tool complies with any applicable third-party license terms.
- The author accepts no responsibility for any damage, data loss, or license violations resulting from the use of this software.
