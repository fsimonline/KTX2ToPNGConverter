# ============================================================
#  Converts DDS and/or KTX2 texture files from directory A
#  to PNG files in directory B
# ============================================================

$script:ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigFile = Join-Path $script:ScriptDir "userConfig.ini"
$script:LogFile    = Join-Path $script:ScriptDir "logfile.txt"
$script:PresetDir  = Join-Path $script:ScriptDir "NTT-Presets"
$script:AppVersion = "0.3.4"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------
$C = @{
    Header    = 'Cyan'
    Border    = 'DarkCyan'
    Label     = 'Gray'
    Value     = 'White'
    Key       = 'Yellow'
    OK        = 'Green'
    Error     = 'Red'
    Skip      = 'DarkGray'
    Progress  = 'Cyan'
    Highlight = 'Cyan'
    Dim       = 'DarkGray'
}

# ------------------------------------------------------------
# UI Helper Functions
# ------------------------------------------------------------
function Wait-Interruptible {
    param([int]$Milliseconds)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $Milliseconds) {
        if ([Console]::KeyAvailable) {
            [Console]::ReadKey($true) | Out-Null
            break
        }
        Start-Sleep -Milliseconds 50
    }
}

function Write-Border {
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor $C.Border
}

function Write-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor $C.Border
    Write-Host "  |  _  _  _____  _  _   ___   |   ___   ___   ___            |" -ForegroundColor $C.Header
    Write-Host "  | | |/ /  | |  \ \/ / |__ \  |  |   \ |   \ / __|           |" -ForegroundColor $C.Header
    Write-Host "  | | ' <   | |   >  <   / /   |  | |)| | |)| \__ \           |" -ForegroundColor $C.Header
    Write-Host "  | |_|\_\  |_|  /_/\_\ |___|  |  |___/ |___/ \___/           |" -ForegroundColor $C.Header
    Write-Host "  |" -ForegroundColor $C.Border -NoNewline
    Write-Host "                            |                              " -ForegroundColor $C.Header -NoNewline
    Write-Host "|" -ForegroundColor $C.Border
    Write-Host "  |" -ForegroundColor $C.Border -NoNewline
    Write-Host ("  Texture -> PNG Converter  v" + $script:AppVersion).PadRight(59) -ForegroundColor $C.Dim -NoNewline
    Write-Host "|" -ForegroundColor $C.Border
    Write-Host "  +-----------------------------------------------------------+" -ForegroundColor $C.Border
    if ($Title) {
        Write-Host ""
        Write-Host "  $Title" -ForegroundColor $C.Header
    }
    Write-Host ""
}

function Write-MenuItem {
    param([string]$Key, [string]$Label, [string]$Value = "")
    Write-Host "  [" -ForegroundColor $C.Border -NoNewline
    Write-Host $Key -ForegroundColor $C.Key -NoNewline
    Write-Host "]  " -ForegroundColor $C.Border -NoNewline
    Write-Host $Label.PadRight(22) -ForegroundColor $C.Label -NoNewline
    if ($Value) {
        Write-Host " : " -ForegroundColor $C.Dim -NoNewline
        Write-Host $Value -ForegroundColor $C.Value
    } else {
        Write-Host ""
    }
}

function Write-ProgressBar {
    param([int]$Current, [int]$Total, [int]$Width = 40)
    $pct    = [int](($Current / $Total) * 100)
    $filled = [int](($Current / $Total) * $Width)
    $empty  = $Width - $filled
    $bar    = "[" + ("#" * $filled) + ("-" * $empty) + "]"
    Write-Host ("  " + $bar + "  $Current/$Total  ($pct%)") -ForegroundColor $C.Progress
}

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')  $Message"
    try {
        Add-Content -Path $script:LogFile -Value $line -ErrorAction Stop
    } catch {
        Write-Host "  [Log not writable]" -ForegroundColor $C.Dim
    }
}

