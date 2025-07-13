#requires -RunAsAdministrator
#requires -Version 5.1

<#
.SYNOPSIS
    Shrinks the OS partition, creates a recovery partition, downloads a prebuilt OSDCloud WinPE boot.wim,
    configures the boot settings, and reboots into the recovery partition for OS reinstallation.

.DESCRIPTION
    This script shrinks the OS partition to create a 2GB recovery partition, downloads a prebuilt OSDCloud
    WinPE boot.wim from a specified URL, places it in the recovery partition, configures WinRE and BCD,
    and reboots into the recovery partition to start OS reinstallation. Designed to be run remotely via irm and iex.

.NOTES
    Author: Grok
    Date: July 12, 2025
    Requirements: Internet access, administrative privileges, Windows 10/11, UEFI firmware, GPT disk
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

# Function to download and place prebuilt OSDCloud WinPE boot.wim
function Install-PrebuiltWinPE {
    param (
        [string]$DriveLetter,
        [string]$WinPEUrl = "https://files.khemgeek.com/boot.wim"
    )

    Write-Host "Downloading prebuilt OSDCloud WinPE boot.wim to $DriveLetter..."

    # Create recovery directory
    try {
        $recoveryPath = "${DriveLetter}:\Recovery\WindowsRE"
        New-Item -Path $recoveryPath -ItemType Directory -Force | Out-Null
        Write-Host "Created recovery directory at $recoveryPath."
    }
    catch {
        Write-Error "Failed to create recovery directory: $_"
        exit 1
    }

    # Download boot.wim
    try {
        $winPEPath = "$recoveryPath\winre.wim"
        Invoke-WebRequest -Uri $WinPEUrl -OutFile $winPEPath -ErrorAction Stop
        Write-Host "Downloaded prebuilt boot.wim to $winPEPath."
    }
    catch {
        Write-Error "Failed to download boot.wim from $WinPEUrl."
        exit 1
    }

    # Verify the downloaded file
    if (-not (Test-Path $winPEPath)) {
        Write-Error "Downloaded boot.wim not found at $winPEPath."
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
    Write-Host "Starting recovery partition creation and OSDCloud WinPE setup..."

    # Step 1: Shrink OS partition and create recovery partition
    $driveLetter = New-RecoveryPartition

    # Step 2: Download and place prebuilt OSDCloud WinPE
    $recoveryPath = Install-PrebuiltWinPE -DriveLetter $driveLetter

    # Step 3: Configure WinRE and boot settings
    Set-WinREBoot -RecoveryPath $recoveryPath -DriveLetter $driveLetter

    # Step 4: Signal reboot into recovery partition
    Write-Host "Rebooting into recovery partition to start OSDCloud OS reinstallation..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}