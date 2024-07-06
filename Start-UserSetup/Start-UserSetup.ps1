function Start-UserSetup {
    <#
        .SYNOPSIS 
            This script configures initial user settings and defaults
        .DESCRIPTION
            This script configures initial user settings and defaults
    #>
        [CmdletBinding()]
        param (
            [parameter(mandatory=$true)]
            [Validateset("All","Alignleft","Aligncenter","Unpinall","")]
            [string]$Startacions
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

            function UnPin-Apps { 
                $apps = 'Microsoft Edge', 'Microsoft Store'
                foreach ( $appname in $apps) {
                    try {
                        ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | %{$_.DoIt()}
                    return "App '$appname' unpinned from Taskbar"
                    }        
                    catch {
                    Write-Error "Error Unpinning App! (App-Name correct?)"
                    }
                }
            }


            if ($Startaction -eq "All")
                Set-TaskbarAlignleft
                Disable-CopilotButton
                Disable-LockscreenTips
                Disable-WidgetsButton
                Disable-SearchBox
                Set-StartFolders
                UnPin-Apps
        }
      
    
        end {
    
        }
    
    }