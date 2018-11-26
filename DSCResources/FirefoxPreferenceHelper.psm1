#region Preconfiguration Functions
<#
    .SYNOPSIS
        Verifies if firefox preconfigurations are complete and returns an array of preferences that aren't.

    .PARAMETER InstallDirectory
        Directory where FireFox is installed
#>
function Test-FirefoxPreconfiguration
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $return = @()
    $fileNameConfig = @{
        PrefType   = 'prefLock'
        Preference = 'general.config.filename'
        Value      = 'Mozilla.cfg'
    }

    $obscureValueConfig = @{
        PrefType   = 'prefLock'
        Preference = 'general.config.obscure_value'
        Value      = '0'
    }

    $currentConfiguration = Get-Content -Path "$InstallDirectory\defaults\pref\autoconfig.js"
    if(-not(Test-FirefoxPreference -Configuration $fileNameConfig -CurrentConfiguration $currentConfiguration))
    {
        Write-Warning -Message 'Firefox "GeneralConfigurationFile" preference not set to Mozilla.cfg'
        $return += 'filename'
    }
    if (-not(Test-FirefoxPreference -Configuration $obscureValueConfig -CurrentConfiguration $currentConfiguration))
    {
        Write-Warning -Message 'Firefox "DoNotObscure" preference is incorrect'
        $return += 'obscurevalue'
    }
    if (-not(Test-ConfigStartWithComment -InstallDirectory $InstallDirectory))
    {
        Write-Warning -Message 'Mozilla.cfg does not begin with a commented line and will ignore any preference in the first line'
        $return += 'comment'
    }
    else
    {
        Write-Verbose -Message 'Firefox preconfiguration requirements are correct'
    }

    return $return
}

<#
    .SYNOPSIS
        Tests if Mozilla.cfg starts with a comment line.

    .PARAMETER InstallDirectory
        Directory where FireFox is installed.
#>
function Test-ConfigStartWithComment
{
    [CmdletBinding()]
    [OutputType([boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $configContent = Get-Content -Path "$InstallDirectory\Mozilla.cfg"

    if (($configContent | Select-Object -First 1) -notmatch '^\\\\')
    {
        return $false
    }
    else
    {
        return $true
    }
}

<#
    .SYNOPSIS
        Configures firefox preconfiguration requirements.

    .PARAMETER Preconfigs
        Array of which preconfigurations need to be set.

    .PARAMETER InstallDirectory
        Directory where FireFox is installed.
#>
function Set-FirefoxPreconfigs
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Preconfigs,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $autoConfigPath = "$InstallDirectory\defaults\pref\autoconfig.js"
    $firefoxCfgPath = "$InstallDirectory\Mozilla.cfg"
    $config = @()

    foreach ($item in $Preconfigs)
    {
        switch ($item)
        {
            'filename'
            {
                $fileNameCollection = @{
                    PrefType       = 'lockPref'
                    PreferenceName = 'general.config.filename'
                    Value          = 'Mozilla.cfg'
                }

                $config += $fileNameCollection
            }
            'obscurevalue'
            {
                $fileNameCollection = @{
                    PrefType       = 'lockPref'
                    PreferenceName = 'general.config.obscure_value'
                    Value          = '0'
                }

                $config += $fileNameCollection
            }
            'comment'
            {
                if (-not(Test-Path -Path $firefoxCfgPath))
                {
                    New-Item -Path $firefoxCfgPath -Type File
                }

                $cfgContent = Get-Content -Path $firefoxCfgPath
                $addcomment = '// FireFox preference file' + '`r' + $cfgContent

                Out-File -FilePath $firefoxCfgPath -InputObject $addcomment
            }
        }
    }

    if ($config)
    {
        if (-not(Test-Path -Path $autoConfigPath))
        {
            New-Item -Path $autoConfigPath -Type File
        }

        Set-FirefoxConfiguration -Configuration $config -File 'autoconfig' -InstallDirectory $InstallDirectory
    }
}
#endregion
#region Firefox Preferences
<#
    .SYNOPSIS
        Returns the preference name and value of the desired preference in a Firefox configuration file.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER PreferenceName
        Name of the preference to get.
#>
function Get-FirefoxPreference
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory,

        [Parameter()]
        [string]
        $PreferenceName
    )

    $currentConfiguration = Get-Content "$InstallDirectory\Mozilla.cfg"
    foreach ($line in $currentConfiguration)
    {
        if ($null -ne $line)
        {
            {
                $match = Select-String -InputObject $line -Pattern "\w*Pref\(`"$PreferenceName.*(?=\))"
            }

            if ($null -ne $match)
            {
                $preference = $match.Matches.Value
            }
        }
    }

    $return = Split-FirefoxPreference -Preference $preference

    return $return
}

<#
    .SYNOPSIS
        Returns the preference name and value in a hashtable.

    .PARAMETER Configuration
        Array of preferences to split.
