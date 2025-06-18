<#
.SYNOPSIS
    Script to export or import user data, browser profiles, and system settings to/from a USB storage device.

.DESCRIPTION
    Exports or imports user data, browser profiles (Chrome, Edge, Firefox), Outlook signatures,
    Quick Access pins, Taskbar settings, File Explorer settings, and mapped network drives
    to a USB device with a folder structure of DriveLetter:\CompanyName\UserName.
    Excludes cloud service folders (*onedrive*, *dropbox*, *icloud*).
    Designed for upgrading to a new computer with minimal disruption.

.PARAMETER Action
    Specify 'Export' or 'Import' to determine the operation.

.EXAMPLE
    .\UserDataTransfer.ps1 -Action Export
    .\UserDataTransfer.ps1 -Action Import
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Export','Import')]
    [string]$Action
)

# Function to get USB drive
function Get-USBDrive {
    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=2" | Where-Object { $_.FreeSpace -gt 0 }
    if ($drives) {
        return $drives.DeviceID
    } else {
        Write-Warning "No USB drive detected, skipping..."
        return $null
    }
}

# Function to validate path
function Test-ValidPath {
    param($Path)
    return (Test-Path $Path -PathType Container)
}

# Function to export Quick Access pins
function Export-QuickAccess {
    param($TargetPath)
    $quickAccess = New-Object -ComObject Shell.Application
    $pins = $quickAccess.NameSpace("shell:::{679F85CB-0220-4080-B29B-5540CC05AAB6}").Items() | 
        Select-Object Name, Path
    $pins | ConvertTo-Json | Out-File -FilePath $TargetPath -Force
}

# Function to import Quick Access pins
function Import-QuickAccess {
    param($SourcePath)
    if (Test-Path $SourcePath) {
        $pins = Get-Content $SourcePath | ConvertFrom-Json
        $quickAccess = New-Object -ComObject Shell.Application
        foreach ($pin in $pins) {
            if (Test-Path $pin.Path) {
                $folder = $quickAccess.NameSpace($pin.Path)
                $folder.Self.InvokeVerb("PinToQuickAccess")
            }
        }
    }
}

# Function to export mapped network drives
function Export-MappedDrives {
    param($TargetPath)
    $drives = Get-ItemProperty -Path "HKCU:\Network\*" | 
        Select-Object RemotePath, UserName, ProviderName, ConnectionState
    $drives | ConvertTo-Json | Out-File -FilePath $TargetPath -Force
}

