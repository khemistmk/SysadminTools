
<#PSScriptInfo

.VERSION 1.0

.GUID 2ff5dbce-71a6-434b-bf3f-a7b4e619cc4c

.AUTHOR Timothy Wilson

.COMPANYNAME 

.COPYRIGHT 2024 Timothy Wilson. All rights reserved

.TAGS Windows Script

.LICENSEURI 

.PROJECTURI https://github.com/khemistmk/SysadminTools

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0: Original published version.

#>

<# 

.DESCRIPTION 
 This script will perform initial user configuration to the start menu, taskbar, and desktop. 

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
	Uninstalls MicrosoftTeams, Microsoft.OutlookForWindows,Microsoft.OfficeHub,Microsoft.GamingApp,Spotify, and LinkedInForWindows
- Disable-NewOutlookButton
	*Disables New Outlook button in Microsoft Outlook

.EXAMPLE
Start-UserConfiguration
 
#>
function Start-UserConfiguration {
    [Cmdletbinding()]
    param(
        [Parameter()]
        [ValidateSet("Left","Center")]
        [string]$TaskbarAlignment = "Left",

        [Parameter()]
        [ValidateSet("Show","Hide")]
        [string]$TaskViewButton = "Hide",

        [Parameter()]
        [ValidateSet("Show","Hide")]
        [string]$CopilotButton = "Hide",

        [Parameter()]
        [ValidateSet("Show","Hide")]
        [string]$WidgetsButton = "Hide",

        [Parameter()]
        [ValidateSet("Show","Hide")]
        [string]$Tips = "Hide",

        [Parameter()]
        [ValidateSet("Show","Hide")]
        [string]$LockscreenTips = "Hide",

        [Parameter()]
        [ValidateSet("Hide","Icon","Searchbox","SearchButton")]
        [string]$SearchboxMode = "SearchButton",

        [Parameter()]
        [ValidateSet("Show","Hide")]
        [string]$NewOutlook = "Hide"
    )
    begin {
        
    }
    process {
        switch ($TaskbarAlignment) {
            'Left'{$TA = "000000"}
            'Center'{$TA = "000001"}
        }
        switch ($TaskViewButton) {
            'Hide'{$TV = "000000"}
            'Show'{$TV = "000001"}
        }
        switch ($CopilotButton) {
            'Hide'{$CB = "000000"}
            'Show'{$CB = "000001"}
        }
        switch ($WidgetsButton) {
            'Hide'{$WB = "000000"}
            'Show'{$WB = "000001"}
        }
        switch ($Tips) {
            'Hide'{$T = "000000"}
            'Show'{$T = "000001"}
        }
        switch ($LockscreenTips) {
            'Hide'{$LT = "000000"}
            'Show'{$LT = "000001"}
        }
        switch ($SearchboxMode) {
            'Hide'{$SB = "000000"}
            'Icon'{$SB = "000001"}
            'Searchbox' {$SB = "000002"}
            'SearchButton' {$SB = "000003"}
        }
        switch ($NewOutlook) {
            'Hide'{$NO = "000000"}
            'Show'{$NO = "000001"}
        }

            $Params = @(
                @{
                    #Set Taskbar Align Left
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    Name = "TaskbarAl"
                    Value = $TA   
                }
                @{
                    #Hide TaskView Button
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    Name = "ShowTaskViewButton"
                    Value = $TV 
                }
                @{
                    #Hide Copilot Button
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    Name = "ShowCopilotButton"
                    Value = $CB 
                }
                @{
                    #Hide Widgets Button
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    Name = "TaskbarDa"
                    Value = $WB 
                }
                @{
                    #Disable Tips
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                    Name = "SubscribedContent-338387Enabled"
                    Value = $T
                }
                @{
                    #Disable Lockscreen Tips
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                    Name = "RotatingLockScreenOverlayEnabled"
                    Value = $LT
                }
                @{
                    #Set Searchbox to small with label
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
                    Name = "SearchboxTaskbarMode"
                    Value = $SB
                }
                @{
                    #Disable "Try New Outlook" button in Microsoft Outlook
                    Path = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
                    Name = "HideNewOutlookToggle"
                    Value = $NO 
                }
            )
        
            foreach ($p in $Params) {
                    # Create Subkeys if they don't exist
                    if (!(Test-Path $p.Path)) {
                        Write-Verbose -Message "Setting Registry setting"
                        New-Item -Path $p.Path -Force | Out-Null
                        New-ItemProperty @p -PropertyType DWORD -Force | Out-Null
                    }
                    else {
                        Write-Verbose -Message "Setting Registry setting"
                        New-ItemProperty @p -PropertyType DWORD -Force | Out-Null
                    } 
            }

            try {
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
            catch {
                Write-Error -Message "Unable to set Registry setting $RegName"
            }
            
            $apps = 'Microsoft Edge','Microsoft Store','Copilot'
            foreach ($appname in $apps){
                try {
                    Write-Verbose -Message "Unpinning Microsoft Edge, Microsoft Store, and Copilot from Taskbar"    
                    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() |
                    Where-Object {$_.Name -eq $appname}).Verbs() |
                    Where-Object {$_.Name.replace('&','') -match 'Unpin from taskbar'} |
                    ForEach-Object {$_.DoIt()}
                    Write-Host "App '$appname' unpinned from Taskbar"
                }
                catch {
                    Write-Error -Message "Unable to unpin $appname from Taskbar"
                }
            }
                        
            $programs = "C:\Programdata\Microsoft\Windows\Start Menu\Programs"
            $shortcuts = "Word.lnk", "Outlook.lnk", "Excel.lnk"
            foreach ($shortcut in $shortcuts) {
                try {
                    if (Test-Path "$programs\$shortcut"){
                        Write-Verbose -Message "Adding $Shortcut to the Desktop"
                        Copy-Item -Path "$programs\$shortcut" -Destination "$($env:USERPROFILE)\Desktop" -Force
                    }
                }
                catch {
                    Write-Error -Message "Unable to add $shortcut to the Desktop"
                }
            }

            $applist = 'MicrosoftTeams','Microsoft.OutlookForWindows','Microsoft.OfficeHub','Microsoft.GamingApp','Spotify','LinkedInForWindows'
            foreach ($app in $applist) {
                try {        
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
                catch {
                    Write-Error -Message "Unable to remove package $app"
                }

            }    
    }
    end {

    }
}
