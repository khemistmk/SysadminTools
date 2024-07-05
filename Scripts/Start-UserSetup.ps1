function Start-UserSetup {
    <#
        .SYNOPSIS 
            This script imports HTML local files and exports as CSV in the local folder.
        .DESCRIPTION
            This script utilizes Import-HTML from the power
    #>
        [CmdletBinding()]
        param (
            [parameter(mandatory=$true)]
            [string]$HTMLFile,
    
            [Parameter(mandatory=$true)]
            [string]$Outfile
        )
    
        begin {
            
        }
    
        process {
            function Alignleft {
                $RegKey = "HKLM:\SOFTWARE\Policies\Lenovo\System Update\UserSettings\General"
                $RegName = "AdminCommandLine"
                $RegValue = "/CM -search A -action INSTALL -includerebootpackages 3 -noicon -noreboot -exporttowmi"    
                # Create Subkeys if they don't exist
                if (!(Test-Path $RegKey)) {
                    New-Item -Path $RegKey -Force | Out-Null
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue | Out-Null
                }
                else {
                    New-ItemProperty -Path $RegKey -Name $RegName -Value $RegValue -Force | Out-Null
                } 
            }
        }
      
    
        end {
    
        }
    
    }