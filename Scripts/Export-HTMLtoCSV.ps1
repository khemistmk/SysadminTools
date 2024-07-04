function Export-HTMLtoCSV {
<#
    .SYNOPSIS 
        This script imports HTML local files and exports as CSV in the local folder.
    .DESCRIPTION
        This script utilizes Import-HTML from the power
#>
    [CmdletBinding()]
    param {

    }

    begin {

    }

    process {
        Import-Module -Name Read-HTMLTable
        
        $table | Where-Object -Filterscript {$_.Status -like "*User*" -or $_.Company -like "*User*" } |Select-Object -Property Status | Export-Csv c:\temp\users.csv
    }

    end {

    }

}

Import-Module -Name Read-HTMLTable
$table | Where-Object -Filterscript {$_.Status -like "*User*" -or $_.Company -like "*User*" } |Select-Object -Property Status | Export-Csv c:\temp\users.csv