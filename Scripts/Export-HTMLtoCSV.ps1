function Export-HTMLtoCSV {
<#
    .SYNOPSIS 
        This script imports HTML local files and exports as CSV in the local folder.
    .DESCRIPTION
        This script utilizes Import-HTML from the power
#>
    [CmdletBinding()]
    param {
        [parameter(mandatory=$true)]
        [validatescript({(Get-Item $_).Extension -eq '.txt'})]
$HTMLFile
        [string]$HTMLFile = "$PSScriptroot\*.html"

        [Parameter()]
        [string]$Outfile = "$PDScriptroot\Converted.csv"
    }

    begin {
        if (Get-Module -ListAvailable -Name Read-HTMLTable) {
    process
} 
else {
    Install-Module -Name Read-HTMLTable
    Import-Module-Name Read-HTMLTable
}
    }

    process {
        $table = Read-HTMLTable -InputObject $HTMLfile
        
        $table | Where-Object -Filterscript {$_.Status -like "*User*" -or $_.Company -like "*User*" } |Select-Object -Property Status | Export-Csv $outfile
    }

    end {

    }

}

Import-Module -Name Read-HTMLTable
$table | Where-Object -Filterscript {$_.Status -like "*User*" -or $_.Company -like "*User*" } |Select-Object -Property Status | Export-Csv c:\temp\users.csv