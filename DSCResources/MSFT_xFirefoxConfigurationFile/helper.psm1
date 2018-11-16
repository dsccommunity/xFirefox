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
        Value      = 'firefox.cfg'
    }

    $obscureValueConfig = @{
        PrefType   = 'prefLock'
        Preference = 'general.config.obscure_value'
        Value      = '0'
    }

    $currentConfiguration = Get-Content -Path "$InstallDirectory\defaults\pref\autoconfig.js"
    if(-not(Test-FirefoxPreference -Configuration $fileNameConfig -CurrentConfiguration $currentConfiguration))
    {
        Write-Warning -Message 'Firefox "GeneralConfigurationFile" preference not set to firefox.cfg'
        $return += 'filename'
    }
    if (-not(Test-FirefoxPreference -Configuration $obscureValueConfig -CurrentConfiguration $currentConfiguration))
    {
        Write-Warning -Message 'Firefox "DoNotObscure" preference is incorrect'
        $return += 'obscurevalue'
    }
    if (-not(Test-ConfigStartWithComment -InstallDirectory $InstallDirectory))
    {
        Write-Warning -Message 'firefox.cfg does not begin with a commented line and will ignore any preference in the first line'
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
        Tests if firefox.cfg starts with a comment line.

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

    $configContent = Get-Content -Path "$InstallDirectory\firefox.cfg"

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
    $firefoxCfgPath = "$InstallDirectory\firefox.cfg"
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
                    Value          = 'firefox.cfg'
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

    .PARAMETER ConfigContent
        Content of the configuration file to check.

    .PARAMETER Preference
        Name of the preference to get.
#>
function Get-FirefoxPreference
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [System.Object[]]
        $CurrentConfiguration,

        [Parameter()]
        [string]
        $Preference
    )

    $configuration = @()
    foreach ($line in $CurrentConfiguration)
    {
        if ($null -ne $line)
        {
            if ($Preference)
            {
                $match = Select-String -InputObject $line -Pattern "\w*Pref\(`"$Preference.*(?=\))"
            }
            else
            {
                $match = Select-String -InputObject $line -Pattern "\w*Pref.*(?=\))"
            }

            if ($null -ne $match)
            {
                $configuration += $match.Matches.Value
            }
        }
    }

    $return = Split-FirefoxPreference -Configuration $configuration

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
        [System.Object[]]
        $Configuration
    )

    $return = @()
    foreach ($config in $Configuration)
    {
        $prefSplit = $config.split('(')
        $prefType = $prefSplit[0]
        $keyValue = ($prefSplit[1]).split(',')
        $count = $keyValue.count

        if ($count -gt 2)
        {
            $key = $keyValue[1].replace('"', '')
            $Value = ($keyValue[2..$count] -join ',').replace('"', '')
        }
        else
        {
            $key = $keyValue[0].replace('"', '')
            $Value = $keyValue[1].replace('"', '')
        }

        $collection = @{
            PrefType       = $prefType.trim()
            PreferenceName = $key.trim()
            Value          = $value.trim()
        }

        $return += $collection
    }

    return $return
}

function Test-FirefoxPreference
{
    [CmdletBinding()]
    [OutputType([boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]
        $Configuration,

        [Parameter(Mandatory = $true)]
        [psobject]
        $CurrentConfiguration,

        [Parameter()]
        [switch]
        $Force = $false
    )

    foreach ($config in $Configuration)
    {
        $currentPreference = Get-FirefoxPreference -CurrentConfiguration $CurrentConfiguration -Preference $config.PreferenceName
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
    }

    return $inDesiredState
}

#endregion
#region Write Firefox Files
function Set-FirefoxConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [hashtable[]]
        $Configuration,

        [Parameter()]
        [string]
        [ValidateSet('autoconfig', 'firefox')]
        $File = 'firefox',

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory,

        [Parameter()]
        [switch]
        $Force = $false
    )

    switch ($File)
        {
            'firefox'
            {
                $filePath = "$InstallDirectory\firefox.cfg"
            }
            'autoconfig'
            {
                $filePath = "$InstallDirectory\defaults\pref\autoconfig.js"
            }
        }

    $preferences = $null
    if ($Force)
    {
        foreach ($preference in $Configuration)
        {
            $pref = $preference.PrefType
            $preferenceName = $preference.PreferenceName
            $value = Format-FireFoxPreference -Value ($preference.Value)

            $preferences += ('{0}("{1}", {2});' -f $pref, $preferenceName, $value) + "`n"
        }
    }
    else
    {
        $configurationContent = Get-Content -Path $filePath -ErrorAction SilentlyContinue
        $newConfiguration = Merge-FirefoxPreference -Configuration $Configuration -ConfigurationContent $configurationContent

        foreach ($preference in $newConfiguration)
        {
            $pref = $preference.PrefType
            $preferenceName = $preference.PreferenceName
            $value = Format-FireFoxPreference -Value ($preference.Value)

            $preferences += ('{0}("{1}", {2});' -f $pref, $preferenceName, $value) + "`n"
        }
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
        The FireFox.cfg file wants double quotes around words but not around bools
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

function Merge-FirefoxPreference
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
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
