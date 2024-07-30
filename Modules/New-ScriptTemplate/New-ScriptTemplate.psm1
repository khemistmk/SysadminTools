<#PSScriptInfo

.VERSION 1.0

.GUID 4c227114-98bb-4bbb-95f7-592a3d9c4592

.AUTHOR Timothy Wilson

.COMPANYNAME 

.COPYRIGHT 2024 Timothy Wilson. All rights reserved.

.TAGS Powershell Scripts

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
This script will aid in the generation of new advanced scripts by setting a default template.
 
MIT LICENSE
 
Copyright (c) Timothy Wilson
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
.DESCRIPTION
This script will aid in the generation of new advanced scripts and Modules by generating a default template. 

.PARAMETER ScriptName
The name of the new Script to be generated.

.PARAMETER ScriptType
Type of script to be generated, either Module or Script.
Modules will have a directory of the same name generated in the Output Directory.

.PARAMETER OutputDirectory
The directory to output the newly generated script.
Default: "."

.PARAMETER TempFile
The directory for writing temporary files which will later be removed.
Default: TempDirectory = "$ENV:LOCALAPPDATA\temp"

.EXAMPLE
.\New-ScriptTemplate -Outfile .\New-Script.ps1

.EXAMPLE
.\New-ScriptTemplate.ps1 -Outfile "C:\Scripts\MyNewScript.ps1" -TempDirectory "C:\Temp"
 
#>
function New-ScriptTemplate {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ScriptName,

        [Parameter(Mandatory = $true, Position = 1)]
        [Validateset("Script","Module")]
        [string]$ScriptType,

        [Parameter()]
        [string]$OutputDirectory = ".",

        [Parameter()]
        [string]$Tempfile = "$env:LOCALAPPDATA\temp\temp.ps1"
    )
    
    begin {
            
    }
    
    process {
        $Parms = @{
            Path = $Tempfile
            Verbose = $True
            Version = "1.0"
            Author = "Timothy Wilson"
            Copyright = "2024 Timothy Wilson. All rights reserved."
            Tags = @("Tag1","Tag2")
            ProjectUri = "https://github.com/khemistmk/_Repo_Name"
            PassThru = $True
            ReleaseNotes = @("Version 1.0: Original published version")
        }

        $Structure = @"
<#
.SYNOPSIS
 
MIT LICENSE
 
Copyright (c) 2020 Microsoft
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
.DESCRIPTION
 
.PARAMETER

.PARAMETER

.PARAMETER

.EXAMPLE

.EXAMPLE

.EXAMPLE
 
#>
function $ScriptName {

    [CmdletBinding()]
    param (
    )
    
    begin {
            
    }
    
    process {

	}
    end {

	}
"@
    switch ($ScriptType) {
        'Script' {
            New-ScriptFileInfo @Parms
            $metainfo = Get-Content $Tempfile | Select-Object -SkipLast 10
            $scripttemplate = $metainfo + $structure
            $scripttemplate | Out-File $OutputDirectory\$ScriptName.ps1
        }
        'Module' {
            New-Item -Path $OutputDirectory\$ScriptName -ItemType Directory
            $Structure | Out-File $OutputDirectory\$ScriptName\$ScriptName.psm1
        }
    }
        
    }
    end {
        if (Test-Path $Tempfile) {
            Remove-Item $Tempfile
        }
    }
}