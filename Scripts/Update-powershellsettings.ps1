
    #region Powershell Modules
    Write-Verbose -Message 'Starting PS Config'
    # need to add logic to detect if powershell 7 is running the script cause it not good right now

    Write-Verbose -Message 'Configure TLS and SSL'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::'tls12'

    Write-Verbose -Message 'Install Latest Package Provider'
    Install-PackageProvider -Name nuget -Scope CurrentUser -Force

    Write-Verbose -Message 'Configure PS Gallery to be trusted'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Write-Verbose -Message 'Save modules to temp to allow for import and overwrite without being in use'
    Save-Module -Path $env:temp -Name 'powershellget'

    Write-Verbose -Message 'Remove (Un-Import) currently loaded modules'
    Remove-Module -Force -Name powershelget, PackageManagement, psreadline

    Write-Verbose -Message 'Import updated powershekkget and package managment'
    Import-Module $env:temp\PackageManagement -Force
    Import-Module $env:temp\PowershellGet -Force

    Write-Verbose -Message 'Install NUGET for all users'
    Install-PackageProvider -Name nuget -Scope AllUsers -Force

    Write-Verbose -Message 'COnfigure all users install default POSH Modules'

    $ModuleSplat = @{
        AllowClobber       = $true
        SkipPublisherCheck = $true
        Scope              = 'AllUsers'
        force              = $true
    }

    $ModuleUpdateList = @(
        'powershellget'
        'PSReadline'
        'pswindowsupdate'
        'pester'
        'PSScriptAnalyzer'
    )

    foreach ($SingleModule in $ModuleUpdateList)
    {
        Write-Verbose -Message "Install $SingleModule Module for all users"
        Install-Module @ModuleSplat -Name $SingleModule
    }

    Write-Verbose -Message 'Update modules existing modules'
    Update-Module -Force -AcceptLicense -ErrorAction SilentlyContinue

    Write-Verbose -Message 'Update Help files'
    Update-Help -Force -ErrorAction SilentlyContinue
    #endregion