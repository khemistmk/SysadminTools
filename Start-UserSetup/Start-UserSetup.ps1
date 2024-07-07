function Start-UserSetup {
    <#
        .SYNOPSIS 
            This script configures initial user settings and defaults
        .DESCRIPTION
            This script configures initial user settings and defaults
    #>
        [CmdletBinding()]
        param (
        )
    
        begin {
            
        }
    
        process {
            function Set-TaskbarAlignleft {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                $RegName = "TaskbarAl"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-TaskView {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                $RegName = "ShowTaskViewButton"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-CopilotButton {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                $RegName = "ShowCopilotButton"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-LockscreenTips {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                $RegName = "SubscribedContent-338387Enabled"
                $RegValue = "00000000"
                $RegName2 = "RotatingLockScreenOverlayEnabled"
                $RegValue2 = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName2 -Value $RegValue2 -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName2 -Value $RegValue2 -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-WidgetsButton {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                $RegName = "TaskbarDa"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-SearchBox {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
                $RegName = "SearchboxTaskbarMode"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Set-StartFolders {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
                $RegName = "VisiblePlaces"
                $hex = "86087352AA5143429F7B2776584659D4BC248A140CD68942A0806ED9BBA24882CED5342D5AFA434582F222E6EAF7773C"
                $Regvalue = [byte[]] -split ($hex -replace '..', '0x$& ')   
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType Binary -Force | Out-Null
                }
                else {
                    Set-ItemProperty -Path $RegKey -Name $RegName -Value ([byte[]]($RegValue)) -Type Binary -Force | Out-Null
                } 
            }

            function Remove-TaskbarApps { 
                $apps = 'Microsoft Edge','Microsoft Store'
                foreach ($appname in $apps){    
                    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() |
                    Where-Object {$_.Name -eq $appname}).Verbs() |
                    Where-Object {$_.Name.replace('&','') -match 'Unpin from taskbar'} |
                    ForEach-Object {$_.DoIt()}
                    Write-Host "App '$appname' unpinned from Taskbar"
                }
            }
            
            function Add-TaskbarApps { 
                $apps = 'Google Chrome','Microsoft Outlook'
                foreach ($appname in $apps){    
                    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() |
                    Where-Object {$_.Name -eq $appname}).Verbs() |
                    Where-Object {$_.Name.replace('&','') -match 'Pin to taskbar'} |
                    ForEach-Object {$_.DoIt()}
                    Write-Host "App '$appname' pinned to Taskbar"
                }
            }

            function Set-OfficeShortcuts {
                $path = "C:\Programdata\Microsoft\Windows\Start Menu\Programs"
                $shortcuts = "Word.lnk", "Outlook.lnk", "Excel.lnk"
                foreach ($shortcut in $shortcuts) {
                    if (Test-Path "$path\$shortcut"){
                        Copy-Item -Path "$path\$shortcut" -Destination "$($env:USERPROFILE)\Desktop" -Force
                    }
                }
            }

            function Remove-OutlooknewandTeams {
                Get-AppxPackage | Where-Object {$_.Name -eq 'MicrosoftTeams'} | Remove-AppxPackage
                Get-AppxPackage | Where-Object {$_.Name -eq 'Microsoft.OutlookForWindows'} | Remove-AppxPackage
                Get-AppxPackage | Where-Object {$_.Name -eq 'Microsoft.MicrosoftOfficeHub'} | Remove-AppxPackage
            }

        Set-TaskbarAlignleft
        Disable-TaskView
        Disable-CopilotButton
        Disable-LockscreenTips
        Disable-WidgetsButton
        Disable-SearchBox
        Set-StartFolders
        Remove-TaskbarApps
        Set-OfficeShortcuts
        Remove-OutlooknewandTeams
        }
      
    
        end {
    
        }
    
    }