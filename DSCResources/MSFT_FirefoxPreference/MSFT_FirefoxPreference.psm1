$currentPath = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module  "$currentPath\..\FirefoxPreferenceHelper.psm1" -Force

<#
    .SYNOPSIS
        Get-TargetResource returns the Firefox Install path and the current configuration
        preferences in the Mozilla.cfg file.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER PreferenceName
        The name of the Firefox preference to configure.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory,

        [Parameter(Mandatory = $true)]
        [string]
        $PreferenceName
    )

    if (-not(Test-Path -Path $InstallDirectory))
    {
        Write-Warning "$InstallDirectory not found. Verify Firefox is installed and the correct Install Directory is defined."
    }
    elseif (Test-Path -Path "$InstallDirectory\Mozilla.cfg")
    {
        $currentPreference = Get-FirefoxPreference -PreferenceName $PreferenceName -InstallDirectory $InstallDirectory
    }
    else
    {
        Write-Warning -Message "No Mozilla.cfg file found"
    }

    $return = @{
        PreferenceType   = $currentPreference.Type
        PreferenceName   = $currentPreference.PreferenceName
        PreferenceValue  = $currentPreference.Value
        InstallDirectory = $InstallDirectory
    }

    return $return
}

<#
    .SYNOPSIS
        Set-TargetResource sets Firefox config preconfigurations and preferences.

    .PARAMETER PreferenceName
        The name of the Firefox preference to configure.

    .PARAMETER PreferenceType
        The type of Firefox preference to configure.

    .PARAMETER PreferenceValue
        The Value of the Firefox preference to configure.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $PreferenceName,

        [Parameter(Mandatory = $true)]
        [string]
        $PreferenceType,

        [Parameter()]
        [AllowNull()]
        [string]
        $PreferenceValue,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    if (-not(Test-Path -Path $InstallDirectory))
    {
        throw -Message "$InstallDirectory not found. Verify Firefox is installed and the correct Install Directory is defined."
    }

    $preconfigs = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory
    if ($preconfigs)
    {
        Set-FirefoxPreconfigs -Preconfigs $preconfigs -InstallDirectory $InstallDirectory
    }

    Set-FirefoxConfiguration -PreferenceName $PreferenceName -PreferenceType $PreferenceType -PreferenceValue $PreferenceValue -InstallDirectory $InstallDirectory
}

<#
    .SYNOPSIS
        Test-TargetResource tests Firefox config preconfigurations and Preferences.

    .PARAMETER PreferenceName
        The name of the Firefox preference to configure.

    .PARAMETER PreferenceType
        The type of Firefox preference to configure.

    .PARAMETER PreferenceValue
        The Value of the Firefox preference to configure.

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
        [string]
        $PreferenceName,

        [Parameter(Mandatory = $true)]
        [string]
        $PreferenceType,

        [Parameter()]
        [AllowNull()]
        [string]
        $PreferenceValue,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $preconfigurationTest = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory

    if ($null -ne $preconfigurationTest)
    {
        Write-Verbose -Message "Firefox preferences are not set to use Mozilla.cfg"
        return $false
    }

    $inDesiredState = Test-FirefoxPreference -PreferenceName $PreferenceName -PreferenceType $PreferenceType -PreferenceValue $PreferenceValue -InstallDirectory $InstallDirectory

    return $inDesiredState
}

Export-ModuleMember -Function *-TargetResource
