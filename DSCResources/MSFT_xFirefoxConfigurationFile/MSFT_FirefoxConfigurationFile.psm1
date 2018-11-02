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
        throw "$InstallDirectory not found. Verify Firefox is installed and the correct Install Directory is defined."
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

    $preconfigs = Test-FirefoxPreconfiguration -InstallDirectory $InstallDirectory
    foreach ($item in $preconfigs)
    {
        switch ($item)
        {
            'filename'
            {

            }
            'obscurevalue'
            {

            }
            'comment'
            {

            }
        }
    }

    $configContent = Get-Content -Path "$InstallDirectory\firefox.cfg"

    foreach ($setting in $Configuration.Keys)
    {
        $firefoxSetting = Get-FirefoxSetting -ConfigContent $configContent -Setting $setting
        if (-not(Test-FirefoxSetting))
        {
            #set correct value if incorrect
        }
    }
}

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

        return $inDesiredState
    }
}

function Get-FirefoxSetting
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
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

function Split-FirefoxSetting
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Configuration
    )

    $return = @{}
    foreach ($config in $configurations)
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

function Test-ConfigStartWithComment
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectory
    )

    $configContent = Get-Content -Path "$InstallDirectory\firefox.cfg"

    if ($configContent -notmatch '^\\\\')
    {
        return $false
    }
    else
    {
        return $true
    }
}
