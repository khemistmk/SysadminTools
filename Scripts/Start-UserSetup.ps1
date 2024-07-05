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
            if (Get-Module -ListAvailable -Name Read-HTMLTable) {
            } 
            else {
                Install-Module -Name Read-HTMLTable
                Import-Module-Name Read-HTMLTable
            }
            $table = Read-HTMLTable -InputObject $HTMLfile
            
            $table | Where-Object -Filterscript {$_.Status -like "*User*" -or $_.Company -like "*User*" } |Select-Object -Property Status | Export-Csv $outfile
        }
    
        end {
    
        }
    
    }