# Function to import mapped network drives
function Import-MappedDrives {
    param($SourcePath)
    if (Test-Path $SourcePath) {
        $drives = Get-Content $SourcePath | ConvertFrom-Json
        foreach ($drive in $drives) {
            try {
                New-PSDrive -Name $drive.PSChildName -PSProvider FileSystem `
                    -Root $drive.RemotePath -Persist -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Failed to map drive $($drive.RemotePath): $_"
            }
        }
    }
}

# Get user input
$companyName = Read-Host "Enter company name"
$username = Read-Host "Enter username"

# Define paths
$userFolder = "C:\Users\$username"
$chromeSource = "$env:LOCALAPPDATA\Google\Chrome"
$edgeSource = "$env:LOCALAPPDATA\Microsoft\Edge"
$firefoxSource = "$env:LOCALAPPDATA\Mozilla\Firefox"
$signaturesSource = "$env:APPDATA\Microsoft\Signatures"

# Get USB drive
$usbDrive = Get-USBDrive
if (-not $usbDrive) { exit 1 }
$targetBasePath = Join-Path $usbDrive "$companyName\$username"
$settingsTarget = Join-Path $targetBasePath "Settings"
$chromeTarget = Join-Path $targetBasePath "Chrome"
$edgeTarget = Join-Path $targetBasePath "Edge"
$firefoxTarget = Join-Path $targetBasePath "Firefox"
$signaturesTarget = Join-Path $settingsTarget "Signatures"
$quickAccessTarget = Join-Path $settingsTarget "QuickAccess.json"
$mappedDrivesTarget = Join-Path $settingsTarget "MappedDrives.json"
$taskbarSettingsTarget = Join-Path $settingsTarget "TaskbarSettings.reg"
$explorerSettingsTarget = Join-Path $settingsTarget "ExplorerSettings.reg"

# Robocopy parameters
$roboCopyParams = @(
    "/MIR",      # Mirror source to destination
    "/MT:32",    # Use 32 threads for faster copying
    "/XD",       # Exclude directories (for user folder only)
    "*onedrive*",
    "*dropbox*",
    "*icloud*",
    "/R:0",      # No retries (force copy)
    "/W:0",      # No wait between retries
    "/NP",       # No progress display
    "/Z",        # Copy in restartable mode
    "/J",        # Unbuffered I/O for large files
    "/E",        # Include empty directories
    "/COPYALL",  # Copy all file attributes
    "/LOG+:transfer.log" # Append to log file
)

try {
    if ($Action -eq "Export") {
        Write-Host "Exporting data to $targetBasePath..."

        # Create target directories
        New-Item -Path $targetBasePath, $settingsTarget -ItemType Directory -Force | Out-Null

        # Export user folder
        if (Test-ValidPath $userFolder) {
            Write-Host "Exporting user data from $userFolder..."
            robocopy $userFolder $targetBasePath *.* @roboCopyParams
        } else {
            Write-Warning "User folder $userFolder not found, skipping..."
        }

        # Export Chrome data
        if (Test-ValidPath $chromeSource) {
            Write-Host "Exporting Chrome data from $chromeSource..."
            New-Item -Path $chromeTarget -ItemType Directory -Force | Out-Null
            robocopy $chromeSource $chromeTarget *.* @roboCopyParams
        } else {
            Write-Warning "Chrome folder $chromeSource not found, skipping..."
        }

        # Export Edge data
        if (Test-ValidPath $edgeSource) {
            Write-Host "Exporting Edge data from $edgeSource..."
            New-Item -Path $edgeTarget -ItemType Directory -Force | Out-Null
            robocopy $edgeSource $edgeTarget *.* @roboCopyParams
        } else {
            Write-Warning "Edge folder $edgeSource not found, skipping..."
        }

        # Export Firefox data
        if (Test-ValidPath $firefoxSource) {
            Write-Host "Exporting Firefox data from $firefoxSource..."
            New-Item -Path $firefoxTarget -ItemType Directory -Force | Out-Null
            robocopy $firefoxSource $firefoxTarget *.* @roboCopyParams
        } else {
            Write-Warning "Firefox folder $firefoxSource not found, skipping..."
        }

        # Export Outlook signatures
        if (Test-ValidPath $signaturesSource) {
            Write-Host "Exporting Outlook signatures from $signaturesSource..."
            New-Item -Path $signaturesTarget -ItemType Directory -Force | Out-Null
            robocopy $signaturesSource $signaturesTarget *.* @roboCopyParams
        } else {
            Write-Warning "Signatures folder $signaturesSource not found, skipping..."
        }

        # Export Quick Access pins
        Write-Host "Exporting Quick Access pins..."
        Export-QuickAccess -TargetPath $quickAccessTarget

        # Export mapped network drives
        Write-Host "Exporting mapped network drives..."
        Export-MappedDrives -TargetPath $mappedDrivesTarget

        # Export taskbar settings
        Write-Host "Exporting taskbar settings..."
        reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" $taskbarSettingsTarget /y 2>$null

        # Export explorer settings
        Write-Host "Exporting File Explorer settings..."
        reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" $explorerSettingsTarget /y 2>$null

        Write-Host "Export completed. Check transfer.log for details."
    }
    elseif ($Action -eq "Import") {
        Write-Host "Importing data from $targetBasePath..."

        # Validate base target path
        if (-not (Test-ValidPath $targetBasePath)) {
            Write-Warning "Source path $targetBasePath not found on USB drive, skipping..."
            exit 1
        }

        # Import user folder
        Write-Host "Importing user data to $userFolder..."
        robocopy $targetBasePath $userFolder *.* @roboCopyParams

        # Import Chrome data
        if (Test-ValidPath $chromeTarget) {
            Write-Host "Importing Chrome data to $chromeSource..."
            New-Item -Path $chromeSource -ItemType Directory -Force | Out-Null
            robocopy $chromeTarget $chromeSource *.* @roboCopyParams
        } else {
            Write-Warning "Chrome folder $chromeTarget not found on USB, skipping..."
        }

        # Import Edge data
        if (Test-ValidPath $edgeTarget) {
            Write-Host "Importing Edge data to $edgeSource..."
            New-Item -Path $edgeSource -ItemType Directory -Force | Out-Null
            robocopy $edgeTarget $edgeSource *.* @roboCopyParams
        } else {
            Write-Warning "Edge folder $edgeTarget not found on USB, skipping..."
        }

        # Import Firefox data
        if (Test-ValidPath $firefoxTarget) {
            Write-Host "Importing Firefox data to $firefoxSource..."
            New-Item -Path $firefoxSource -ItemType Directory -Force | Out-Null
            robocopy $firefoxTarget $firefoxSource *.* @roboCopyParams
        } else {
            Write-Warning "Firefox folder $firefoxTarget not found on USB, skipping..."
        }

        # Import Outlook signatures
        if (Test-ValidPath $signaturesTarget) {
            Write-Host "Importing Outlook signatures to $signaturesSource..."
            New-Item -Path $signaturesSource -ItemType Directory -Force | Out-Null
            robocopy $signaturesTarget $signaturesSource *.* @roboCopyParams
        } else {
            Write-Warning "Signatures folder $signaturesTarget not found on USB, skipping..."
        }

        # Import Quick Access pins
        if (Test-Path $quickAccessTarget) {
            Write-Host "Importing Quick Access pins..."
            Import-QuickAccess -SourcePath $quickAccessTarget
        } else {
            Write-Warning "Quick Access pins file $quickAccessTarget not found, skipping..."
        }

        # Import mapped network drives
        if (Test-Path $mappedDrivesTarget) {
            Write-Host "Importing mapped network drives..."
            Import-MappedDrives -SourcePath $mappedDrivesTarget
        } else {
            Write-Warning "Mapped drives file $mappedDrivesTarget not found, skipping..."
        }

        # Import taskbar settings
        if (Test-Path $taskbarSettingsTarget) {
            Write-Host "Importing taskbar settings..."
            reg import $taskbarSettingsTarget 2>$null
        } else {
            Write-Warning "Taskbar settings file $taskbarSettingsTarget not found, skipping..."
        }

        # Import explorer settings
        if (Test-Path $explorerSettingsTarget) {
            Write-Host "Importing File Explorer settings..."
            reg import $explorerSettingsTarget 2>$null
        } else {
            Write-Warning "Explorer settings file $explorerSettingsTarget not found, skipping..."
        }

        Write-Host "Import completed. Check transfer.log for details."
    }
}
catch {
    Write-Warning "An error occurred: $_"
}
finally {
    Write-Host "Operation completed."
}