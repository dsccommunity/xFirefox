#Updates Firefox preference configurations.

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
