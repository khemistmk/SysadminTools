function Get-SystemStatus {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$SaveLocation = "$env:SystemDrive\Setup Files"
        
    )

    begin {   
        $date = Get-Date
        $serialnumber = (Get-WmiObject -Class Win32_BIOS | Select-Object -Property SerialNumber).serialnumber
        $computername = (Get-WmiObject -Class Win32_Operatingsystem).PSComputerName
        $winver = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
        $licensestatus = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" | Where-Object -Property Name -Like "Windows*"
        $Admin = (Get-LocalUser -Name "Administrator").Enabled
        $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).manufacturer
        $model = (Get-CimInstance -Namespace root\wmi -ClassName MS_SystemInformation).SystemVersion
        $CPUInfo = (Get-CimInstance Win32_Processor).name
        $RAM = Get-CimInstance win32_ComputerSystem | ForEach-Object {[math]::round($_.TotalPhysicalMemory /1GB)}
        $drivesize = Get-PhysicalDisk | ForEach-Object {[math]::round($_.size /1GB)}
        $Drivemanufacturer = Get-PhysicalDisk | Select-Object -ExpandProperty FriendlyName
        $drivebrand,$driveserial = $Drivemanufacturer -split " "
        $Drivetype = Get-PhysicalDisk | Select-Object -ExpandProperty MediaType
        $Bustype = Get-PhysicalDisk | Select-Object -ExpandProperty Bustype
        $graphics = (Get-CimInstance -ClassName Win32_VideoController).Description | Out-String
        $OEM =  Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" | Select-Object -Property Manufacturer,SupportHours,SupportPhone,SupportURL
        $oemman = $OEM.Manufacturer
        $oemhours = $OEM.SupportHours
        $oemphone = $OEM.SupportPhone
        $oemurl = $OEM.SupportURL
        $dotnet3 = (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name 'Version' -ErrorAction SilentlyContinue | ForEach-Object {$_.Version -as [System.Version]} | Where-Object {$_.Major -eq 3 -and $_.Minor -eq 5}).Count -ge 1
        $fsPath = "HKLM:\System\CurrentControlSet\Control\Session Manager\Power"
        $fsName = "HiberbootEnabled"
        $fsvalue = (Get-ItemProperty -Path $fsPath -Name $fsName).HiberbootEnabled
        $RAMinfo = Get-CimInstance -Classname Win32_PhysicalMemory
        $ramcap = $RAMinfo | ForEach-Object {[math]::round($_.Capacity /1GB)}
        $ramman = $RAMinfo.Manufacturer
        $ramloc = $RAMinfo.DeviceLocator
        $ramspeed = $RAMinfo.Speed
        $ramchannel = $RAMinfo.InterleaveDataDepth
            }
    process {
        if ($licensestatus.LicenseStatus -eq 1){
            $winactivation = "Activated"
        }
        if (($drivesize -gt "459")-and ($drivesize -lt "468")) { $Drive = "500 GB"}
        if (($drivesize -gt "469") -and ($drivesize -lt "479")) { $Drive = "512 GB"}
        if (($drivesize -gt "929") -and ($drivesize -lt "1024")) { $Drive = "1 TB"}
        if (($drivesize -gt "1800") -and ($drivesize -lt "2048")) { $Drive = "2 TB"}
       
        $Programs = @()
        $Programlist = @(
                        "Adobe Acrobat",
                        "Reader",
                        "Foxit",
                        "Microsoft Office",
                        "Microsoft 365",
                        "Project",
                        "AutoDesk",
                        "Navisworks",
                        "VLC",
                        "Chrome",
                        "Firefox",
                        "Sophos",
                        "7-Zip",
                         "Forticlient"
        )
        foreach ($p in $Programlist) {
            $Programs += (Get-Package | Where-Object {$_.Name -like "*$p*"}).Name
        }
        $plist = $Programs | Out-String
        if (!$Admin) {
            $Adminstatus = "Disabled"
        }
        else {
            $Adminstatus = "Enabled"
        }
        if (((Get-BitLockerVolume -MountPoint "C:").VolumeStatus) -eq 'FullyEncrypted') {
            $bit = "Enabled"
        }
        else {
            $bit = "Disabled"
        }
        if (!(Test-Path "C:\Platform")) {
            $platform = "Removed"
        }
        else {
            $platform = "Not Removed"
        }
        if (!(Test-Path "C:\OEM")) { 
            $oemfolder = "Removed"
        }
        else {
            $oemfolder = "Not Removed"
        }
        if ($dotnet3 -eq 'True') {
            $dotnet = "Enabled"
        }
        else {
            $dotnet = "Disabled"
        }
        if ($fsvalue -eq "0") {
            $faststart = "Disabled"
        }
        else {
            $faststart = "Enabled"
        }
        if ($null -eq (Get-Package | Where-Object {$_.Name -like "*SmartDeploy*"})) {
            $SmartDeploy = "Removed"
        }
        else {
            $SmartDeploy = "Not Removed"
        }
        $ramchan = @()
        foreach ($r in $ramchannel){
            if ($r -eq "2") {
                $ramchan += "Dual Channel"
            }
            else {
                $ramchan += "Single Channel"
            }
        }

        $RAM1 = $ramcap[0],"GB",$ramman[0],$ramspeed[0],"GHz", $ramchan[0],$ramloc[0]
        $RAM2 = $ramcap[1],"GB",$ramman[1],$ramspeed[1],"GHz", $ramchan[0],$ramloc[1]
        $RAM3 = $ramcap[2],"GB",$ramman[2],$ramspeed[2],"GHz", $ramchan[0],$ramloc[2]
        $RAM4 = $ramcap[3],"GB",$ramman[3],$ramspeed[3],"GHz", $ramchan[0],$ramloc[3]

        $montimeoutac,$montimeoutdc = powercfg @(
            '/query'
            'scheme_current'
            '7516b95f-f776-4464-8c53-06167f40cc99'
            '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
        ) |
        Select-Object -Last 2 -Skip 1 |
        Foreach-Object {($_.Split(':')[1]) /60}
        
        $sleeptimeoutac,$sleeptimeoutdc = powercfg @(
            '/query'
            'scheme_current'
            '238c9fa8-0aad-41ed-83f4-97be242c8f20'
            '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
        ) |
        Select-Object -Last 2 -Skip 1 |
        Foreach-Object {($_.Split(':')[1]) /60}


    $Report = @"

**************************************************************    
Deployment Date:            $date
Serial Number:              $SerialNumber
Computer Name:              $computername

Activation Information
**************************************************************
Windows Version:            $winver
Windows Activation:         $winactivation

Hardware Information
**************************************************************
Manufacturer:               $manufacturer
Model:                      $model
CPU:                        $CPUInfo
Ram Info:
            Total RAM:      $RAM GB
                            $RAM1
                            $RAM2
                            $RAM3
                            $RAM4
Drive:                      $Drive $drivebrand $Bustype $Drivetype                           
Graphics:                   $graphics

Deployment Tasks
**************************************************************
OEM Info:   
            Manufacturer:   $oemman
            Support Hours:  $oemhours
            Support Phone:  $oemphone
            Support URL:    $oemurl 

Bitlocker:                  $bit
Platform folder:            $platform
OEM folder:                 $OEMfolder
Administrator:              $Adminstatus
Dotnet 3.5:                 $dotnet
Fast Startup:               $faststart
SmartDeploy:                $SmartDeploy

Power Options:  
    Monitor Timeout Battery:    $montimeoutdc Minutes
    Monitor Timeout Plugged in: $montimeoutac Minutes
    Sleep Timeout Battery:      $sleeptimeoutdc Minutes
    Sleep Timeout Plugged in:   $sleeptimeoutac Minutes 

Installed Software
**************************************************************
$plist
"@
        $keystext = Get-Content -Path $SaveLocation\keys.txt
        $Systeminfo = $keystext + $Report
        $Systeminfo | Out-File "$SaveLocation\$computername.txt" -Append
    }
    end {

    }
}
Get-SystemStatus
Remove-Item $PSCommandPath -Force 