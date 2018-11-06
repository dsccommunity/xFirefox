Import-Module  "$PSScriptRoot\helper.psm1"

<#
    .SYNOPSIS
        Get-TargetResource returns the Firefox Install path and the current configuration
        preferences in the firefox.cfg file.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox"
    )

    if (-not(Test-Path -Path $InstallDirectory))
    {
        Write-Warning "$InstallDirectory not found. Verify Firefox is installed and the correct Install Directory is defined."
    }
    elseif (Test-Path -Path "$InstallDirectory\firefox.cfg")
    {
        $configurationContent = Get-Content -Path "$InstallDirectory\firefox.cfg"
        $currentFirefoxPreference = Get-FirefoxPreference -ConfigContent $configurationContent
    }
    else
    {
        Write-Warning -Message "No firefox.cfg file found"
    }

    $return = @{
        CurrentConfiguration  = $currentFirefoxPreference
        ConfigurationLocation = $configurationPath
    }

    return $return
}

<#
    .SYNOPSIS
        Set-TargetResource sets Firefox config preconfigurations and preferences.

    .PARAMETER Configuration
        Hashtable of desired Preferences and Values

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Configuration,

        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox"
    )

    if (Test-Path -Path $InstallDirectory)
    {
        throw -Message "$InstallDirectory not found. Verify Firefox is installed and the correct Install Directory is defined."
    }

    $preconfigs = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory
    if ($preconfigs)
    {
        Set-FirefoxPreconfigs -Preconfigs $preconfigs -InstallDirectory $InstallDirectory
    }

    if ($Force)
    {
        Set-FirefoxConfiguration -Configuration $Configuration -InstallDirectory $InstallDirectory -Force
    }
    else
    {
        Set-FirefoxConfiguration -Configuration $Configuration -InstallDirectory $InstallDirectory
    }
}

<#
    .SYNOPSIS
        Test-TargetResource tests Firefox config preconfigurations and Preferences.

    .PARAMETER Configuration
        Hashtable of desired Preferences and Values

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Configuration,

        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox"
    )

    $preconfigurationTest = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory

    if ($null -ne $preconfigurationTest)
    {
        Write-Warning -Message "Firefox preferences are not set to use firefox.cfg"
        return $false
    }

    $currentConfiguration = Get-TargetResource -InstallDirectory $InstallDirectory
    if ($Force)
    {
       $inDesiredState = Test-FirefoxPreference -Configuration $Configuration -CurrentConfiguration $currentConfiguration.CurrentConfiguration -Force
    }
    else
    {
        $inDesiredState = Test-FirefoxPreference -Configuration $Configuration -CurrentConfiguration $currentConfiguration.CurrentConfiguration
    }

    return $inDesiredState
}
