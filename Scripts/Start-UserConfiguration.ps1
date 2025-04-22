
<#PSScriptInfo
.VERSION 1.1
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
Version 1.1: Enhanced error handling, centralized registry mapping, Windows version detection, logging, and improved robustness.
#>
<#
.SYNOPSIS
This script performs initial user configuration for the Start menu, taskbar, and desktop in the user context.

MIT LICENSE

Copyright (c) 2024 Timothy Wilson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.DESCRIPTION
This script configures user settings for the Start menu, taskbar, and desktop, including taskbar alignment, button visibility, and app removal. It supports both command-line parameters and a JSON configuration file.

.PARAMETER TaskbarAlignment
Set taskbar alignment. Valid set: "Left", "Center". Default: "Left"
.PARAMETER TaskViewButton
Set TaskView button visibility. Valid set: "Hide", "Show". Default: "Hide"
.PARAMETER CopilotButton
Set Copilot button visibility. Valid set: "Hide", "Show". Default: "Hide"
.PARAMETER WidgetButton
Set Widget button visibility. Valid set: "Hide", "Show". Default: "Hide"
.PARAMETER Tips
Set OS Tips visibility. Valid set: "Hide", "Show". Default: "Hide"
.PARAMETER LockscreenTips
Set Lockscreen Tips visibility. Valid set: "Hide", "Show". Default: "Hide"
.PARAMETER SearchboxMode
Set Searchbox visibility. Valid set: "Hide", "Icon", "Searchbox", "SearchButton". Default: "SearchButton"
.PARAMETER NewOutlook
Set "New Outlook" toggle visibility in Microsoft Outlook. Valid set: "Hide", "Show". Default: "Hide"
.PARAMETER StartFolders
Switch. Enable visibility of Documents, File Explorer, and Settings in the Start menu.
.PARAMETER UnpinApps
Switch. Unpin Microsoft Edge, Microsoft Store, and Copilot from the Taskbar.
.PARAMETER OfficeShortcuts
Switch. Add shortcuts to the desktop for Microsoft Word, Outlook, and Excel.
.PARAMETER RemoveBloat
Switch. Uninstall MicrosoftTeams, Microsoft.OutlookForWindows, Microsoft.OfficeHub, Microsoft.GamingApp, Spotify, and LinkedInForWindows for the logged-in user.
.PARAMETER ConfigFile
Path to a JSON configuration file to override parameter values.
.PARAMETER LogPath
Path to a log file to record script execution details.

.EXAMPLE
.\Start-UserConfiguration.ps1 -UnpinApps -OfficeShortcuts -RemoveBloat
Runs the script with default settings plus unpinning apps, adding Office shortcuts, and removing bloatware.

.EXAMPLE
.\Start-UserConfiguration.ps1 -ConfigFile ".\config.json" -LogPath ".\log.txt"
Runs the script using settings from a JSON configuration file and logs output to a file.

.EXAMPLE
.\Start-UserConfiguration.ps1 -TaskbarAlignment Left -TaskViewButton Hide -CopilotButton Hide -WidgetButton Hide -Tips Hide -LockscreenTips Hide -SearchboxMode SearchButton -NewOutlook Hide -StartFolders -UnpinApps -OfficeShortcuts -RemoveBloat -LogPath ".\log.txt"
Runs the script with explicit settings and logs output.

