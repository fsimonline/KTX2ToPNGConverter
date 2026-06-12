# ============================================================
#  Convert-KTX2-to-PNG.ps1
#  Reads all .ktx2 files from directory A and
#  saves them as .png files in directory B
# ============================================================

$script:ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigFile = Join-Path $script:ScriptDir "userConfig.ini"
$script:LogFile    = Join-Path $script:ScriptDir "logfile.txt"
$script:AppVersion = "0.3"

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
function Write-Border {
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor $C.Border
}

function Write-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor $C.Border
    Write-Host "  |  _  _ _____ _  _  ___     |" -ForegroundColor $C.Header
    Write-Host "  | | |/ /_   _\ \/ /___ \    |" -ForegroundColor $C.Header
    Write-Host "  | | ' /  | |  >  <  __) |   |" -ForegroundColor $C.Header
    Write-Host "  | | . \  | | / /\ \/ __/    |" -ForegroundColor $C.Header
    Write-Host "  | |_|\_\ |_|/_/  \_\_____|  |" -ForegroundColor $C.Header
    Write-Host "  |                           |" -ForegroundColor $C.Header
    Write-Host "  |" -ForegroundColor $C.Border -NoNewline
    Write-Host ("  KTX2 -> PNG Converter  v" + $script:AppVersion).PadRight(58) -ForegroundColor $C.Dim -NoNewline
    Write-Host "" 
    Write-Host "  +---------------------------------------------------------+" -ForegroundColor $C.Border
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
    $pct     = [int](($Current / $Total) * 100)
    $filled  = [int](($Current / $Total) * $Width)
    $empty   = $Width - $filled
    $bar     = "[" + ("#" * $filled) + ("-" * $empty) + "]"
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
    @(
        "AppVersion=$($script:AppVersion)"
        "NvttExePath=$($cfg['NvttExePath'])"
        "InputDir=$($cfg['InputDir'])"
        "OutputDir=$($cfg['OutputDir'])"
        "OverwriteExisting=$($cfg['OverwriteExisting'])"
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
# Prompt for value
# ------------------------------------------------------------
function Prompt-Value {
    param([string]$Label, [string]$Current)
    Write-Host ""
    Write-Host "  $Label" -ForegroundColor $C.Label
    if ($Current -and $Current -ne 'UNDEFINED') {
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
    while ($true) {
        Write-Header "SETTINGS"
        Write-MenuItem "1" "nvtt_export.exe"  $cfg['NvttExePath']
        Write-MenuItem "2" "Source path (KTX2)" $cfg['InputDir']
        Write-MenuItem "3" "Target path (PNG)"  $cfg['OutputDir']
        $owColor = if ($cfg['OverwriteExisting'] -eq 'ON') { 'Green' } else { 'Red' }
        Write-Host "  [" -ForegroundColor $C.Border -NoNewline
        Write-Host "4" -ForegroundColor $C.Key -NoNewline
        Write-Host "]  " -ForegroundColor $C.Border -NoNewline
        Write-Host "Overwrite             : " -ForegroundColor $C.Label -NoNewline
        Write-Host $cfg['OverwriteExisting'] -ForegroundColor $owColor
        Write-MenuItem "5" "Log file"         $cfg['LogFile']
        Write-Host ""
        Write-Border
        Write-MenuItem "S" "Save & back"
        Write-MenuItem "X" "Cancel"
        Write-Border
        Write-Host ""

        $choice = Read-Host "  Choice"
        switch ($choice.ToUpper()) {
            '1' {
                $val = Prompt-Value "Path to nvtt_export.exe (folder or full path)" $cfg['NvttExePath']
                $cfg['NvttExePath'] = Resolve-NvttPath $val
                Write-Host "  --> $($cfg['NvttExePath'])" -ForegroundColor $C.Highlight
            }
            '2' { $cfg['InputDir']          = Prompt-Value "Source path (KTX2)"  $cfg['InputDir'] }
            '3' { $cfg['OutputDir']         = Prompt-Value "Target path (PNG)"     $cfg['OutputDir'] }
            '4' {
                $cfg['OverwriteExisting'] = if ($cfg['OverwriteExisting'] -eq 'ON') { 'OFF' } else { 'ON' }
                Write-Host "  --> Overwrite: $($cfg['OverwriteExisting'])" -ForegroundColor $C.Highlight
                Start-Sleep -Milliseconds 600
            }
            '5' { $cfg['LogFile']           = Prompt-Value "Log file"          $cfg['LogFile'] }
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

    $nvtt      = Resolve-NvttPath $cfg['NvttExePath']
    $inputDir  = $cfg['InputDir']
    $outputDir = $cfg['OutputDir']
    $overwrite = $cfg['OverwriteExisting']

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
        New-Item -ItemType Directory -Path $outputDir | Out-Null
        Write-Host "  Output directory created: $outputDir" -ForegroundColor $C.Dim
        Write-Log "Output directory created: $outputDir"
    }

    $files = Get-ChildItem -Path $inputDir -Filter "*.ktx2" -File
    if ($files.Count -eq 0) {
        Write-Host "  No .ktx2 files found in:" -ForegroundColor Yellow
        Write-Host "  $inputDir" -ForegroundColor $C.Dim
        Write-Log "No .ktx2 files found"
        Write-Host ""; Read-Host "  Press Enter to continue"
        return
    }

    Write-Host "  Source  : " -ForegroundColor $C.Label -NoNewline
    Write-Host $inputDir -ForegroundColor $C.Value
    Write-Host "  Target  : " -ForegroundColor $C.Label -NoNewline
    Write-Host $outputDir -ForegroundColor $C.Value
    Write-Host "  Files   : " -ForegroundColor $C.Label -NoNewline
    Write-Host $files.Count -ForegroundColor $C.Value
    Write-Host ""
    Write-Border
    Write-Host ""

    Write-Log "Starting conversion: $($files.Count) files"

    $success = 0
    $failed  = 0
    $skipped = 0
    $i       = 0

    foreach ($file in $files) {
        $i++
        $outFile = Join-Path $outputDir ($file.BaseName + ".png")

        Write-ProgressBar -Current $i -Total $files.Count
        Write-Host "  $($file.Name)" -ForegroundColor $C.Label

        if ((Test-Path $outFile) -and $overwrite -eq 'OFF') {
            Write-Host "  >> Skipped" -ForegroundColor $C.Skip
            Write-Log "Skipped: $($file.Name)"
            $skipped++
            Write-Host ""
            continue
        }

        # Temp file with clean .ktx2 extension (FreeImage cannot handle .PNG.KTX2)
        $tempFile = Join-Path $env:TEMP ($file.BaseName + ".ktx2")
        Copy-Item -Path $file.FullName -Destination $tempFile -Force

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo.FileName               = $nvtt
        $proc.StartInfo.Arguments              = "`"$tempFile`" --output `"$outFile`""
        $proc.StartInfo.UseShellExecute        = $false
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError  = $true
        $proc.StartInfo.CreateNoWindow         = $true
        $proc.Start() | Out-Null
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

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
    Write-Host "  1. Go to " -ForegroundColor $C.Label -NoNewline
    Write-Host "Settings [2]" -ForegroundColor $C.Key -NoNewline
    Write-Host " and configure the following:" -ForegroundColor $C.Label
    Write-Host ""
    Write-Host "     [1]  Path to nvtt_export.exe" -ForegroundColor $C.Value
    Write-Host "          You can enter the folder path only - the tool" -ForegroundColor $C.Dim
    Write-Host "          appends 
vtt_export.exe automatically." -ForegroundColor $C.Dim
    Write-Host ""
    Write-Host "     [2]  Source path - the folder containing your .ktx2 files" -ForegroundColor $C.Value
    Write-Host ""
    Write-Host "     [3]  Target path - the folder where .png files will be saved" -ForegroundColor $C.Value
    Write-Host "          The folder is created automatically if it does not exist." -ForegroundColor $C.Dim
    Write-Host ""
    Write-Host "     [4]  Overwrite - toggle ON/OFF" -ForegroundColor $C.Value
    Write-Host "          ON  : existing .png files will be overwritten" -ForegroundColor $C.Dim
    Write-Host "          OFF : existing .png files will be skipped" -ForegroundColor $C.Dim
    Write-Host ""
    Write-Host "  2. Press " -ForegroundColor $C.Label -NoNewline
    Write-Host "[S]" -ForegroundColor $C.Key -NoNewline
    Write-Host " to save your settings." -ForegroundColor $C.Label
    Write-Host ""
    Write-Host "  3. Press " -ForegroundColor $C.Label -NoNewline
    Write-Host "[1]" -ForegroundColor $C.Key -NoNewline
    Write-Host " in the main menu to start the conversion." -ForegroundColor $C.Label
    Write-Host ""
    Write-Border
    Write-Host ""
    Write-Host "  NOTES" -ForegroundColor $C.Header
    Write-Host ""
    Write-Host "  - All .ktx2 files in the source folder are processed" -ForegroundColor $C.Dim
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
        Write-Header ""
        Write-Border
        Write-Host ""
        Write-MenuItem "1" "Start conversion"
        Write-MenuItem "2" "Settings"
        Write-MenuItem "H" "Help"
        Write-MenuItem "X" "Exit"
        Write-Host ""
        Write-Border
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

if (-not $cfg['NvttExePath'])        { $cfg['NvttExePath']       = 'C:\Program Files\NVIDIA Corporation\NVIDIA Texture Tools\nvtt_export.exe' }
if (-not $cfg['InputDir'])           { $cfg['InputDir']          = 'UNDEFINED' }
if (-not $cfg['OutputDir'])          { $cfg['OutputDir']         = 'UNDEFINED' }
if (-not $cfg['OverwriteExisting'])  { $cfg['OverwriteExisting'] = 'ON' }
if (-not $cfg['LogFile'])            { $cfg['LogFile']           = $script:LogFile }

$cfg['NvttExePath'] = Resolve-NvttPath $cfg['NvttExePath']

if (-not (Test-Path $script:ConfigFile)) {
    Write-Header "FIRST SETUP"
    Write-Host "  No configuration found." -ForegroundColor Yellow
    Write-Host "  Please enter your settings..." -ForegroundColor $C.Dim
    Start-Sleep 1
    $updated = Show-ConfigMenu $cfg
    if ($updated) { $cfg = $updated } else { exit 0 }
}

Show-MainMenu $cfg
