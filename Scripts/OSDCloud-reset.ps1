# Requires -RunAsAdministrator

# Function to check if running as Administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Exit if not running as Administrator
if (-not (Test-Admin)) {
    Write-Error "This script must be run as an Administrator. Please run PowerShell as Administrator and try again."
    exit 1
}

# Variables
$secondaryPartitionLetter = "D"
$bootWimUrl = "https://files.khemgeek.com/boot.wim"
$bootWimPath = "$secondaryPartitionLetter`:\Sources\boot.wim"
$partitionSizeMB = 1024  # Size of the secondary partition in MB (1GB)
$diskNumber = 0  # Assuming primary disk; adjust if needed

try {
    # Step 1: Identify the OS partition
    Write-Host "Identifying OS partition..."
    $osPartition = $null
    $partitions = Get-Partition
    foreach ($partition in $partitions) {
        if ($partition.DriveLetter -and (Test-Path "$($partition.DriveLetter):\Windows")) {
            $osPartition = $partition
            break
        }
    }

    if (-not $osPartition) {
        Write-Host "DEBUG: Listing all partitions for troubleshooting..."
        $partitions | Format-Table DiskNumber, PartitionNumber, DriveLetter, Size, Type -AutoSize
        Write-Error "Could not identify the OS partition. Ensure the Windows directory exists on a partition with a drive letter."
        exit 1
    }

    $osDiskNumber = $osPartition.DiskNumber
    $osPartitionNumber = $osPartition.PartitionNumber
    Write-Host "OS partition found on Disk $osDiskNumber, Partition $osPartitionNumber, Drive Letter $($osPartition.DriveLetter)."

    # Check if there’s enough space to shrink
    Write-Host "Checking available shrink space..."
    $partitionInfo = Get-PartitionSupportedSize -DiskNumber $osDiskNumber -PartitionNumber $osPartitionNumber
    $availableShrinkMB = [math]::Floor(($partitionInfo.SizeMax - $partitionInfo.SizeMin) / 1MB)
    if ($availableShrinkMB -lt $partitionSizeMB) {
        Write-Error "Insufficient space to shrink OS partition. Available: $availableShrinkMB MB, Required: $partitionSizeMB MB."
        exit 1
    }
    Write-Host "Available shrink space: $availableShrinkMB MB."

    # Step 2: Shrink the OS partition
    Write-Host "Shrinking OS partition to create $partitionSizeMB MB of unallocated space..."
    $osPartition | Resize-Partition -Size ($osPartition.Size - ($partitionSizeMB * 1MB))
    if ($?) {
        Write-Host "OS partition shrunk successfully."
    } else {
        Write-Error "Failed to shrink OS partition."
        exit 1
    }

    # Step 3: Create a secondary partition in the unallocated space
    Write-Host "Creating secondary partition..."
    $diskpartScript = @"
select disk $diskNumber
create partition primary size=$partitionSizeMB
format fs=ntfs quick label="WinPE"
assign letter=$secondaryPartitionLetter
active
exit
"@

    # Write diskpart script to a temporary file
    $diskpartScriptPath = "$env:TEMP\diskpart_script.txt"
    $diskpartScript | Out-File -FilePath $diskpartScriptPath -Encoding ASCII

    # Run diskpart to create and format the partition
    Start-Process -FilePath "diskpart.exe" -ArgumentList "/s $diskpartScriptPath" -Wait -NoNewWindow

    if (-not (Test-Path "$secondaryPartitionLetter`:\")) {
        Write-Error "Failed to create or assign secondary partition with letter $secondaryPartitionLetter."
        exit 1
    }

    # Step 4: Create Sources directory on the secondary partition
    Write-Host "Creating Sources directory on $secondaryPartitionLetter`:\..."
    New-Item -Path "$secondaryPartitionLetter`:\Sources" -ItemType Directory -Force | Out-Null

    # Step 5: Download boot.wim
    Write-Host "Downloading boot.wim from $bootWimUrl..."
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($bootWimUrl, $bootWimPath)

    if (-not (Test-Path $bootWimPath)) {
        Write-Error "Failed to download or save boot.wim to $bootWimPath."
        exit 1
    }

    # Step 6: Configure BCD using bcdedit via cmd.exe
    Write-Host "Configuring BCD boot entry..."
    $bcdCommands = @"
bcdedit /create {ramdiskoptions}
bcdedit /set {ramdiskoptions} device partition=$secondaryPartitionLetter`:
bcdedit /set {ramdiskoptions} path \Sources\boot.wim
bcdedit /set {ramdiskoptions} osdevice ramdisk=[$secondaryPartitionLetter`:]\Sources\boot.wim,{ramdiskoptions}
bcdedit /set {ramdiskoptions} systemroot \Windows
bcdedit /set {ramdiskoptions} detecthal yes
bcdedit /set {ramdiskoptions} winpe yes
bcdedit /set {ramdiskoptions} description "Windows PE from Secondary Partition"
bcdedit /displayorder {ramdiskoptions} /addlast
bcdedit /timeout 10
"@

    # Write bcdedit commands to a temporary batch file
    $bcdScriptPath = "$env:TEMP\bcdedit_commands.bat"
    $bcdCommands | Out-File -FilePath $bcdScriptPath -Encoding ASCII

    # Run bcdedit commands via cmd.exe
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $bcdScriptPath" -Wait -NoNewWindow

    # Verify BCD configuration
    Write-Host "Verifying BCD configuration..."
    $bcdOutput = bcdedit /enum
    if ($bcdOutput -match "Windows PE from Secondary Partition") {
        Write-Host "BCD configuration successful."
    } else {
        Write-Error "BCD configuration failed. Please check the boot entries manually using 'bcdedit /enum'."
        exit 1
    }

    # Step 7: Reboot the computer
    Write-Host "Rebooting the computer in 10 seconds to boot into the secondary partition..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}