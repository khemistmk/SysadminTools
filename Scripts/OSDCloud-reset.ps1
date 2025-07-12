#requires -RunAsAdministrator
#requires -Version 5.1

<#
.SYNOPSIS
    Shrinks the OS partition, creates a recovery partition, installs OSDCloud WinPE, and boots to it for OS reinstallation.

.DESCRIPTION
    This script shrinks the OS partition to make space, creates a recovery partition on the primary disk,
    downloads and configures OSDCloud WinPE, sets up the boot configuration, and restarts the machine
    to boot into WinPE for OS reinstallation. The script is designed to be run remotely via irm and iex.

.NOTES
    Author: Grok, with inspiration from OSDCloud by David Segura
    Date: July 12, 2025
    Requirements: Internet access, administrative privileges, Windows 10/11, UEFI firmware
    Warning: Modifies disk partitions and may cause data loss. Test in a VM first.
#>

# Set execution policy to bypass for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Ensure the script is running with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires administrative privileges. Please run as Administrator."
    exit 1
}

# Function to shrink the OS partition and create a recovery partition
function New-RecoveryPartition {
    param (
        [int]$DiskNumber = 0,
        [int]$PartitionSizeMB = 2048  # 2GB for recovery partition
    )

    Write-Host "Shrinking OS partition and creating recovery partition on Disk $DiskNumber..."

    # Get the target disk
    $disk = Get-Disk -Number $DiskNumber
    if (-not $disk) {
        Write-Error "Disk $DiskNumber not found."
        exit 1
    }

    # Identify the OS partition (typically the largest NTFS partition with Windows)
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
    $volume = Get-Volume -DriveLetter $driveLetterOS
    $sizeInfo = Get-PartitionSupportedSize -DriveLetter $driveLetterOS
    $minSizeMB = [math]::Ceiling($sizeInfo.SizeMin / 1MB)
    $currentSizeMB = [math]::Ceiling($osPartition.Size / 1MB)
    $availableShrinkMB = $currentSizeMB - $minSizeMB

    if ($availableShrinkMB -lt $PartitionSizeMB) {
        Write-Error "Insufficient shrinkable space on OS partition. Available: $availableShrinkMB MB, Required: $PartitionSizeMB MB."
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

# Function to download and install OSDCloud WinPE
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
        New-OSDCloudTemplate
        New-OSDCloudWorkspace -WorkspacePath $WorkspacePath -Verbose
        Set-OSDCloudWorkspace -WorkspacePath $WorkspacePath -Verbose
    }
    catch {
        Write-Error "Failed to create OSDCloud template/workspace: $_"
        exit 1
    }

    # Customize WinPE with drivers and automation script
    $webPSScript = "https://raw.githubusercontent.com/OSDeploy/OSDCloud/main/Demo-CustomOSDCloud.ps1"
    try {
        Edit-OSDCloudWinPE -WorkspacePath $WorkspacePath -CloudDriver Dell,HP,IntelNet,LenovoDock,Nutanix,USB,VMware,WiFi -WebPSScript $webPSScript -Verbose
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
        reagentc /disable

        # Update ReAgent.xml with new WinRE path
        $reagentXml = @"
<WindowsRE version="2.0">
  <WinreBCD id="{00000000-0000-0000-0000-000000000000}"/>
  <WinreLocation path="\Recovery\WindowsRE" id="0" offset="0" guid="{00000000-0000-0000-0000-000000000000}"/>
  <ImageLocation path="\Recovery\WindowsRE" id="$diskNumber" offset="0" guid="{00000000-0000-0000-0000-000000000000}"/>
  <InstallState state="1"/>
  <IsServer value="0"/>
  <IsWimBoot value="0"/>
  <CustomImage value="0"/>
</WindowsRE>
"@
        Set-Content -Path $reagentXmlPath -Value $reagentXml -Force
        Write-Host "Updated ReAgent.xml with new WinRE path."

        # Enable WinRE
        reagentc /enable
        reagentc /setreimage /path "$RecoveryPath" /target C:\Windows

        # Set boot order to boot from recovery partition
        $bcdStore = bcdedit /store C:\boot\bcd
        $bcdEntry = bcdedit /create /d "Windows Recovery Environment" /application osloader
        $guid = ($bcdEntry | Select-String "{.+}").Matches.Value
        bcdedit /set $guid osdevice partition=${DriveLetter}:
        bcdedit /set $guid device partition=${DriveLetter}:
        bcdedit /set $guid path \Recovery\WindowsRE\winre.wim
        bcdedit /set $guid recoveryenabled Yes
        bcdedit /set $guid recoverysequence $guid
        bcdedit /displayorder $guid /addfirst

        Write-Host "Configured BCD to boot from recovery partition."
    }
    catch {
        Write-Error "Failed to configure WinRE or boot settings: $_"
        exit 1
    }
}

# Function to initiate OS reinstallation with OSDCloud
function Start-OSDCloudReinstall {
    Write-Host "Preparing to boot into WinPE for OS reinstallation..."

    # Define OSDCloud parameters for reinstallation
    $osdParams = @{
        OSName = 'Windows 11 23H2 x64'
        OSEdition = 'Pro'
        OSActivation = 'Retail'
        OSLanguage = 'en-us'
        Restart = $true
        RecoveryPartition = $true
    }

    # Start OSDCloud
    try {
        Start-OSDCloud @osdParams -Verbose
    }
    catch {
        Write-Error "Failed to start OSDCloud: $_"
        exit 1
    }
}

# Main script execution
try {
    Write-Host "Starting recovery partition creation and OSDCloud setup..."

    # Step 1: Shrink OS partition and create recovery partition
    $driveLetter = New-RecoveryPartition

    # Step 2: Install OSDCloud WinPE to recovery partition
    $recoveryPath = Install-OSDCloudWinPE -DriveLetter $driveLetter

    # Step 3: Configure WinRE and boot settings
    Set-WinREBoot -RecoveryPath $recoveryPath -DriveLetter $driveLetter

    # Step 4: Restart to boot into WinPE and start OSDCloud
    Write-Host "Restarting to boot into WinPE for OS reinstallation..."
    Start-Sleep -Seconds 5
    wpeutil reboot
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}