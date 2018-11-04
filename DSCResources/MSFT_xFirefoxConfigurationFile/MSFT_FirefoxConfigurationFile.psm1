<#
    .SYNOPSIS
        Get-TargetResource returns the Firefox Install path and the current configuration
        settings in the firefox.cfg file.

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Get-TargetResource
{
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
        $currentFirefoxSetting = Get-FirefoxSetting -ConfigContent $configurationContent
    }
    else
    {
        Write-Warning -Message "No firefox.cfg file found"
    }

    $return = @{
        Settings              = $currentFirefoxSetting
        ConfigurationLocation = $configurationPath
    }

    return $return
}

<#
    .SYNOPSIS
        Set-TargetResource sets Firefox config preconfigurations and settings.

    .PARAMETER Configuration
        Hashtable of desired Settings and Values

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Configuration,

        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox"
    )

    throw -Message "$InstallDirectory not found. Verify Firefox is installed and the correct Install Directory is defined."
    $preconfigs = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory

    if ($preconfigs)
    {
        Set-FirefoxPreconfigs -Setting $preconfigs
    }

    $configContent = Get-Content -Path "$InstallDirectory\firefox.cfg"

    foreach ($setting in $Configuration.Keys)
    {
        $firefoxSetting = Get-FirefoxSetting -ConfigContent $configContent -Setting $setting
        if (-not(Test-FirefoxSetting))
        {
            #set correct value if incorrect. Incorrect could mean doesn't exist or incorrect setting value which require separeate action.
        }
    }
}

<#
    .SYNOPSIS
        Test-TargetResource tests Firefox config preconfigurations and settings.

    .PARAMETER Configuration
        Hashtable of desired Settings and Values

    .PARAMETER InstallDirectory
        The directory where Firefox is installed.
#>
function Test-TargetResource
{
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Configuration,

        [Parameter()]
        [string]
        $Ensure = 'Present',

        [Parameter()]
        [string]
        $InstallDirectory = "$env:ProgramFiles\Mozilla Firefox"
    )

    $preconfigurationTest = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory

    if ($null -ne $preconfigurationTest)
    {
        Write-Warning -Message "Firefox settings are not set to use firefox.cfg"
        return $false
    }

    $inDesiredState = $true

    $currentConfiguration = Get-TargetResource -InstallDirectory $InstallDirectory

    foreach ($key in $Configuration.Keys)
    {
        if ($currentConfiguration.Settings.$key)
        {
            if($currentConfiguration.Settings.$key -eq $Configuration.$key)
            {
                Write-Verbose "$key is correctly configured in firefox.cfg"
            }
            else
            {
                Write-Warning -Message "$key in firefox.cfg does not have the correct value."
                $inDesiredState = $false
            }
        }
        else
        {
            Write-Warning -Message "Could not find $key in firefox.cfg."
            $inDesiredState = $false
        }
    }

    return $inDesiredState
}

<#
    .SYNOPSIS
        Returns the setting name and value of the desired setting in a Firefox configuration file.

    .PARAMETER ConfigContent
        Content of the configuration file to check.

    .PARAMETER Setting
        Name of the setting to get.
#>
function Get-FirefoxSetting
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $ConfigContent,

        [Parameter()]
        [string]
        $Setting
    )

    $configuration = @()
    foreach ($line in $configContent)
    {
        if ($null -ne $line)
        {
            if ($Setting)
            {
                $match = Select-String -InputObject $line -Pattern "(?<=\(`")$Setting.*(?=\))"
            }
            else
            {
                $match = Select-String -InputObject $line -Pattern "(?<=\().*(?=\))"
            }

            if ($null -ne $match)
            {
                $configuration += $match.Matches.Value
            }
        }
    }

    $return = Split-FirefoxSetting -Configuration $configuration

    return $return
}

<#
    .SYNOPSIS
        Returns the setting name and value in a hashtable.

    .PARAMETER Configuration
        Array of settings to split.
#>
function Split-FirefoxSetting
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $Configuration
    )

    $return = @{}
    foreach ($config in $Configuration)
    {
        $keyValue = $config -split ','
        $count = $keyValue.count

        if ($count -gt 2)
        {
            $key = $keyValue[0].replace('"', '')
            $Value = ($keyValue[1..$count] -join ',').replace('"', '')
        }
        else
        {
            $key = $keyValue[0].replace('"', '')
            $Value = $keyValue[1].replace('"', '')
        }

        $return.add($key, $value)
    }

    return $return
}

<#
    .SYNOPSIS
        Verifies if firefox preconfigurations are complete and returns an array of settings that aren't.

    .PARAMETER InstallDirectory
        Directory where FireFox is installed
