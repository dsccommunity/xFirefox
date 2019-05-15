<#
    .SYNOPSIS
        This sample configuration allows you to update a single Firefox preference

    .PARAMETER PreferenceName
        The name of the Firefox preference to configure.

    .PARAMETER PreferenceType
        The type of Firefox preference to configure.

    .PARAMETER PreferenceValue
        The Value of the Firefox preference to configure.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

#>
Configuration Sample_SetFirefoxPreference
{
    param
    (

        [Parameter(Mandatory = $true)]
        [string]
        $PreferenceType,

        [Parameter(Mandatory = $true)]
        [string]
        $PreferenceName,

        [Parameter()]
        [string]
        $PreferenceValue,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    Import-DscResource -ModuleName xFirefox

    xFirefoxPreference firefox
    {
        PreferenceType   = $PreferenceType
        PreferenceName   = $PreferenceName
        PreferenceValue  = $PreferenceValue
        InstallDirectory = $InstallDirectory
    }
}
