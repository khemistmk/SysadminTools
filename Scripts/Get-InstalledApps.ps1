function Get-installedApps {
    param( $computers=$env:computername )
        $array = @()
            foreach($pc in $computers){
                $computername=$pc
                #Define the variable to hold the location of Currently Installed Programs
                $unistalKeys=@("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall","SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")
                $unistalKeys| ForEach-Object{
                $UninstallKey=$_
                #Create an instance of the Registry Object and open the HKLM base key
                $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computername)
                #Drill down into the Uninstall key using the OpenSubKey Method
                $regkey=$reg.OpenSubKey($UninstallKey)
                #Retrieve an array of string that contain all the subkey names
                $subkeys=$regkey.GetSubKeyNames()
                #Open each Subkey and use GetValue Method to return the required values for each
                foreach($key in $subkeys){
                    $thisKey=$UninstallKey+”\\���+$key
                    $thisSubKey=$reg.OpenSubKey($thisKey)
                    $obj = New-Object PSObject
                    $obj | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value ($computername).ToUpper()
                    $obj | Add-Member -MemberType NoteProperty -Name “DisplayName” -Value $($thisSubKey.GetValue(“DisplayName”))
                    $obj | Add-Member -MemberType NoteProperty -Name “DisplayVersion” -Value $($thisSubKey.GetValue(“DisplayVersion”))
                    $obj | Add-Member -MemberType NoteProperty -Name “InstallLocation” -Value $($thisSubKey.GetValue(“InstallLocation”))
                    $obj | Add-Member -MemberType NoteProperty -Name “Publisher” -Value $($thisSubKey.GetValue(“Publisher”))
                    $array += $obj
                }
                }
         }
    $array |sort-object  -Property displayname| Select-Object * -unique
  }
  
  Get-installedApps
  
  # GET DURATION
  measure-comman {Get-installedApps}