#>
function Test-FirefoxPreconfiguration
{
    param
    (
        [Parameter(Mandatory = $true)
        [string]
        $InstallDirectory
    )

    $return = @()
    if(-not(Test-AutoConfigSetting -InstallDirectory $InstallDirectory -Setting 'filename'))
    {
        Write-Warning -Message 'Firefox "GeneralConfigurationFile" setting not set to firefox.cfg'
        $return += 'filename'
    }
    elseif ((Test-AutoConfigSetting -InstallDirectory $InstallDirectory -Setting 'obscurevalue'))
    {
        Write-Warning -Message -Message 'Firefox "DoNotObscure" setting is incorrect'
        $return += 'obscurevalue'
    }
    elseif (-not(Test-ConfigStartWithComment -InstallDirectory $InstallDirectory))
    {
        Write-Warning -Message 'firefox.cfg does not begin with a commented line and will ignore any setting in the first line'
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
        Tests if Firefox autoconfig.js setting are set correctly.

    .PARAMETER InstallDirectory
        Directory where FireFox is installed.

    .PARAMETER Setting
        Name of the setting to Test.
#>
function Test-AutoConfigSetting
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateSet('filename', 'obscurevalue')]
        [string]
        $Setting
    )

    $autoConfigContent = Get-Content "$InstallDirectory\defaults\pref\autoconfig.js"

    $currentSetting = Get-FirefoxSetting -ConfigContent $autoConfigContent -Setting "general.config.$Setting"

    switch ($Setting)
    {
        'filename'
        {
            if ($currentSetting.'general.config.filename' -eq 'firefox.cfg')
            {
                $return = $true
            }
            else
            {
                $return = $false
            }
        }
        'obscurevalue'
        {
            if ($currentSetting.'general.config.obscure_value' -eq 0)
            {
                $return = $true
            }
            else
            {
                $return = $false
            }
        }
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

    .PARAMETER Setting
        Array of which preconfigurations need to be set.

    .PARAMETER InstallDirectory
        Directory where FireFox is installed.
#>
function Set-FirefoxPreconfigs
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Setting,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $autoConfigPath = "$InstallDirectory\defaults\pref\autoconfig.js"
    $firefoxCfgPath = "$InstallDirectory\firefox.cfg"
    foreach ($item in $preconfigs)
    {
        switch ($item)
        {
            'filename'
            {
                if (-not(Test-Path -Path $autoConfigPath))
                {
                    New-Item -Path $autoConfigPath -Type File
                }

                Set-FirefoxSetting -Setting 'pref("general.config.filename", "firefox.cfg");'
            }
            'obscurevalue'
            {
                Set-FirefoxSetting -Setting 'pref("general.config.obscure_value", 0);'
            }
            'comment'
            {
                if (-not(Test-Path -Path $autoConfigPath))
                {
                    New-Item -Path $firefoxCfgPath -Type File
                }

                $cfgContent = Get-Content -Path $firefoxCfgPath
                if(($cfgContent | Select-Object -First 1) -notmatch '^\\\\')
                {
                    $addcomment = '// FireFox preference file' + '`r' + $cfgContent

                    Out-File -FilePath $firefoxCfgPath -InputObject $addcomment
                }
            }
        }
    }
}

function Write-FirefoxConfiguration
{
    param
    (
        [Parameter()]
        [hashtable]
        $Setting,

        [Parameter()]
        [switch]
        $Clobber,

        [Parameter()]
        [string]
        [ValidateSet('autoconfig', 'firefox')]
        $File,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $settings = $null
    if ($Clobber)
    {
        foreach ($key in $Setting.Keys)
        {
            $value = Format-FireFoxPreference -Value ($Setting.$key)

            $settings += ('lockPref("{0}", {1});' -f $key, $value) + "`n"
        }
    }
    else
    {
        $preferences = Merge-FirefoxPreference -Setting $Setting -InstallDirectory $InstallDirectory -File $File

        switch ($File)
        {
            'firefox'
            {
                foreach ($key in $preferences.Keys)
                {
                    $settings += ('lockPref("{0}", {1});' -f $key, $value) + "`n"
                }

                ForEach-Object -InputObject $File -Process {
                    "\\Firefox preference file"
                    ($settings -split "`n")
                } | Out-file -FilePath "$InstallDirectory\firefox.cfg"
            }
            'autoconfig'
            {
                foreach ($key in $preferences.Keys)
                {
                    $settings += ('pref("{0}", {1});' -f $key, $value) + "`n"
                }

                ForEach-Object -InputObject $File -Process {
                    ($settings -split "`n")
                } | Out-file -FilePath "$InstallDirectory\defaults\pref\autoconfig.js"
            }
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
    param
    (
        [Parameter()]
        [string]
        $Value
    )

    switch ($value)
    {
        {[bool]::TryParse($value, [ref]$null) }
        {
            $result = $value; break
        }
        { [int]::TryParse($value, [ref]$null) }
        {
            $result = $value; break
        }
        default
        {
            $result = '"' + $value + '"'
        }
    }
    return $result
}

function Merge-FirefoxPreference
{
    param
    (
        [Parameter()]
        [hashtable]
        $Setting,

        [Parameter()]
        [string]
        [ValidateSet('autoconfig', 'firefox')]
        $File,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    switch ($File)
    {
        'firefox'
        {
            $content = Get-Content -Path "$InstallDirectory\firefox.cfg"
            $preferences = Get-FirefoxSetting -ConfigContent $content

            foreach ($key in $Setting.Keys)
            {
                if ($preferences.$key -and $preferences.$key -ne $Setting.$key)
                {
                    $preferences.$key = $Setting.$key
                }
                else
                {
                    $preferences.add($key, $Setting.$key)
                }
            }
        }
        'autoconfig'
        {
            Get-Content -Path "$InstallDirectory\defaults\pref\autoconfig.js"
            $preferences = Get-FirefoxSetting -ConfigContent $content

            foreach ($key in $Setting.Keys)
            {
                if ($preferences.$key -and $preferences.$key -ne $Setting.$key)
                {
                    $preferences.$key = $Setting.$key
                }
                else
                {
                    $preferences.add($key, $Setting.$key)
                }
            }
        }
    }

    return $preferences
}
