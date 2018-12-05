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

    $fileNameParam = @{
        PreferenceType   = 'lockPref'
        PreferenceName   = 'general.config.filename'
        PreferenceValue  = 'Mozilla.cfg'
        InstallDirectory = $InstallDirectory
        File             = 'Autoconfig'
    }

    $obscureValueParam = @{
        PreferenceType   = 'lockPref'
        PreferenceName   = 'general.config.obscure_value'
        PreferenceValue  = '0'
        InstallDirectory = $InstallDirectory
        File            = 'Autoconfig'
    }

    $return = @()
    if(-not(Test-FirefoxPreference @fileNameParam))
    {
        Write-Verbose -Message 'Firefox "GeneralConfigurationFile" preference not set to Mozilla.cfg'
        $return += 'filename'
    }
    if (-not(Test-FirefoxPreference @obscureValueParam))
    {
        Write-Verbose -Message 'Firefox "DoNotObscure" preference is incorrect'
        $return += 'obscurevalue'
    }
    if (-not(Test-ConfigStartWithComment -InstallDirectory $InstallDirectory))
    {
        Write-Verbose -Message 'Mozilla.cfg does not begin with a commented line and will ignore any preference in the first line'
        $return += 'comment'
    }
    if ($null -eq $return)
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

    $configContent = Get-Content -Path "$InstallDirectory\Mozilla.cfg" -ErrorAction SilentlyContinue

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

    if (-not(Test-Path -Path "$InstallDirectory\defaults\pref\autoconfig.js"))
    {
        New-Item -Path $autoConfigPath -Type File
    }

    switch ($Preconfigs)
    {
        'filename'
        {
            Set-FirefoxPreference -PreferenceType 'lockPref' -PreferenceName 'general.config.filename' -PreferenceValue 'Mozilla.cfg' -InstallDirectory $InstallDirectory -File 'Autoconfig'
        }
        'obscurevalue'
        {
            Set-FirefoxPreference -PreferenceType 'lockPref' -PreferenceName 'general.config.obscure_value' -PreferenceValue '0' -InstallDirectory $InstallDirectory -File 'Autoconfig'
        }
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

    .PARAMETER File
        The file name to update
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
        $PreferenceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Mozilla', 'Autoconfig')]
        [string]
        $File
    )

    switch ($File)
    {
        'Mozilla'
        {
            $currentConfiguration = Get-Content "$InstallDirectory\Mozilla.cfg" -ErrorAction SilentlyContinue
            break
        }
        'Autoconfig'
        {
            $currentConfiguration = Get-Content "$InstallDirectory\defaults\pref\autoconfig.js" -ErrorAction SilentlyContinue
            break
        }
    }

    $preferences = @()
    foreach ($line in $currentConfiguration)
    {
        if ($null -ne $line)
        {
            if ($PreferenceName)
            {
                $match = Select-String -InputObject $line -Pattern "\w*Pref\(`"$PreferenceName.*(?=\))"
            }
            else
            {
                $match = Select-String -InputObject $line -Pattern '\w*Pref\(.*(?=\))'
            }
            if ($null -ne $match)
            {
                $preferences += $match.Matches.Value
            }
        }
    }

    if ($preferences.count -gt 0)
    {
        $return = @()
        foreach ($preference in $preferences)
        {
            $return += Split-FirefoxPreference -Preference $preference
        }
    }
    else
    {
        Write-Verbose -Message "$PreferenceName not found"
    }

    return $return
}

<#
    .SYNOPSIS
        Returns the preference name and value in a hashtable.

    .PARAMETER Preference
        Preference to split.
#>
function Split-FirefoxPreference
{
    [CmdletBinding()]
    [OutputType([hashtable])]
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
        $preferenceName = $nameValue[0].replace('"', '')
        $preferenceValue = ($nameValue[1..($count - 1)] -join ',').replace('"', '')
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

    .PARAMETER File
        The file name to update
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
        $InstallDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Mozilla', 'Autoconfig')]
        [string]
        $File
    )

    $currentPreference = Get-FirefoxPreference -PreferenceName $PreferenceName -InstallDirectory $InstallDirectory -File $File
    if ($null -eq $currentPreference)
    {
        Write-Verbose -Message "$PreferenceName not found"
        return $false
    }

    $inDesiredState = $true

    if ($currentPreference.PreferenceType -ne $PreferenceType)
    {
        Write-Verbose -Message "PrefType: $PrefType does not matched desired setting for $PreferenceName"
        $inDesiredState = $false
    }
    if ($currentPreference.PreferenceValue -ne $PreferenceValue)
    {
        Write-Verbose -Message "Value: $Value does not matched desired setting for $PreferenceName"
        $inDesiredState = $false
    }

    return $inDesiredState
}

#endregion
#region Write Firefox Files
<#
    .SYNOPSIS
        Writes the preferences to the appropriate file.

    .PARAMETER PreferenceName
        The name of the Firefox preference to configure.

    .PARAMETER PreferenceType
        The type of Firefox preference to configure.

    .PARAMETER PreferenceValue
        The Value of the Firefox preference to configure.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER File
        The file name to update
#>
function Set-FirefoxPreference
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

        [Parameter()]
        [ValidateSet('Autoconfig', 'Mozilla')]
        [string]
        $File = 'Mozilla',

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    switch ($File)
    {
        'Mozilla'
        {
            $filePath = "$InstallDirectory\Mozilla.cfg"
            break
        }
        'Autoconfig'
        {
            $filePath = "$InstallDirectory\defaults\pref\autoconfig.js"
            break
        }
    }

    $preferences = $null

    $newConfiguration = Merge-FirefoxPreference -PreferenceType $PreferenceType -PreferenceName $PreferenceName -PreferenceValue $PreferenceValue -InstallDirectory $InstallDirectory -File $File

    foreach ($preference in $newConfiguration)
    {
        $pref = $preference.PreferenceType
        $preferenceName = $preference.PreferenceName
        $value = Format-FireFoxPreference -Value ($preference.PreferenceValue)

        $preferences += ('{0}("{1}", {2});' -f $pref, $preferenceName, $value) + "`n"
    }

    switch ($File)
    {
        'Mozilla'
        {
            ForEach-Object -InputObject $File -Process {
                "\\Firefox preference file `n"
                "$preferences"
            } | Out-file -FilePath $filePath -Force -NoNewline
            break
        }
        'Autoconfig'
        {
            ForEach-Object -InputObject $File -Process {
                "$preferences"
            } | Out-file -FilePath $filePath -Force -NoNewline
            break
        }
    }

    Write-Verbose -Message "$PreferenceName has been set in $File file."
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

    .PARAMETER PreferenceName
        The name of the Firefox preference to configure.

    .PARAMETER PreferenceType
        The type of Firefox preference to configure.

    .PARAMETER PreferenceValue
        The Value of the Firefox preference to configure.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.

    .PARAMETER File
        The file name to update
#>

function Merge-FirefoxPreference
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
        $InstallDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Mozilla', 'Autoconfig')]
        [string]
        $File
    )
    $return = @()
    $preferences = Get-FirefoxPreference -InstallDirectory $InstallDirectory -File $File
    $return += $preferences | Where-Object -FilterScript {$_.PreferenceName -ne $PreferenceName}

    $return += @{
        PreferenceType  = $PreferenceType
        PreferenceName  = $PreferenceName
        PreferenceValue = $PreferenceValue
    }

    return $return
}
#endregion