#>
function Split-FirefoxPreference
{
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Preference
    )

    $prefSplit = $Preference.split('(')
    $preferenceType = $prefSplit[0]
    $nameValue = ($prefSplit[1]).split(',')
    $count = $nameValue.count

    if ($count -gt 2)
    {
        $preferenceName = $nameValue[1].replace('"', '')
        $preferenceValue = ($nameValue[2..$count] -join ',').replace('"', '')
    }
    else
    {
        $preferenceName = $nameValue[0].replace('"', '')
        $preferenceValue = $nameValue[1].replace('"', '')
    }

    $return = @{
        PreferenceType  = $preferenceType.trim()
        PreferenceName  = $preferenceName.trim()
        PreferenceValue = $preferenceValue.trim()
    }

    return $return
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

function Test-FirefoxPreference
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

    $currentPreference = Get-FirefoxPreference -Preference $config.PreferenceName -InstallDirectory $InstallDirectory
    if ($null -eq $currentPreference)
    {
        Write-Verbose -Message "$Preference not found."
        return $false
    }

    $inDesiredState = $true

    if ($currentPreference.PrefType -ne $config.PrefType)
    {
        Write-Verbose -Message "PrefType: $PrefType does not matched desired setting for $Preference"
        $inDesiredState = $false
    }
    if ($currentPreference.Value -ne $config.Value)
    {
        Write-Verbose -Message "Value: $Value does not matched desired setting for $Preference"
        $inDesiredState = $false
    }

    return $inDesiredState
}

#endregion
#region Write Firefox Files
<#
    .SYNOPSIS
        Writes the preferences to the appropriate file.

    .PARAMETER File
        States which file to configure.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER Force
        Switch to set a strict configuration.
#>
function Set-FirefoxConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Configuration,

        [Parameter()]
        [string]
        [ValidateSet('autoconfig', 'firefox')]
        $File = 'firefox',

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    switch ($File)
    {
        'firefox'
        {
            $filePath = "$InstallDirectory\Mozilla.cfg"
        }
        'autoconfig'
        {
            $filePath = "$InstallDirectory\defaults\pref\autoconfig.js"
        }
    }

    $preferences = $null

    $configurationContent = Get-Content -Path $filePath -ErrorAction SilentlyContinue
    $newConfiguration = Merge-FirefoxPreference -Configuration $Configuration -ConfigurationContent $configurationContent

    foreach ($preference in $newConfiguration)
    {
        $pref = $preference.PrefType
        $preferenceName = $preference.PreferenceName
        $value = Format-FireFoxPreference -Value ($preference.Value)

        $preferences += ('{0}("{1}", {2});' -f $pref, $preferenceName, $value) + "`n"
    }

    switch ($File)
    {
        'firefox'
        {
            ForEach-Object -InputObject $File -Process {
                "\\Firefox preference file"
                ($preferences -split "`n")
            } | Out-file -FilePath $filePath
        }
        'autoconfig'
        {
            ForEach-Object -InputObject $File -Process {
                ($preferences -split "`n")
            } | Out-file -FilePath $filePath
        }
    }
}

<#
    .SYNOPSIS
        Formats the value of a FireFox configuration preference.
        The Mozilla.cfg file wants double quotes around words but not around bools
        or intergers.
    .PARAMETER Value
        Specifies the FireFox preference value to be formated.
#>
function Format-FireFoxPreference
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Value
    )

    switch ($Value)
    {
        {[bool]::TryParse($Value, [ref]$null) }
        {
            $result = $Value; break
        }
        { [int]::TryParse($Value, [ref]$null) }
        {
            $result = $Value; break
        }
        default
        {
            $result = '"' + $Value + '"'
        }
    }
    return $result
}

<#
    .SYNOPSIS
        Merges Firefox preferences to a sigle array of preference hashtables

    .PARAMETER Configuration
        Array of preferences.

    .PARAMETER ConfigurationContent
        Content of the configuration file to check.
#>

function Merge-FirefoxPreference
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Configuration,

        [Parameter()]
        [AllowNull()]
        [psobject]
        $ConfigurationContent
    )

    $return = @()
    $preferences = Get-FirefoxPreference -CurrentConfiguration $ConfigurationContent

    foreach ($pref in $preferences)
    {
        $duplicate = $false
        foreach ($config in $Configuration)
        {
            if ($pref.PreferenceName -eq $config.PreferenceName)
            {
                $duplicate = $true
                break
            }
        }

        if ($duplicate -ne $true)
        {
            $return += $pref
        }
    }

    $return += $Configuration

    return $return
}
#endregion

function ConvertTo-KeyValuePairArrayToHashtable
{
    param
    (
        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Array
    )

    $hashtable = @{}
    foreach($item in $array)
    {
        $hashtable += @{$item.Key = $item.Value}
    }

    return $hashtable
}
