function Get-SystemStatus {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$SaveLocation = "$env:SystemDrive\Setup Files"
        
    )

    begin {  
        #Get today's date 
        $date = Get-Date

        #Get Administrator Status
        $Admin = (Get-LocalUser -Name "Administrator").Enabled
        
        #Create CIMSession and call classes
        $cimsession = New-CimSession
        $CIMBIOS = Get-CimInstance -ClassName Win32_BIOS -CimSession $cimsession
        $CIMOS = Get-CimInstance -ClassName Win32_Operatingsystem -CimSession $cimsession
        $CIMComp = Get-CIMInstance -ClassName Win32_ComputerSystem -CimSession $cimsession
        $CIMVideo = Get-CimInstance -ClassName Win32_VideoController -CimSession $cimsession
        $RAMinfo = Get-CimInstance -Classname Win32_PhysicalMemory -CimSession $cimsession
        
        #Reference called classes to assign variables
        $serialnumber = $CIMBIOS.SerialNumber
        $computername = $CIMOS.PSComputerName
        $winver = $CIMOS.Caption
        $manufacturer = $CIMComp.manufacturer
        $RAM = $CIMComp | ForEach-Object {[math]::round($_.TotalPhysicalMemory /1GB)}
    
        #Additional CimInstance calls and variable assignment
        $model = (Get-CimInstance -Namespace root\wmi -ClassName MS_SystemInformation -CimSession $cimsession).SystemVersion
        $CPUInfo = (Get-CimInstance Win32_Processor -CimSession $cimsession).name
        $licensestatus = Get-CimInstance -ClassName SoftwareLicensingProduct -CimSession $cimsession -Filter "PartialProductKey IS NOT NULL" | Where-Object -Property Name -Like "Windows*"
        
       
        #Registry calls and variable assignment
        $Winbuild = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('DisplayVersion')
        $OEM =  Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" | Select-Object -Property Manufacturer,SupportHours,SupportPhone,SupportURL
        $oemman = $OEM.Manufacturer
        $oemhours = $OEM.SupportHours
        $oemphone = $OEM.SupportPhone
        $oemurl = $OEM.SupportURL
        $dotnet3 = (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name 'Version' -ErrorAction SilentlyContinue | ForEach-Object {$_.Version -as [System.Version]} | Where-Object {$_.Major -eq 3 -and $_.Minor -eq 5}).Count -ge 1
        $fsPath = "HKLM:\System\CurrentControlSet\Control\Session Manager\Power"
        $fsName = "HiberbootEnabled"
        $fsvalue = (Get-ItemProperty -Path $fsPath -Name $fsName).HiberbootEnabled

        #Physical disk information
        $Driveinfo = Get-PhysicalDisk
    }
    process {
        #check license status
        if ($licensestatus.LicenseStatus -eq 1){
            $winactivation = "Activated"
        }
        #Round drive sizes based on capacity to standard sizes
        if (($drivesize -gt "459")-and ($drivesize -lt "468")) { $Drive = "500 GB"}
        if (($drivesize -gt "469") -and ($drivesize -lt "479")) { $Drive = "512 GB"}
        if (($drivesize -gt "929") -and ($drivesize -lt "1024")) { $Drive = "1 TB"}
        if (($drivesize -gt "1800") -and ($drivesize -lt "2048")) { $Drive = "2 TB"}
       
        #Get BIOS information based on manufacturer
        if ($manufacturer -eq "Lenovo") {
            $bios = $CIMComp.OEMStringArray
            $b = $bios | Where-Object -FilterScript {$_ -like "*BIOS Boot Block Revision*"}
            $b1,$b2 = $b -split "Revision"
            $biosver = $b | Select-Object -Last 4
        }
        else {
            $bios = $CIMBIOS.Name
            $b1,$biosver = $bios -split "Ver."
        }

        #Get list of installed programs
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

        #Set variable status based on parameter values
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

        #Set Computer information PSCustomObject
        $Compinfo = [PSCustomObject]@{
            DeploymentDate      =   $date
            SerialNumber        =   $serialnumber
            ComputerName        =   $computername
        }
        
        #Set Activation information PSCustomObject
        $Activationinfo = [PSCustomObject]@{
            WindowsVersion      =   $winver
            WindowsBuild        =   $Winbuild
            WindowsActivation   =   $winactivation

        }

        #Set Manufacturer informatino PSCustomObject
        $Manufacturerinfo = [PSCustomObject]@{
            Manufacturer        =   $manufacturer
            Model               =   $model
        }

        #Set Hardware information PSCustomObject
        $Hardwareinfo = [PSCustomObject]@{
            CPU                 =   $CPUInfo
            TotalRAM            =   "$RAM GB"
            BIOSVersion         =   $biosver
        }

        #Set OEM information PSCustomObject
        $OEMinfo = [PSCustomObject]@{
            Manufacturer        =   $oemman
            SupportHours        =   $oemhours
            SupportPhone        =   $oemphone
            SupportURL          =   $oemurl 
        }

        #Set Deployment Tasks information PSCustomObject
        $Deployment = [PSCustomObject]@{
            Bitlocker       =   $bit
            Platformfolder  =   $platform
            OEMfolder       =   $OEMfolder
            Administrator   =   $Adminstatus
            Dotnet3         =   $dotnet
            FastStartup    =   $faststart
            SmartDeploy     =   $SmartDeploy
        }

        #Set Power Options informatino PSCustomObject
        $PowerOptions = [PSCustomObject]@{  
            MonitorTimeoutDC    =   "$montimeoutdc Minutes"
            MonitorTimeoutAC    =   "$montimeoutac Minutes"
            SleepTimeoutDC      =   "$sleeptimeoutdc Minutes"
            SleepTimeoutAC      =   "$sleeptimeoutac Minutes"
        }
        #Set RAM information PSCustomObject
        $RAM =  foreach ($r in $RAMinfo){
                    $ramcap = $r | ForEach-Object {[math]::round($_.Capacity /1GB)}
                    $ramman = $r.Manufacturer
                    $ramloc = $r.DeviceLocator
                    $ramspeed = $r.Speed
                    if ($r.InterleaveDataDepth -eq "2"){
                        $ramchan = "Dual Channel"
                    }
                    else {
                        $ramchan = "Single Channel"
                    }
                    [pscustomobject]@{
                    Capacity        =   "$ramcap GB"
                    Manufacturer    =   $ramman
                    Speed           =   $ramspeed
                    Channel         =   $ramchan
                    Location        =   $ramloc
                    }
                } 
        $RAMinfo = $RAM | Format-Table

        #Set drive information PSCustomObject
        $Driveinfo =    foreach ($d in $diskinfo){
	                        $drivesize = $d | ForEach-Object {[math]::round($_.size /1GB)}
	                        $driveman = $d.FriendlyName
	                        $drivebrand,$driveserial = $driveman -split " "
	                        $drivetype = $d.MediaType
	                        $drivebus = $d.Bustype
	                        if (($drivesize -gt "459")-and ($drivesize -lt "468")) { $Drive = "500 GB"}
                            if (($drivesize -gt "469") -and ($drivesize -lt "479")) { $Drive = "512 GB"}
                            if (($drivesize -gt "929") -and ($drivesize -lt "1024")) { $Drive = "1 TB"}
                            if (($drivesize -gt "1800") -and ($drivesize -lt "2048")) { $Drive = "2 TB"}
	                        [pscustomobject]@{
		                        Size	=	$Drive
		                        Brand	=	$drivebrand
		                        Form	=	$drivebus
		                        Type	=	$drivetype
	                        }
                        }
        
        #Set GPU information PSCustomObject
        $Graphicsinfo = foreach ($v in $CIMVideo){
                            $GPU 	        =	$v.description
                            $DriverVersion  =	$v.DriverVersion
                            [pscustomobject]@{
                                GPU	            =	$GPU
                                DriverVersion	=	$DriverVersion    
                            }
                        }
        
        
        #Monitor timeout powercfg parameters
        $monparam = @(
            '/query'
            'scheme_current' 
             '7516b95f-f776-4464-8c53-06167f40cc99'
            '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
        )
        $montimeoutac,$montimeoutdc =   powercfg @monparam |
                                            Select-Object -Last 2 -Skip 1 |
                                                Foreach-Object {($_.Split(':')[1]) /60}
        
        #Sleep timeout powercfg parameters
        $sleepparam = @(
            '/query'
            'scheme_current' 
             '7516b95f-f776-4464-8c53-06167f40cc99'
            '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
        )
        $sleeptimeoutac,$sleeptimeoutdc =   powercfg @sleepparam |
                                                Select-Object -Last 2 -Skip 1 |
                                                    Foreach-Object {($_.Split(':')[1]) /60}
        
        #Define keysfile location
        $keystext = Get-Content -Path $SaveLocation\keys.txt
        
        #Output System Status report to text file
        $SystemStatus = $keystext
        $SystemStatus | Out-File "$SaveLocation\$computername.txt"
        $Systeminfofile = "$SaveLocation\$computername.txt"
        
        #Append content to text file
        Add-Content -Path $Systeminfofile "`n**************************************************************"
        Add-Content -Path $Systeminfofile $($Compinfo | Format-List)
        Add-Content -Path $Systeminfofile "Activation Information"
        Add-Content -Path $Systeminfofile "`n**************************************************************"
        Add-Content -Path $Systeminfofile $($Activationinfo | Format-List)
        Add-Content -Path $Systeminfofile "Hardware Information"
        Add-Content -Path $Systeminfofile "`n**************************************************************"
        Add-Content -Path $Systeminfofile $($Manufacturerinfo | Format-List)
        Add-Content -Path $Systeminfofile $($Hardwareinfo | Format-List)
        Add-Content -Path $Systeminfofile "DIMM Information:"
        Add-Content -Path $Systeminfofile $($RAMInfo | Out-String)
        Add-Content -Path $Systeminfofile "Disk Information:"
        Add-Content -Path $Systeminfofile $($DriveInfo | Out-String)
        Add-Content -Path $Systeminfofile "Graphics Processors:"
        Add-Content -Path $Systeminfofile $($Graphicsinfo | Out-String)
        Add-Content -Path $Systeminfofile "Deployment Tasks"
        Add-Content -Path $Systeminfofile "`n**************************************************************"
        Add-Content -Path $Systeminfofile "OEM Informaton:"
        Add-Content -Path $Systeminfofile $($OEMinfo | Format-List)
        Add-Content -Path $Systeminfofile $($Deployment | Format-List)
        Add-Content -Path $Systeminfofile "Power Settings:"
        Add-Content -Path $Systeminfofile $($PowerOptions | Format-List)
        Add-Content -Path $Systeminfofile "Installed Software"
        Add-Content -Path $Systeminfofile "`n**************************************************************"
        Add-Content -Path $Systeminfofile $plist
    }
    end {
    }
  Get-SystemStatus
    }