# ------------------------------------------------------------
# Read INI
# ------------------------------------------------------------
function Read-Config {
    $cfg = @{}
    if (Test-Path $script:ConfigFile) {
        foreach ($line in Get-Content $script:ConfigFile) {
            if ($line -match '^([^=]+?)=(.*)$') {
                $cfg[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    return $cfg
}

# ------------------------------------------------------------
# Write INI
# ------------------------------------------------------------
function Write-Config {
    param([hashtable]$cfg)
    $paths        = Test-Paths $cfg
    $nvttResolved = Resolve-NvttPath $cfg['NvttExePath']
    @(
        "AppVersion=$($script:AppVersion)"
        "NvttExePath=$(if ($paths.NvttExePath) { $nvttResolved }         else { '' })"
        "InputDir=$(if ($paths.InputDir)        { $cfg['InputDir'] }     else { '' })"
        "OutputDir=$(if ($paths.OutputDir)      { $cfg['OutputDir'] }    else { '' })"
        "OverwriteExisting=$($cfg['OverwriteExisting'])"
        "InputFormat=$($cfg['InputFormat'])"
        "NttPresetFile=$(if ($paths.PresetFile) { $cfg['NttPresetFile'] } else { '' })"
        "LogFile=$($cfg['LogFile'])"
    ) | Set-Content -Path $script:ConfigFile -Encoding UTF8
    Write-Log "Configuration saved"
}

# ------------------------------------------------------------
# Normalize nvtt_export.exe path
# ------------------------------------------------------------
function Resolve-NvttPath {
    param([string]$path)
    $path = $path.Trim().TrimEnd('\')
    if ($path -notlike '*nvtt_export.exe') {
        $path = Join-Path $path 'nvtt_export.exe'
    }
    return $path
}

# ------------------------------------------------------------
# Validate paths — returns hashtable with bool per key
# ------------------------------------------------------------
function Test-Paths {
    param([hashtable]$cfg)
    $nvttResolved = if ($cfg['NvttExePath'] -notlike 'Enter path*') { Resolve-NvttPath $cfg['NvttExePath'] } else { $cfg['NvttExePath'] }
    $presetFile   = Join-Path $script:PresetDir $cfg['NttPresetFile']
    return @{
        NvttExePath  = (Test-Path $nvttResolved)
        InputDir     = (Test-Path $cfg['InputDir'])
        OutputDir    = (Test-Path $cfg['OutputDir'])
        PresetDir    = (Test-Path $script:PresetDir)
        PresetFile   = (Test-Path $presetFile)
    }
}

# ------------------------------------------------------------
# Truncate long path for display (keeps end of path)
# ------------------------------------------------------------
function Format-Path {
    param([string]$Path, [int]$MaxLen = 45)
    if ($Path.Length -le $MaxLen) { return $Path }
    return "..." + $Path.Substring($Path.Length - ($MaxLen - 3))
}

# ------------------------------------------------------------
# Prompt for value
# ------------------------------------------------------------
function Prompt-Value {
    param([string]$Label, [string]$Current)
    Write-Host ""
    Write-Host "  $Label" -ForegroundColor $C.Label
    if ($Current -and $Current -notlike 'Enter path*') {
        Write-Host "  Current: " -ForegroundColor $C.Dim -NoNewline
        Write-Host $Current -ForegroundColor $C.Value
        Write-Host "  (Enter = keep current)" -ForegroundColor $C.Dim
    }
    Write-Host ""
    $val = Read-Host "  > "
    if ([string]::IsNullOrWhiteSpace($val)) { return $Current }
    return $val.Trim().TrimEnd('\')
}

# ------------------------------------------------------------
# Configuration menu
# ------------------------------------------------------------
function Show-ConfigMenu {
    param([hashtable]$cfg)
    $failCount = @{ '1' = 0; '2' = 0; '3' = 0; '6' = 0 }
    while ($true) {
        $paths = Test-Paths $cfg

        Write-Header "SETTINGS"

        # [1] nvtt — red if not found
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "1" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "nvtt_export.exe  : " -ForegroundColor $C.Label -NoNewline
        Write-Host (Format-Path $cfg['NvttExePath']) -ForegroundColor $(if ($paths.NvttExePath) { $C.Value } else { $C.Error })

        # [2] Source — red if not found
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "2" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Source path      : " -ForegroundColor $C.Label -NoNewline
        Write-Host (Format-Path $cfg['InputDir']) -ForegroundColor $(if ($paths.InputDir) { $C.Value } else { $C.Error })

        # [3] Target — red if not found
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "3" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Target path      : " -ForegroundColor $C.Label -NoNewline
        Write-Host (Format-Path $cfg['OutputDir']) -ForegroundColor $(if ($paths.OutputDir) { $C.Value } else { $C.Error })

        # [4] Overwrite
        $owColor = if ($cfg['OverwriteExisting'] -eq 'ON') { 'Green' } else { 'Red' }
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "4" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Overwrite        : " -ForegroundColor $C.Label -NoNewline
        Write-Host $cfg['OverwriteExisting'] -ForegroundColor $owColor

        # [5] Input format toggle
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "5" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Toggle Input Ext : " -ForegroundColor $C.Label -NoNewline
        Write-Host $cfg['InputFormat'] -ForegroundColor $C.Value -NoNewline
        Write-Host "  (KTX2 / DDS / BOTH)" -ForegroundColor $C.Dim

        # Preset dir — info only, hardcoded, warn if missing
        $presetDirColor = if ($paths.PresetDir) { $C.Dim } else { $C.Error }
        Write-Host "  " -NoNewline
        Write-Host "     Preset dir     : " -ForegroundColor $C.Label -NoNewline
        Write-Host (Format-Path $script:PresetDir) -ForegroundColor $presetDirColor
        if (-not $paths.PresetDir) {
            Write-Host "       ! NTT-Presets folder missing - please recreate it next to the script" -ForegroundColor $C.Error
        }

        # [6] Preset filename — red if file not found in preset dir
        $presetFileColor = if ($paths.PresetFile) { $C.Value } else { $C.Error }
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "6" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Preset name      : " -ForegroundColor $C.Label -NoNewline
        Write-Host $cfg['NttPresetFile'] -ForegroundColor $presetFileColor

        # [7] Log file
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "7" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Log file         : " -ForegroundColor $C.Label -NoNewline
        Write-Host (Format-Path $cfg['LogFile']) -ForegroundColor $C.Value

        Write-Host ""
        Write-Border
        Write-MenuItem "S" "Save & back"
        Write-MenuItem "X" "Cancel"
        Write-Border
        Write-Host ""

        $choice = Read-Host "  Choice"
        switch ($choice.ToUpper()) {
            '1' {
                $val = Prompt-Value "Path to nvtt_export.exe  (folder only or full path incl. nvtt_export.exe)" $cfg['NvttExePath']
                if ($val -notlike 'Enter path*') {
                    $resolved = Resolve-NvttPath $val
                    if (Test-Path $resolved) {
                        $cfg['NvttExePath'] = $resolved
                        $failCount['1'] = 0
                        Write-Host "  --> OK: $($cfg['NvttExePath'])" -ForegroundColor $C.OK
                        Start-Sleep -Milliseconds 800
                    } else {
                        $cfg['NvttExePath'] = $resolved
                        $failCount['1']++
                        Write-Host "  --> Not found: $resolved" -ForegroundColor $C.Error
                        if ($failCount['1'] -ge 2) { Write-Host "      Tip: Press [H] in the main menu for help." -ForegroundColor $C.Dim }
                        Read-Host "  Press Enter to continue"
                    }
                }
            }
            '2' {
                $val = Prompt-Value "Source path" $cfg['InputDir']
                if ($val -notlike 'Enter path*') {
                    if (Test-Path $val) {
                        $cfg['InputDir'] = $val
                        $failCount['2'] = 0
                        Write-Host "  --> OK: $($cfg['InputDir'])" -ForegroundColor $C.OK
                        Start-Sleep -Milliseconds 800
                    } else {
                        $cfg['InputDir'] = $val
                        $failCount['2']++
                        Write-Host "  --> Not found: $val" -ForegroundColor $C.Error
                        if ($failCount['2'] -ge 2) { Write-Host "      Tip: Press [H] in the main menu for help." -ForegroundColor $C.Dim }
                        Read-Host "  Press Enter to continue"
                    }
                }
            }
            '3' {
                $val = Prompt-Value "Target path" $cfg['OutputDir']
                if ($val -notlike 'Enter path*') {
                    if (Test-Path $val) {
                        $cfg['OutputDir'] = $val
                        $failCount['3'] = 0
                        Write-Host "  --> OK: $($cfg['OutputDir'])" -ForegroundColor $C.OK
                        Start-Sleep -Milliseconds 800
                    } else {
                        $cfg['OutputDir'] = $val
                        $failCount['3']++
                        Write-Host "  --> Not found: $val" -ForegroundColor $C.Error
                        if ($failCount['3'] -ge 2) { Write-Host "      Tip: Press [H] in the main menu for help." -ForegroundColor $C.Dim }
                        Read-Host "  Press Enter to continue"
                    }
                }
            }
            '4' {
                $cfg['OverwriteExisting'] = if ($cfg['OverwriteExisting'] -eq 'ON') { 'OFF' } else { 'ON' }
                Write-Host "  --> Overwrite: $($cfg['OverwriteExisting'])" -ForegroundColor $C.Highlight
                Start-Sleep -Milliseconds 600
            }
            '5' {
                $fmt = $cfg['InputFormat']
                $cfg['InputFormat'] = switch ($fmt) {
                    'KTX2' { 'DDS' }
                    'DDS'  { 'BOTH' }
                    'BOTH' { 'KTX2' }
                    default { 'KTX2' }
                }
                Write-Host "  --> Input format changed to: $($cfg['InputFormat'])" -ForegroundColor $C.Highlight
                Write-Host "      (press [5] again to cycle: KTX2 -> DDS -> BOTH)" -ForegroundColor $C.Dim
                Read-Host "  Press Enter to continue"
            }
            '6' {
                Write-Host ""
                Write-Host "  Preset name  (filename only, e.g. MyPreset.dpf)" -ForegroundColor $C.Label
                Write-Host "  Current: " -ForegroundColor $C.Dim -NoNewline
                Write-Host $cfg['NttPresetFile'] -ForegroundColor $C.Value
                Write-Host "  (Enter = keep current)" -ForegroundColor $C.Dim
                Write-Host ""
                $raw = Read-Host "  > "
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $cfg['NttPresetFile'] = $raw.Trim()
                }
                $dpf = Join-Path $script:PresetDir $cfg['NttPresetFile']
                if (Test-Path $dpf) {
                    $failCount['6'] = 0
                    Write-Host "  --> OK: $($cfg['NttPresetFile']) found in preset dir" -ForegroundColor $C.OK
                    Read-Host "  Press Enter to continue"
                } else {
                    $failCount['6']++
                    Write-Host "  --> $($cfg['NttPresetFile']) not found in preset dir" -ForegroundColor $C.Error
                    Write-Host "      Drop the file into $($script:PresetDir)" -ForegroundColor $C.Dim
                    Write-Host "      Reminder: preset files must have the extension .dpf  (e.g. myPreset.dpf)" -ForegroundColor $C.Dim
                    if ($failCount['6'] -ge 2) { Write-Host "      Tip: Press [H] in the main menu for help." -ForegroundColor $C.Dim }
                    Read-Host "  Press Enter to continue"
                }
            }
            '7' { $cfg['LogFile'] = Prompt-Value "Log file" $cfg['LogFile'] }
            'S' { Write-Config $cfg; return $cfg }
            'X' { return $null }
        }
    }
}

# ------------------------------------------------------------
# Conversion
# ------------------------------------------------------------
function Start-Conversion {
    param([hashtable]$cfg)

    $nvtt      = if ($cfg['NvttExePath'] -notlike 'Enter path*') { Resolve-NvttPath $cfg['NvttExePath'] } else { $cfg['NvttExePath'] }
    $inputDir  = $cfg['InputDir']
    $outputDir = $cfg['OutputDir']
    $overwrite = $cfg['OverwriteExisting']

    # Preset: use if .dpf exists in preset dir
    $presetArg = ""
    $dpfPath   = Join-Path $script:PresetDir $cfg['NttPresetFile']
    if ((Test-Path $script:PresetDir) -and (Test-Path $dpfPath)) {
        $presetArg = "--preset `"$dpfPath`""
    }

    Write-Header "CONVERSION"

    if (-not (Test-Path $nvtt)) {
        Write-Host "  ERROR: nvtt_export.exe not found:" -ForegroundColor $C.Error
        Write-Host "  $nvtt" -ForegroundColor $C.Error
        Write-Log "ERROR: nvtt_export.exe not found: $nvtt"
        Write-Host ""; Read-Host "  Press Enter to continue"
        return
    }
    if (-not (Test-Path $inputDir)) {
        Write-Host "  ERROR: Source path not found: $inputDir" -ForegroundColor $C.Error
        Write-Log "ERROR: Source path not found: $inputDir"
        Write-Host ""; Read-Host "  Press Enter to continue"
        return
    }
    if (-not (Test-Path $outputDir)) {
        Write-Host "  ERROR: Target path not found: $outputDir" -ForegroundColor $C.Error
        Write-Log "ERROR: Target path not found: $outputDir"
        Write-Host ""; Read-Host "  Press Enter to continue"
        return
    }

    $format = $cfg['InputFormat']
    $files = @()
    if ($format -eq 'KTX2' -or $format -eq 'BOTH') {
        $files += Get-ChildItem -Path $inputDir -Filter "*.ktx2" -File
    }
    if ($format -eq 'DDS' -or $format -eq 'BOTH') {
        $files += Get-ChildItem -Path $inputDir -Filter "*.dds" -File
    }
    if ($files.Count -eq 0) {
        Write-Host "  No .$($format.ToLower()) files found in:" -ForegroundColor Yellow
        Write-Host "  $inputDir" -ForegroundColor $C.Dim
        Write-Log "No files found for format: $format"
        Write-Host ""; Read-Host "  Press Enter to continue"
        return
    }

    Write-Host "  Source  : " -ForegroundColor $C.Label -NoNewline
    Write-Host $inputDir -ForegroundColor $C.Value
    Write-Host "  Target  : " -ForegroundColor $C.Label -NoNewline
    Write-Host $outputDir -ForegroundColor $C.Value
    Write-Host "  Format  : " -ForegroundColor $C.Label -NoNewline
    Write-Host $format -ForegroundColor $C.Value
    Write-Host "  Preset  : " -ForegroundColor $C.Label -NoNewline
    if ($presetArg) {
        Write-Host $cfg['NttPresetFile'] -ForegroundColor $C.OK
    } else {
        Write-Host "none ($($cfg['NttPresetFile']) not found in $($script:PresetDir))" -ForegroundColor 'Yellow'
    }
    Write-Host "  Files   : " -ForegroundColor $C.Label -NoNewline
    Write-Host $files.Count -ForegroundColor $C.Value
    Write-Host ""
    Write-Border
    Write-Host ""

    Write-Log "Starting conversion: $($files.Count) files | preset: $(if ($presetArg) { $dpfPath } else { 'none' })"

    $success = 0
    $failed  = 0
    $skipped = 0
    $i       = 0

    foreach ($file in $files) {
        $i++
        $cleanName = [System.IO.Path]::GetFileNameWithoutExtension($file.BaseName)
        $outFile   = Join-Path $outputDir ($cleanName + ".png")

        Write-ProgressBar -Current $i -Total $files.Count
        Write-Host "  $($file.Name)" -ForegroundColor $C.Label

        if ((Test-Path $outFile) -and $overwrite -eq 'OFF') {
            Write-Host "  >> Skipped (overwrite is disabled)" -ForegroundColor $C.Skip
            Write-Log "Skipped: $($file.Name)"
            $skipped++
            Write-Host ""
            continue
        }

        # KTX2: copy to temp with clean extension (FreeImage cannot handle .PNG.KTX2)
        # DDS: pass directly — no double extension issue
        if ($file.Extension -eq '.ktx2') {
            $tempFile = Join-Path $env:TEMP ($file.BaseName + ".ktx2")
            Copy-Item -Path $file.FullName -Destination $tempFile -Force
            $inputArg = $tempFile
        } else {
            $tempFile = $null
            $inputArg = $file.FullName
        }

        $arguments = "`"$inputArg`" --output `"$outFile`""
        if ($presetArg) { $arguments = "$presetArg $arguments" }

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo.FileName               = $nvtt
        $proc.StartInfo.Arguments              = $arguments
        $proc.StartInfo.UseShellExecute        = $false
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError  = $true
        $proc.StartInfo.CreateNoWindow         = $true
        $proc.Start() | Out-Null
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($tempFile) { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue }

        if ($proc.ExitCode -eq 0 -and (Test-Path $outFile)) {
            Write-Host "  >> OK" -ForegroundColor $C.OK
            Write-Log "OK: $($file.Name)"
            $success++
        } else {
            Write-Host "  >> ERROR (Exit-Code: $($proc.ExitCode))" -ForegroundColor $C.Error
            if ($stderr) { Write-Host "     $stderr" -ForegroundColor DarkYellow }
            Write-Log "ERROR: $($file.Name) (Exit-Code: $($proc.ExitCode)) | $stderr"
            $failed++
        }
        Write-Host ""
    }

    Write-Border
    Write-Host ""
    Write-Host "  DONE" -ForegroundColor $C.Header
    Write-Host ""
    Write-Host "  OK            : " -ForegroundColor $C.Label -NoNewline
    Write-Host $success -ForegroundColor $C.OK
    Write-Host "  Errors        : " -ForegroundColor $C.Label -NoNewline
    Write-Host $failed -ForegroundColor $(if ($failed -gt 0) { $C.Error } else { $C.OK })
    Write-Host "  Skipped       : " -ForegroundColor $C.Label -NoNewline
    Write-Host $skipped -ForegroundColor $C.Dim
    Write-Host ""
    Write-Border
    Write-Log "Done: $success OK, $failed errors, $skipped skipped"
    Write-Host ""
    Read-Host "  Press Enter to continue"
}

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------
function Show-Help {
    Write-Header "HELP"
    Write-Host "  QUICK START" -ForegroundColor $C.Header
    Write-Host ""
    Write-Host "  1. Go to Settings [2] and configure:" -ForegroundColor $C.Label
    Write-Host ""
    Write-Host "     [1]  Path to nvtt_export.exe" -ForegroundColor $C.Value
    Write-Host "          Path to NVIDIA Texture Converter nvtt_export.exe" -ForegroundColor $C.Dim
    Write-Host "     [2]  Source path - folder containing your texture files" -ForegroundColor $C.Value
    Write-Host "     [3]  Target path - folder where .png files will be saved" -ForegroundColor $C.Value
    Write-Host "     [4]  Overwrite ON  - existing .png files will be overwritten" -ForegroundColor $C.Value
    Write-Host "          Overwrite OFF - existing .png files will be skipped" -ForegroundColor $C.Dim
    Write-Host "     [5]  Input format - KTX2 / DDS / BOTH (cycles on each press)" -ForegroundColor $C.Value
    Write-Host "     [6]  Preset name - filename of the preset to apply (e.g. MyPreset.dpf)" -ForegroundColor $C.Value
    Write-Host "          Save a preset in NVIDIA Texture Tools Exporter and drop it" -ForegroundColor $C.Dim
    Write-Host "          into the NTT-Presets folder next to this script." -ForegroundColor $C.Dim
    Write-Host "     [7]  Log file path" -ForegroundColor $C.Value
    Write-Host ""
    Write-Host "  2. Press [S] to save your settings." -ForegroundColor $C.Label
    Write-Host "  3. Press [1] in the main menu to start the conversion." -ForegroundColor $C.Label
    Write-Host ""
    Write-Border
    Write-Host "  NOTES" -ForegroundColor $C.Header
    Write-Host "  - All files of the selected format in the source folder are processed" -ForegroundColor $C.Dim
    Write-Host "  - A logfile.txt is written next to this script" -ForegroundColor $C.Dim
    Write-Host "  - Settings are saved in userConfig.ini next to this script" -ForegroundColor $C.Dim
    Write-Host ""
    Write-Border
    Write-Host ""
    Read-Host "  Press Enter to go back"
}

# ------------------------------------------------------------
# Main menu
# ------------------------------------------------------------
function Show-MainMenu {
    param([hashtable]$cfg)
    while ($true) {
        $paths  = Test-Paths $cfg
        $allOK  = $paths.NvttExePath -and $paths.InputDir -and $paths.OutputDir

        Write-Header ""
        Write-Border
        Write-Host ""
        Write-MenuItem "1" "Start conversion"
        Write-MenuItem "2" "Settings"
        Write-MenuItem "H" "Help"
        Write-MenuItem "X" "Exit"
        Write-Host ""
        Write-Border

        # Status line below menu
        if (-not $allOK) {
            Write-Host ""
            Write-Host "  ! Path not found: " -ForegroundColor $C.Error -NoNewline
            $issues = @()
            if (-not $paths.NvttExePath) { $issues += "nvtt_export.exe" }
            if (-not $paths.InputDir)    { $issues += "Source path" }
            if (-not $paths.OutputDir)   { $issues += "Target path" }
            Write-Host ($issues -join ", ") -ForegroundColor $C.Error
            Write-Host "    Go to Settings [2] to fix highlighted paths." -ForegroundColor $C.Dim
        }

        Write-Host ""
        $choice = Read-Host "  Choice"
        switch ($choice.ToUpper()) {
            '1' { Start-Conversion $cfg }
            '2' {
                $updated = Show-ConfigMenu $cfg
                if ($updated) { $cfg = $updated }
            }
            'H' { Show-Help }
            'X' { Write-Log "Script terminated"; exit 0 }
        }
    }
}

# ============================================================
# START
# ============================================================

Write-Log "Script started v$($script:AppVersion)"
$cfg = Read-Config

if (-not $cfg['NvttExePath'])        { $cfg['NvttExePath']       = 'Enter path to NVIDIA Texture Tools Exporter' }
if (-not $cfg['InputDir'])           { $cfg['InputDir']          = 'Enter path to source directory' }
if (-not $cfg['OutputDir'])          { $cfg['OutputDir']         = 'Enter path to target directory' }
if (-not $cfg['OverwriteExisting'])  { $cfg['OverwriteExisting'] = 'ON' }
if (-not $cfg['InputFormat'])        { $cfg['InputFormat']       = 'KTX2' }
if (-not $cfg['LogFile'])            { $cfg['LogFile']           = $script:LogFile }
if (-not $cfg['NttPresetFile'])      { $cfg['NttPresetFile']     = '' }

# Warn if NTT-Presets folder is missing
if (-not (Test-Path $script:PresetDir)) {
    Write-Header "WARNING"
    Write-Host "  NTT-Presets folder not found:" -ForegroundColor $C.Error
    Write-Host "  $($script:PresetDir)" -ForegroundColor $C.Dim
    Write-Host ""
    Write-Host "  Please create this folder and place your .dpf preset files in it." -ForegroundColor $C.Label
    Write-Host "  Expected presets: default.dpf, MSFS2024-sRGBToLinear.dpf" -ForegroundColor $C.Dim
    Write-Log "WARNING: NTT-Presets folder not found: $($script:PresetDir)"
    Read-Host "  Press Enter to continue"
}

# Warn if no preset is selected
if ([string]::IsNullOrWhiteSpace($cfg['NttPresetFile'])) {
    Write-Header "WARNING"
    Write-Host "  No preset selected." -ForegroundColor 'Yellow'
    Write-Host ""
    Write-Host "  Conversion will run without an NTT preset." -ForegroundColor $C.Label
    Write-Host "  Go to Settings [6] to select a preset (e.g. MSFS2024-sRGBToLinear.dpf)." -ForegroundColor $C.Dim
    Write-Log "WARNING: No NTT preset selected"
    Read-Host "  Press Enter to continue"
}

if (-not (Test-Path $script:ConfigFile)) {
    Write-Header "FIRST SETUP"
    Write-Host "  No configuration found." -ForegroundColor Yellow
    Write-Host "  Please enter your settings..." -ForegroundColor $C.Dim
    Start-Sleep 1
    $updated = Show-ConfigMenu $cfg
    if ($updated) { $cfg = $updated } else { exit 0 }
}

Show-MainMenu $cfg