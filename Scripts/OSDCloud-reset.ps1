#requires -RunAsAdministrator
#requires -Version 5.1

<#
.SYNOPSIS
    Shrinks the OS partition, creates a recovery partition, installs OSDCloud WinPE with embedded Start-OSDCloud parameters,
    and reboots into the recovery partition for OS reinstallation.

.DESCRIPTION
    This script shrinks the OS partition to create space, sets up a recovery partition on the primary disk,
    configures OSDCloud WinPE with embedded Start-OSDCloud parameters, updates boot settings, and reboots
    into the recovery partition to automatically reinstall Windows using OSDCloud. Designed to be run remotely via irm and iex.

.NOTES
    Author: Grok, with inspiration from OSDCloud by David Segura
    Date: July 12, 2025
    Requirements: Internet access, administrative privileges, Windows 10/11, UEFI firmware, Windows ADK with WinPE Add-on
    Warning: Modifies disk partitions and may cause data loss. Test in a VM first.
#>

# Set execution policy to bypass for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Ensure the script is running with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires administrative privileges. Please run as Administrator."
    exit 1
}

# Function to check for Windows ADK and WinPE Add-on
function Test-WinADK {
    $adkPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
    if (-not (Test-Path $adkPath)) {
        Write-Error "Windows ADK with WinPE Add-on is not installed. Please install it from https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install."
        exit 1
    }
    Write-Host "Windows ADK with WinPE Add-on detected."
}

# Function to shrink the OS partition and create a recovery partition
function New-RecoveryPartition {
    param (
        [int]$DiskNumber = 0,
        [int]$PartitionSizeMB = 2048  # 2GB for recovery partition
    )

    Write-Host "Shrinking OS partition and creating recovery partition on Disk $DiskNumber..."

    # Get the target disk and verify it's GPT
    $disk = Get-Disk -Number $DiskNumber
    if (-not $disk) {
        Write-Error "Disk $DiskNumber not found."
        exit 1
    }
    if ($disk.PartitionStyle -ne 'GPT') {
        Write-Error "Disk $DiskNumber is not GPT. This script requires a GPT disk for UEFI compatibility."
        exit 1
    }

    # Identify the OS partition (largest NTFS partition with Windows folder)
    $osPartition = Get-Partition -DiskNumber $DiskNumber | Where-Object {
        $_.Type -eq 'Basic' -and $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Windows")
    } | Sort-Object Size -Descending | Select-Object -First 1

    if (-not $osPartition) {
        Write-Error "Could not identify the OS partition on Disk $DiskNumber."
        exit 1
    }

    $driveLetterOS = $osPartition.DriveLetter
    Write-Host "Identified OS partition: Drive $driveLetterOS, Size: $($osPartition.Size / 1MB) MB"

    # Check if the OS partition can be shrunk
    $sizeInfo = Get-PartitionSupportedSize -DriveLetter $driveLetterOS
    $minSizeMB = [math]::Ceiling($sizeInfo.SizeMin / 1MB)
    $currentSizeMB = [math]::Ceiling($osPartition.Size / 1MB)
    $availableShrinkMB = $currentSizeMB - $minSizeMB

    if ($availableShrinkMB -lt $PartitionSizeMB) {
        Write-Error "Insufficient shrinkable space on OS partition. Available: $availableShrinkMB MB, Required: $PartitionSizeMB MB. Try running 'defrag $driveLetterOS /X' to consolidate free space."
        exit 1
    }

    # Shrink the OS partition
    try {
        $newSizeMB = $currentSizeMB - $PartitionSizeMB
        Resize-Partition -DriveLetter $driveLetterOS -Size ($newSizeMB * 1MB) -ErrorAction Stop
        Write-Host "Shrunk OS partition to $newSizeMB MB."
    }
    catch {
        Write-Error "Failed to shrink OS partition: $_"
        exit 1
    }

    # Create a new recovery partition in the freed space
    try {
        $partition = New-Partition -DiskNumber $DiskNumber -Size ($PartitionSizeMB * 1MB) -AssignDriveLetter
        $driveLetter = $partition.DriveLetter
        Write-Host "Created recovery partition with drive letter $driveLetter."

        # Format the partition as NTFS
        Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel "Recovery" -Force -Confirm:$false
        Write-Host "Formatted recovery partition as NTFS."

        # Set partition type as Recovery (for UEFI)
        Set-Partition -DriveLetter $driveLetter -GptType "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
        Write-Host "Set partition type to Recovery."

        return $driveLetter
    }
    catch {
        Write-Error "Failed to create or format recovery partition: $_"
        exit 1
    }
}

