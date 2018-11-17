$currentPath = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module  "$currentPath\FirefoxCOnfigurationFileHelper.psm1" -Force

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
        $namespace = 'root/Microsoft/Windows/DesiredStateConfiguration'
        $cimPreferenceObjects = New-Object -TypeName 'System.Collections.ObjectModel.Collection`1[Microsoft.Management.Infrastructure.CimInstance]'

        $configurationContent = Get-Content -Path "$InstallDirectory\firefox.cfg"
        $currentPreference = Get-FirefoxPreference -CurrentConfiguration $configurationContent

        foreach ($preference in $currentPreference)
        {
            $cimPreferenceObjects += New-CimInstance -ClientOnly -Namespace $namespace -ClassName PreferenceObject -Property @{
                PrefType   = $preference.PrefType
                Preference = $preference.Preference
                Value      = $preference.Value
            }
        }
    }
    else
    {
        Write-Warning -Message "No firefox.cfg file found"
    }

    $return = @{
        CurrentConfiguration  = $cimPreferenceObjects
        InstallDirectory      = $InstallDirectory
    }

    return $return
}

<#
    .SYNOPSIS
        Set-TargetResource sets Firefox config preconfigurations and preferences.

    .PARAMETER PreferenceObject
        Hashtable of desired Preferences and Values

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER Force
        Switch to set a strict configuration.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $PreferenceObject,

        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox",

        [Parameter()]
        [switch]
        $Force = $false
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

    if ($Force)
    {
        Set-FirefoxConfiguration -Configuration $PreferenceObject -InstallDirectory $InstallDirectory -Force
    }
    else
    {
        Set-FirefoxConfiguration -Configuration $PreferenceObject -InstallDirectory $InstallDirectory
    }
}

<#
    .SYNOPSIS
        Test-TargetResource tests Firefox config preconfigurations and Preferences.

    .PARAMETER PreferenceObject
        Hashtable of desired Preferences and Values

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER Force
        Switch to set a strict configuration.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]
        $PreferenceObject,

        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox",

        [Parameter()]
        [switch]
        $Force = $false
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
       $inDesiredState = Test-FirefoxPreference -Configuration $PreferenceObject -CurrentConfiguration $currentConfiguration.CurrentConfiguration -Force
    }
    else
    {
        $inDesiredState = Test-FirefoxPreference -Configuration $PreferenceObject -CurrentConfiguration $currentConfiguration.CurrentConfiguration
    }

    return $inDesiredState
}

Export-ModuleMember -Function *-TargetResource
