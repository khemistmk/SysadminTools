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
        New-OSDCloudTemplate -Language en-us -SetInputLocale en-us -Verbose
        New-OSDCloudWorkspace -WorkspacePath $WorkspacePath -Verbose
        Set-OSDCloud​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​​