# Function to download and install OSDCloud WinPE with embedded Start-OSDCloud parameters
function Install-OSDCloudWinPE {
    param (
        [string]$DriveLetter,
        [string]$WorkspacePath = "$env:ProgramData\OSDCloud"
    )

    Write-Host "Installing OSDCloud WinPE to $DriveLetter..."

    # Install OSD PowerShell module if not already installed
    if (-not (Get-Module -ListAvailable -Name OSD)) {
        Write-Host "Installing OSD PowerShell module..."
        Install-Module -Name OSD -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module OSD -Force
    }

    # Create OSDCloud template and workspace
    try {
        New-OSDCloudTemplate -Language en-us -SetInputLocale en-us -Verbose
        New-OSDCloudWorkspace -WorkspacePath $WorkspacePath -Verbose
        Set-OSDCloudWorkspace -WorkspacePath $WorkspacePath -Verbose
    }
    catch {
        Write-Error "Failed to create OSDCloud template/workspace: $_"
        exit 1
    }

    # Customize WinPE with drivers and embedded Start-OSDCloud parameters
    try {
        Edit-OSDCloudWinPE -WorkspacePath $WorkspacePath -CloudDriver Dell,HP,IntelNet,LenovoDock,Nutanix,USB,VMware,WiFi `
            -StartOSDCloud "-OSName 'Windows 11 24H2 x64' -OSEdition Pro -OSActivation Retail -OSLanguage en-us -RecoveryPartition" -Verbose
        Write-Host "Customized WinPE with embedded Start-OSDCloud parameters."
    }
    catch {
        Write-Error "Failed to customize OSDCloud WinPE: $_"
        exit 1
    }

    # Copy WinPE files to the recovery partition
    $winPEPath = "$WorkspacePath\Media\sources\boot.wim"
    if (-not (Test-Path $winPEPath)) {
        Write-Error "WinPE image not found at $winPEPath."
        exit 1
    }

    try {
        $recoveryPath = "${DriveLetter}:\Recovery\WindowsRE"
        New-Item -Path $recoveryPath -ItemType Directory -Force
        Copy-Item -Path $winPEPath -Destination "$recoveryPath\winre.wim" -Force
        Write-Host "Copied WinPE image to $recoveryPath\winre.wim."
    }
    catch {
        Write-Error "Failed to copy WinPE image: $_"
        exit 1
    }

    return $recoveryPath
}

# Function to configure WinRE and set boot order
function Set-WinREBoot {
    param (
        [string]$RecoveryPath,
        [string]$DriveLetter
    )

    Write-Host "Configuring WinRE and boot settings..."

    # Configure ReAgent.xml for WinRE
    $reagentXmlPath = "C:\Windows\System32\Recovery\ReAgent.xml"
    $recoveryPartition = Get-Partition -DriveLetter $DriveLetter
    $partitionIndex = $recoveryPartition.PartitionNumber
    $diskNumber = $recoveryPartition.DiskNumber

    try {
        # Disable WinRE temporarily
        reagentc /disable | Out-Null
        Write-Host "Disabled existing WinRE configuration."

        # Update ReAgent.xml with new WinRE path
        $reagentXml = @"
<WindowsRE version="2.0">
  <WinreBCD id="{00000000-0000-0000-0000-000000000000}"/>
  <WinreLocation path="\Recovery\WindowsRE" id="$partitionIndex" offset="0" guid="{00000000-0000-0000-0000-000000000000}"/>
  <ImageLocation path="\Recovery\WindowsRE" id="$diskNumber" offset="0" guid="{00000000-0000-0000-0000-000000000000}"/>
  <InstallState state="1"/>
  <IsServer value="0"/>
  <IsWimBoot value="0"/>
  <CustomImage value="1"/>
</WindowsRE>
"@
        Set-Content -Path $reagentXmlPath -Value $reagentXml -Force
        Write-Host "Updated ReAgent.xml with new WinRE path."

        # Enable WinRE with the new path
        reagentc /setreimage /path "$RecoveryPath" /target C:\Windows | Out-Null
        reagentc /enable | Out-Null
        Write-Host "Enabled WinRE with new recovery partition."

        # Create a new BCD entry for the recovery environment
        $bcdEntry = bcdedit /create /d "Windows Recovery Environment" /application osloader
        $guid = ($bcdEntry | Select-String "{.+}").Matches.Value
        if (-not $guid) {
            Write-Error "Failed to create BCD entry for WinRE."
            exit 1
        }

        # Configure BCD entry
        bcdedit /set $guid device partition=${DriveLetter}: | Out-Null
        bcdedit /set $guid osdevice partition=${DriveLetter}: | Out-Null
        bcdedit /set $guid path \Recovery\WindowsRE\winre.wim | Out-Null
        bcdedit /set $guid recoveryenabled Yes | Out-Null
        bcdedit /set $guid recoverysequence $guid | Out-Null
        bcdedit /displayorder $guid /addfirst | Out-Null
        Write-Host "Configured BCD to boot from recovery partition (GUID: $guid)."

        # Verify BCD configuration
        $bcdCheck = bcdedit /enum all | Select-String $guid
        if (-not $bcdCheck) {
            Write-Error "BCD configuration verification failed."
            exit 1
        }
    }
    catch {
        Write-Error "Failed to configure WinRE or boot settings: $_"
        exit 1
    }
}

# Main script execution
try {
    Write-Host "Starting recovery partition creation and OSDCloud setup..."

    # Step 1: Check for Windows ADK
    Test-WinADK

    # Step 2: Shrink OS partition and create recovery partition
    $driveLetter = New-RecoveryPartition

    # Step 3: Install OSDCloud WinPE to recovery partition with embedded Start-OSDCloud
    $recoveryPath = Install-OSDCloudWinPE -DriveLetter $driveLetter

    # Step 4: Configure WinRE and boot settings
    Set-WinREBoot -RecoveryPath $recoveryPath -DriveLetter $driveLetter

    # Step 5: Signal reboot into recovery partition
    Write-Host "Rebooting into recovery partition to start OSDCloud OS reinstallation..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}