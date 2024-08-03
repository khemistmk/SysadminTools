
<#PSScriptInfo

.VERSION 1.0

.GUID 2ff5dbce-71a6-434b-bf3f-a7b4e619cc4c

.AUTHOR Timothy Wilson

.COMPANYNAME 

.COPYRIGHT 2024 Timothy Wilson. All rights reserved.

.TAGS Windows Script

.LICENSEURI 

.PROJECTURI https://github.com/khemistmk/SysadminTools

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0: Original published version

#>
<#
.SYNOPSIS

This script will perform initial user configuration to the start menu, taskbar, and desktop.
 
MIT LICENSE
 
Copyright (c) 2024 Timothy Wilson
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
.DESCRIPTION
This script will perform initial user configuration to the start menu, taskbar, and desktop.

Functions:
- Set-TaskbarAlignleft
- Disable-TaskView
- DisableCopilotButton
- Disable-LockscreenTips
- Disable-WidgetButton
- Disable-SearchBox
- Set-StartFolders 
	* Enables Documents, File Explorer, and Settings.
- Remove-TaskbarApps
	* Removes Microsoft Edge, Microsoft Store, and Copilot from Taskbar.
- Set-OfficeShortcuts
	* Sets Desktop shortcuts for Microsoft Word, Outlook, and Excel.
- Remove-Bloatapps
	* Uninstalls 'MicrosoftTeams','Microsoft.OutlookForWindows','Microsoft.OfficeHub','Microsoft.GamingApp','Spotify', and 'LinkedInForWindows'
- Disable-NewOutlookButton
	*Disables New Outlook button in Microsoft Outlook

.EXAMPLE
Start-UserConfiguration
 
#>
function Start-UserConfiguration {
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
                    Write-Verbose -Message "Setting Taskbar Align Left"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Setting Taskbar Align Left"
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-TaskView {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                $RegName = "ShowTaskViewButton"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    Write-Verbose -Message "Hiding TaskView Button"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Hiding TaskView Button"
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-CopilotButton {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                $RegName = "ShowCopilotButton"
                $RegValue = "00000000"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    Write-Verbose -Message "Hiding Copilot Button"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Hiding Copilot Button"
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
                    Write-Verbose -Message "Disabling LockScreen Tips"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName2 -Value $RegValue2 -PropertyType DWORD -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Disabling LockScreen Tips"
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
                    Write-Verbose -Message "Hiding Widgets Button"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Hiding Widgets Button"
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
            }

            function Disable-SearchBox {
                $RegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
                $RegName = "SearchboxTaskbarMode"
                $RegValue = "00000003"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    Write-Verbose -Message "Setting Searchbox to short with label"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Setting Searchbox to short with label"
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
                    Write-Verbose -Message "Enabling Documents, File Explorer, and Settings Folders"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType Binary -Force | Out-Null
                }
                else {
                    Write-Verbose -Message "Enabling Documents, File Explorer, and Settings Folders"
                    Set-ItemProperty -Path $RegKey -Name $RegName -Value ([byte[]]($RegValue)) -Type Binary -Force | Out-Null
                } 
            }

            function Remove-TaskbarApps { 
                $apps = 'Microsoft Edge','Microsoft Store','Copilot'
                foreach ($appname in $apps){
                    Write-Verbose -Message "Unpinning Microsoft Edge, Microsoft Store, and Copilot from Taskbar"    
                    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() |
                    Where-Object {$_.Name -eq $appname}).Verbs() |
                    Where-Object {$_.Name.replace('&','') -match 'Unpin from taskbar'} |
                    ForEach-Object {$_.DoIt()}
                    Write-Host "App '$appname' unpinned from Taskbar"
                }
            }
            
            function Set-OfficeShortcuts {
                $path = "C:\Programdata\Microsoft\Windows\Start Menu\Programs"
                $shortcuts = "Word.lnk", "Outlook.lnk", "Excel.lnk"
                foreach ($shortcut in $shortcuts) {
                    if (Test-Path "$path\$shortcut"){
                        Write-Verbose -Message "Adding $Shortcut to the Desktop"
                        Copy-Item -Path "$path\$shortcut" -Destination "$($env:USERPROFILE)\Desktop" -Force
                    }
                }
            }

            function Remove-Bloatapps {
                $applist = 'MicrosoftTeams','Microsoft.OutlookForWindows','Microsoft.OfficeHub','Microsoft.GamingApp','Spotify','LinkedInForWindows'
                foreach ($app in $applist) {
                    
                    if ($WinVersion -ge 22000){
                        # Windows 11 build 22000 or later
                        Write-Verbose -Message "Removing $app..."
                        Get-AppxPackage -Name $app | Remove-AppxPackage
                    }
                    else {
                        # Windows 10
                        Write-Verbose -Message "Removing $app"
                        Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource | Remove-AppxPackage
                    }
                }

            }

            function Disable-NewOutlookButton {
                $RegKey = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
                $RegName = "HideNewOutlookToggle"
                $RegValue = "00000001"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    Write-Verbose -Message "Hiding New Outlook Button in Outlook"
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -PropertyType DWORD -Force | Out-Null
                } 
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
        Remove-Bloatapps
        Disable-NewOutlookButton
        }
      
    
        end {
    
        }
    
    }