.NOTES
- Some changes (e.g., taskbar settings) may require restarting Windows Explorer to take effect. Run 'Stop-Process -Name explorer -Force' manually or log out and back in.
- The script operates in the current user context (HKCU). For system-wide changes, modify to use HKLM or target other user profiles.
- Ensure Microsoft Office is installed before using -OfficeShortcuts, as the script assumes shortcuts exist in the default location.
#>
[Cmdletbinding()]
param(
    [ValidateSet("Left","Center")]
    [string]$TaskbarAlignment = "Left",
    [ValidateSet("Show","Hide")]
    [string]$TaskViewButton = "Hide",
    [ValidateSet("Show","Hide")]
    [string]$CopilotButton = "Hide",
    [ValidateSet("Show","Hide")]
    [string]$WidgetsButton = "Hide",
    [ValidateSet("Show","Hide")]
    [string]$Tips = "Hide",
    [ValidateSet("Show","Hide")]
    [string]$LockscreenTips = "Hide",
    [ValidateSet("Hide","Icon","Searchbox","SearchButton")]
    [string]$SearchboxMode = "SearchButton",
    [ValidateSet("Show","Hide")]
    [string]$NewOutlook = "Hide",
    [switch]$StartFolders,
    [switch]$UnpinApps,
    [switch]$OfficeShortcuts,
    [switch]$RemoveBloat,
    [string]$ConfigFile,
    [string]$LogPath
)
begin {
    # Start logging if LogPath is specified
    if ($LogPath) {
        try {
            Start-Transcript -Path $LogPath -Append -ErrorAction Stop
        }
        catch {
            Write-Warning "Unable to start logging to $LogPath. Error: $_"
        }
    }
    # Load configuration from JSON file if specified
    if ($ConfigFile) {
        try {
            if (Test-Path $ConfigFile) {
                $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
                $TaskbarAlignment = $config.TaskbarAlignment ?? $TaskbarAlignment
                $TaskViewButton = $config.TaskViewButton ?? $TaskViewButton
                $CopilotButton = $config.CopilotButton ?? $CopilotButton
                $WidgetButton = $config.WidgetButton ?? $WidgetButton
                $Tips = $config.Tips ?? $Tips
                $LockscreenTips = $config.LockscreenTips ?? $LockscreenTips
                $SearchboxMode = $config.SearchboxMode ?? $SearchboxMode
                $NewOutlook = $config.NewOutlook ?? $NewOutlook
                $StartFolders = $config.StartFolders ?? $StartFolders
                $UnpinApps = $config.UnpinApps ?? $UnpinApps
                $OfficeShortcuts = $config.OfficeShortcuts ?? $OfficeShortcuts
                $RemoveBloat = $config.RemoveBloat ?? $RemoveBloat
                Write-Verbose "Loaded configuration from $ConfigFile"
            }
            else {
                Write-Warning "Configuration file $ConfigFile not found. Using parameter defaults."
            }
        }
        catch {
            Write-Warning "Failed to parse configuration file $ConfigFile. Error: $_"
        }
    }

    # Determine Windows version
    try {
        $WinVersion = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).BuildNumber
        Write-Verbose "Detected Windows build: $WinVersion"
    }
    catch {
        Write-Warning "Unable to determine Windows version. Assuming Windows 10 behavior."
        $WinVersion = 19044  # Fallback to a Windows 10 build
    }

    # Centralized registry value mapping
    $RegistryMap = @{
        TaskbarAlignment = @{ Left = 0; Center = 1 }
        TaskViewButton   = @{ Hide = 0; Show = 1 }
        CopilotButton    = @{ Hide = 0; Show = 1 }
        WidgetButton     = @{ Hide = 0; Show = 1 }
        Tips             = @{ Hide = 0; Show = 1 }
        LockscreenTips   = @{ Hide = 0; Show = 1 }
        SearchboxMode    = @{ Hide = 0; Icon = 1; Searchbox = 2; SearchButton = 3 }
        NewOutlook       = @{ Hide = 0; Show = 1 }
    }
}
process {
    # Configure registry settings
    $Params = @(
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name  = "TaskbarAl"
            Value = $RegistryMap.TaskbarAlignment[$TaskbarAlignment]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name  = "ShowTaskViewButton"
            Value = $RegistryMap.TaskViewButton[$TaskViewButton]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name  = "ShowCopilotButton"
            Value = $RegistryMap.CopilotButton[$CopilotButton]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name  = "TaskbarDa"
            Value = $RegistryMap.WidgetButton[$WidgetButton]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Name  = "SubscribedContent-338387Enabled"
            Value = $RegistryMap.Tips[$Tips]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Name  = "RotatingLockScreenOverlayEnabled"
            Value = $RegistryMap.LockscreenTips[$LockscreenTips]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
            Name  = "SearchboxTaskbarMode"
            Value = $RegistryMap.SearchboxMode[$SearchboxMode]
        }
        @{
            Path  = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
            Name  = "HideNewOutlookToggle"
            Value = $RegistryMap.NewOutlook[$NewOutlook]
        }
    )

    foreach ($p in $Params) {
        try {
            Write-Verbose "Setting registry key $($p.Path)\$($p.Name) to $($p.Value)"
            if (!(Test-Path $p.Path)) {
                New-Item -Path $p.Path -Force -ErrorAction Stop | Out-Null
            }
            New-ItemProperty @p -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Failed to set registry key $($p.Path)\$($p.Name). Error: $_"
        }
    }
    #Set start folders visibility
    if ($StartFolders) {
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
    }
    #Unpin listed apps from taskbar
    if ($UnpinApps) {
        $apps = 'Microsoft Edge', 'Microsoft Store', 'Copilot'
        foreach ($appname in $apps) {
            try {
                Write-Verbose "Unpinning $appname from Taskbar"
                $shell = New-Object -ComObject Shell.Application
                $folder = $shell.Namespace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}')
                $item = $folder.Items() | Where-Object { $_.Name -eq $appname }
                if ($item) {
                    $verb = $item.Verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from taskbar' }
                    if ($verb) {
                        $verb.DoIt()
                        Write-Verbose "$appname unpinned from Taskbar"
                    }
                    else {
                        Write-Verbose "$appname is not pinned to Taskbar"
                    }
                }
                else {
                    Write-Verbose "$appname not found in pinned apps"
                }
            }
            catch {
                Write-Error "Unable to unpin $appname from Taskbar. Error: $_"
            }
        }
    }
    #Add listed Microsoft Office shortcuts to the Desktop   
    if ($OfficeShortcuts) {         
        $programs = "C:\Programdata\Microsoft\Windows\Start Menu\Programs"
        $desktop = [environment]::getfolderpath(“desktop”)
        $shortcuts = @(
            "Word.lnk",
            "Outlook (classic).lnk",
            "Excel.lnk"
        )
        foreach ($shortcut in $shortcuts) {
            try {
                if (Test-Path "$programs\$shortcut"){
                    Write-Verbose -Message "Adding $Shortcut to the Desktop"
                    Copy-Item -Path "$programs\$shortcut" -Destination "$desktop" -Force
                }
                else {
                    Write-Warning "Shortcut $shortcut not found in $programs"
                }
            }
            catch {
                Write-Error "Unable to add $shortcut to Desktop. Error: $_"
            }
        }
    }
    if ($RemoveBloat) {
        $applist = @(
            'MicrosoftTeams',
            'Microsoft.OutlookForWindows',
            'Microsoft.OfficeHub',
            'Microsoft.GamingApp',
            'Spotify',
            'LinkedInForWindows'
        )
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
}
end {
    Write-Warning "Some changes may require restarting Windows Explorer. Run 'Stop-Process -Name explorer -Force' or log out and back in to apply."
    if ($LogPath) {
        try {
            Stop-Transcript -ErrorAction Stop
        }
        catch {
            Write-Warning "Unable to stop logging. Error: $_"
        }
    }

}