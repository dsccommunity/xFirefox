$Script:DSCModuleName = 'xFirefox'
$Script:DSCResourceName = 'MSFT_FirefoxConfigurationFile'
#region Header
#Unit Test Template Version: 1.0.0

$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DscResource.Tests\TestHelper.psm1') -Force
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DscResources\FirefoxConfigurationFileHelper.psm1')

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion


[System.Object[]] $firefoxcfg = @(
    '// FireFox preference file'
    'lockPref("security.default_personal_cert", "Ask Every Time");'
)

$namespace = 'root/Microsoft/Windows/DesiredStateConfiguration'
$mockCurrentPref = New-CimInstance -Namespace $namespace -ClientOnly -ClassName PreferenceObject -Property @{
        PrefType       = 'lockPref'
        PreferenceName = 'security.default_personal_cert'
        Value          = 'Ask Every Time'
}

$firefoxPreference = @{
    PrefType       = 'lockPref'
    PreferenceName = 'security.default_personal_cert'
    Value          = 'Ask Every Time'
}

$firefoxPreference2 = @{
    PrefType       = 'lockPref'
    PreferenceName = 'network.protocol-handler.external.shell'
    Value          = 'false'
}

$autoconfigPreference = @{
    PrefType       = 'lockPref'
    PreferenceName = 'general.config.filename'
    Value          = 'Mozilla.cfg'
}
# Begin Tests
try
{
    InModuleScope $DscResourceName {
        Describe 'Get-DscResource' {
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"

            Mock -CommandName Get-Content -MockWith {$firefoxcfg}
            Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
            Mock -CommandName New-CimInstance -MockWith {$mockCurrentPref}

            Context 'When Firefox InstallDirectory is missing or incorrect'{
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq $mockInstallDirectory}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"'{
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration | Should -Be $null
                }
            }
            Context 'When Mozilla.cfg path is missing or incorrect' {
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq "$mockInstallDirectory\Mozilla.cfg"}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"' {
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration | Should -Be $null
                }
            }
            Context 'When Mozilla.cfg does exist' {
                Mock -CommandName Test-Path -MockWith {$true}

                It 'Should return the correct preferences in the correct format' {
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration.PrefType | Should -Be $mockCurrentPref.PrefType
                    $result.CurrentConfiguration.PreferenceName | Should -Be $mockCurrentPref.PreferenceName
                    $result.CurrentConfiguration.Value | Should -Be $mockCurrentPref.Value
                }
            }
        }

        Describe 'Set-DscResource'{
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
            Mock -CommandName Set-FirefoxPreconfigs -MockWith {}
            Mock -CommandName Set-FirefoxConfiguration -MockWith {}

            Context 'When The Install Directory Path is incorrect.'{
                Mock -CommandName Test-Path -MockWith {$false}

                It 'Should throw' {
                    {Set-TargetResource -InstallDirectory $mockInstallDirectory -PreferenceObject $firefoxPreference} | Should -Throw
                }
            }
            Context 'When Firefox preconfigurations are not complete'{
                Mock -CommandName Test-Path -MockWith {$true}
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {'autoconfigfile'}

                Set-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory
                It 'Should call Set-FirefoxPreconfigs' {
                    Assert-MockCalled -CommandName 'Set-FirefoxPreconfigs' -Times 1
                }
                It 'Should call Set-FirefoxConfiguration' {
                    Assert-MockCalled -CommandName 'Set-FirefoxConfiguration' -Times 1
                }
            }
            Context 'When Firefox preconfigurations are complete'{
                Mock -CommandName Test-Path -MockWith {$true}
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {}

                Set-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory
                It 'Should not call Set-FirefoxPreconfigs' {
                    Assert-MockCalled -CommandName 'Set-FirefoxPreconfigs' -Times 0
                }
                It 'Should call Set-FirefoxConfiguration' {
                    Assert-MockCalled -CommandName 'Set-FirefoxConfiguration' -Times 1
                }
            }
        }

        Describe 'Test-DscResource'{
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
            $mockGetReturn = @{
                CurrentConfiguration = $mockCurrentPref
                InstallDirectory     = $mockInstallDirectory
            }
            Mock -CommandName Get-TargetResource -MockWith {$mockGetReturn}
            Context 'When Firefox Preconfigurations are not complete'{
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {'AutoConfigFile'}

                It 'Should return False'{
                    $result = Test-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory
                    $result | Should -Be $false
                }
            }
            Context 'When Firefox preferences are incorrect' {
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {}
                Mock -CommandName Test-FirefoxPreference -MockWith {$false}

                It 'Should return False when "Force" is set to False' {
                    $result = Test-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory
                    $result | Should -Be $false
                }
                It 'Should return False when "Force" is set to True' {
                    $result = Test-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory -Force
                    $result | Should -Be $false
                }
            }
            Context 'When Firefox preferences are correct' {
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {}
                Mock -CommandName Test-FirefoxPreference -MockWith {$true}

                It 'Should return True when "Force" is set to False' {
                    $result = Test-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory
                    $result | Should -Be $true
                }
                It 'Should return True when "Force" is set to True' {
                    $result = Test-TargetResource -PreferenceObject $firefoxPreference -InstallDirectory $mockInstallDirectory -Force
                    $result | Should -Be $true
                }
            }
        }

        #region helper function
        InModuleScope FirefoxConfigurationFileHelper {
            Describe 'Test-FirefoxPreconfiguration' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                Mock -CommandName Get-Content -MockWith {$firefoxPreference}
                Context 'When all preconfigs are incorrect' {
                    Mock -CommandName Test-FirefoxPreference -MockWith {$false}
                    Mock -CommandName Test-ConfigStartWithComment -MockWith {$false}

                    $result = Test-FirefoxPreconfiguration -InstallDirectory $mockInstallDirectory
                    It 'Should return all preconfig requirements' {
                        $result.Count | Should -Be 3
                        $result | Should -Contain 'filename'
                        $result | Should -Contain 'obscurevalue'
                        $result | Should -Contain 'comment'
                    }
                }
                Context 'When autoconfig and obscurevalue is incorrect but comment is correct'{
                    Mock -CommandName Test-FirefoxPreference -MockWith {$false}
                    Mock -CommandName Test-ConfigStartWithComment -MockWith {$true}

                    $result = Test-FirefoxPreconfiguration -InstallDirectory $mockInstallDirectory
                    It 'Should return obscurevalue preconfig requirements' {
                        $result.Count | Should -Be 2
                        $result | Should -Contain 'filename'
                        $result | Should -Contain 'obscurevalue'
                    }
                }
                Context 'When comment is incorrect but other preconfigurations are correct' {
                    Mock -CommandName Test-FirefoxPreference -MockWith {$true}
                    Mock -CommandName Test-ConfigStartWithComment -MockWith {$false}

                    $result = Test-FirefoxPreconfiguration -InstallDirectory $mockInstallDirectory
                    It 'Should return comment preconfig requirements' {
                        $result.Count | Should -Be 1
                        $result | Should -Be 'comment'
                    }
                }
            }
            Describe 'Test-ConfigStartWithComment' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                $mockPassingContent = '\\Test'
                $mockFailingContent = 'Test'
                Context 'When Mozilla.cfg starts with a comment' {
                    Mock -CommandName Get-Content -MockWith {$mockPassingContent}
                    It 'Should return true' {
                        $result = Test-ConfigStartWithComment -InstallDirectory $mockInstallDirectory
                        $result | Should -Be $true
                    }
                }
                Context 'When Mozilla.cfg starts without a comment' {
                    Mock -CommandName Get-Content -MockWith {$mockFailingContent}
                    It 'Should return false' {
                        $result = Test-ConfigStartWithComment -InstallDirectory $mockInstallDirectory
                        $result | Should -Be $false
                    }
                }
            }
            Describe 'Set-FirefoxPreconfigs' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                $autoConfigPath = "$mockInstallDirectory\defaults\pref\autoconfig.js"
                $firefoxCfgPath = "$mockInstallDirectory\Mozilla.cfg"

                Mock -CommandName New-Item -MockWith {}
                Mock -CommandName Get-Content -MockWith {}
                Mock -CommandName Out-File -MockWith {}
                Mock -CommandName Set-FirefoxConfiguration -MockWith {}

                Context 'When filename is incorrectly configured and file exists'{
                    Mock -CommandName Test-Path -MockWith {$true}

                    It 'Should not throw'{
                        {Set-FirefoxPreconfigs -Preconfigs 'filename' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                    }
                    It 'Should run only required commands' {
                        Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath}
                        Assert-MockCalled -CommandName New-Item -Times 0
                        Assert-MockCalled -CommandName Get-Content -Times 0
                        Assert-MockCalled -CommandName Out-File -Times 0
                        Assert-MockCalled -CommandName Set-FirefoxConfiguration -Times 1
                    }
                }
                Context 'When filename is incorrectly configured and file does not exist'{
                    Mock -CommandName Test-Path -MockWith {$false}

                    It 'Should not throw'{
                        {Set-FirefoxPreconfigs -Preconfigs 'filename' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                    }
                    It 'Should run only required commands' {
                        Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath}
                        Assert-MockCalled -CommandName New-Item -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath}
                        Assert-MockCalled -CommandName Get-Content -Times 0
                        Assert-MockCalled -CommandName Out-File -Times 0
                        Assert-MockCalled -CommandName Set-FirefoxConfiguration -Times 1
                    }
                }
                Context 'When obscurevalue is incorrectly configured and file exists'{
                    Mock -CommandName Test-Path -MockWith {$true}

                    It 'Should not throw'{
                        {Set-FirefoxPreconfigs -Preconfigs 'obscurevalue' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                    }
                    It 'Should run only required commands' {
                        Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath}
                        Assert-MockCalled -CommandName New-Item -Times 0
                        Assert-MockCalled -CommandName Get-Content -Times 0
                        Assert-MockCalled -CommandName Out-File -Times 0
                        Assert-MockCalled -CommandName Set-FirefoxConfiguration -Times 1
                    }
                }
                Context 'When obscurevalue is incorrectly configured and file does not exist'{
                    Mock -CommandName Test-Path -MockWith {$false}

                    It 'Should Not throw'{
                        {Set-FirefoxPreconfigs -Preconfigs 'obscurevalue' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                    }
                    It 'Should run only required commands' {
                        Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath}
                        Assert-MockCalled -CommandName New-Item -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath}
                        Assert-MockCalled -CommandName Get-Content -Times 0
                        Assert-MockCalled -CommandName Out-File -Times 0
                        Assert-MockCalled -CommandName Set-FirefoxConfiguration -Times 1
                    }
                }
                Context 'When Mozilla.cfg does not start with a comment and file exists'{
                    Mock -CommandName Test-Path -MockWith {$true}

                    It 'Should Not throw'{
                        {Set-FirefoxPreconfigs -Preconfigs 'comment' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                    }
                    It 'Should run only required commands' {
                        Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $firefoxCfgPath}
                        Assert-MockCalled -CommandName New-Item -Times 0
                        Assert-MockCalled -CommandName Get-Content -Times 1
                        Assert-MockCalled -CommandName Out-File -Times 1
                        Assert-MockCalled -CommandName Set-FirefoxConfiguration -Times 0
                    }
                }
                Context 'When Mozilla.cfg does not start with a comment and file does not exist'{
                    Mock -CommandName Test-Path -MockWith {$false}

                    It 'Should Not throw'{
                        {Set-FirefoxPreconfigs -Preconfigs 'comment' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                    }
                    It 'Should run only required commands' {
                        Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $firefoxCfgPath}
                        Assert-MockCalled -CommandName New-Item -Times 1 -ExclusiveFilter {$Path -eq $firefoxCfgPath}
                        Assert-MockCalled -CommandName Get-Content -Times 1
                        Assert-MockCalled -CommandName Out-File -Times 1
                        Assert-MockCalled -CommandName Set-FirefoxConfiguration -Times 0
                    }
                }
            }
            Describe 'Get-FirefoxPreference' {
                Mock -CommandName Split-FirefoxPreference -MockWith {$firefoxPreference}

                Context 'When no "Preference" is defined' {
                    It 'Should return the correct object'{
                        $result = Get-FirefoxPreference -CurrentConfiguration $firefoxcfg
                        $result.PrefType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.Value | Should -Be 'Ask Every Time'
                    }
                }
                Context 'When "Preference" is defined' {
                    It 'Should return the correct object'{
                        $result = Get-FirefoxPreference -CurrentConfiguration $firefoxcfg -Preference 'security.default_personal_cert'
                        $result.PrefType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.Value | Should -Be 'Ask Every Time'
                    }
                }
            }
            Describe 'Split-FirefoxPreference' {
                $result = Split-FirefoxPreference -Configuration 'lockPref("security.default_personal_cert", "Ask Every Time"'

                It 'Should return a correctly split object'{
                    $result.PrefType | Should -Be 'lockPref'
                    $result.PreferenceName | Should -Be 'security.default_personal_cert'
                    $result.Value | Should -Be 'Ask Every Time'
                }
            }
            Describe 'Test-FirefoxPreference' {
                $mockPrefTypeDifference = @{
                    PrefType       = 'Pref'
                    PreferenceName = 'security.default_personal_cert'
                    Value          = 'Ask Every Time'
                }

                $mockValueDifference = @{
                    PrefType       = 'Pref'
                    PreferenceName = 'security.default_personal_cert'
                    Value          = 'Do not ask'
                }

                Context 'When Firefox preference does not exist.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$null}
                    It 'Should return False' {
                        $result = Test-FirefoxPreference -Configuration $firefoxPreference -CurrentConfiguration $mockCurrentPref
                        $result | Should -Be $false
                    }
                }
                Context 'When Firefox exists and preference matches.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    It 'Should return True' {
                        $result = Test-FirefoxPreference -Configuration $firefoxPreference -CurrentConfiguration $mockCurrentPref
                        $result | Should -Be $true
                    }
                }
                Context 'When Firefox exists and PreferenceType does not match.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    It 'Should return False' {
                        $result = Test-FirefoxPreference -Configuration $mockPrefTypeDifference -CurrentConfiguration $mockCurrentPref
                        $result | Should -Be $false
                    }
                }
                Context 'When Firefox exists and Value does not match.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    It 'Should return False' {
                        $result = Test-FirefoxPreference -Configuration $mockValueDifference -CurrentConfiguration $mockCurrentPref
                        $result | Should -Be $false
                    }
                }
            }
            Describe 'Set-FirefoxConfiguration' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                $firefoxPath = "$mockInstallDirectory\Mozilla.cfg"
                $autoconfigPath = "$mockInstallDirectory\defaults\pref\autoconfig.js"
                $mergedConfiguration = @(
                    $firefoxPreference
                    $firefoxPreference2
                )

                New-Item -Path $mockInstallDirectory -ItemType Directory -Force
                New-Item -Path "$mockInstallDirectory\defaults" -ItemType Directory -Force
                New-Item -Path "$mockInstallDirectory\defaults\pref" -ItemType Directory -Force

                Context 'When configuring Mozilla.cfg and force is true with no prior configuration' {
                    Mock -CommandName Format-FireFoxPreference -MockWith {'"Ask Every Time"'}

                    Set-FirefoxConfiguration -Configuration $firefoxPreference -InstallDirectory $mockInstallDirectory -Force
                    $content = Get-Content -Path $firefoxPath

                    It 'Should start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -match '^\\\\'} | Should -Be $true
                    }
                    It 'Should only contain 3 lines' {
                        $content.Count | Should -Be 3
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("security.default_personal_cert", "Ask Every Time");'
                    }
                }
                Context 'When configuring Mozilla.cfg and force is true with prior configuration' {
                    Mock -CommandName Format-FireFoxPreference -MockWith {'false'}
                    Out-File -FilePath $firefoxPath -InputObject $firefoxCfg

                    Set-FirefoxConfiguration -Configuration $firefoxPreference2 -InstallDirectory $mockInstallDirectory -Force
                    $content = Get-Content -Path $firefoxPath

                    It 'Should start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -match '^\\\\'} | Should -Be $true
                    }
                    It 'Should only contain 3 lines' {
                        $content.Count | Should -Be 3
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("network.protocol-handler.external.shell", false);'
                    }
                }
                Context 'When configuring Mozilla.cfg and force is false with prior configuration' {
                    Mock -CommandName Format-FireFoxPreference -ParameterFilter {$Value -eq 'Ask Every Time'} -MockWith {'"Ask Every Time"'}
                    Mock -CommandName Format-FireFoxPreference -ParameterFilter {$Value -eq 'false'} -MockWith {'false'}
                    Mock -CommandName Merge-FirefoxPreference -MockWith {$mergedConfiguration}
                    Out-File -FilePath $firefoxPath -InputObject $firefoxCfg

                    Set-FirefoxConfiguration -Configuration $firefoxPreference2 -InstallDirectory $mockInstallDirectory
                    $content = Get-Content -Path $firefoxPath

                    It 'Should start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -match '^\\\\'} | Should -Be $true
                    }
                    It 'Should only contain 4 lines' {
                        $content.Count | Should -Be 4
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("network.protocol-handler.external.shell", false);'
                        $content | Should -Contain 'lockPref("security.default_personal_cert", "Ask Every Time");'
                    }
                }
                Context 'When configuring autoconfig.js' {
                    Mock -CommandName Format-FireFoxPreference -MockWith {'"Mozilla.cfg"'}
                    Mock -CommandName Merge-FirefoxPreference -MockWith {$autoconfigpreference}

                    Set-FirefoxConfiguration -Configuration $autoconfigpreference -InstallDirectory $mockInstallDirectory -File 'autoconfig'
                    $content = Get-Content -Path $autoconfigPath

                    It 'Should not start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -notmatch '^\\\\'} | Should -Be $true
                    }
                    It 'Should only contain 2 lines' {
                        $content.Count | Should -Be 2
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("general.config.filename", "Mozilla.cfg");'
                    }
                }
            }
            Describe 'Format-FireFoxPreference' {
                Context 'When a string boolean is input' {
                    $result = Format-FireFoxPreference -Value 'True'
                    It 'Should return True'{
                        $result | Should -Be 'True'
                    }
                }
                Context 'When an integer is input' {
                    $result = Format-FireFoxPreference -Value '42'
                    It 'Should return $true'{
                        $result | Should -Be '42'
                    }
                }
                Context 'When a string is input' {
                    $result = Format-FireFoxPreference -Value 'Meaning of Life'
                    It 'Should return string input wrapped in double quotes'{
                        $result | Should -Be '"Meaning of Life"'
                    }
                }
            }
            Describe 'Merge-FirefoxPreference' {
                Context 'When there is no current configuration' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$null}
                    It 'Should not throw' {
                        {Merge-FirefoxPreference -Configuration $firefoxPreference} | Should -Not -Throw
                    }
                    It 'Should return the supplied configuration' {
                        $result = Merge-FirefoxPreference -Configuration $firefoxPreference
                        $result.PrefType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.Value | Should -Be 'Ask Every Time'
                    }
                }
                Context 'When current configuration exists and matches supplied configuration' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    $result = Merge-FirefoxPreference -Configuration $firefoxPreference
                    It 'Should not throw' {
                        {Merge-FirefoxPreference -Configuration $firefoxPreference} | Should -Not -Throw
                    }
                    It 'Should return the supplied configuration' {
                        $result.PrefType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.Value | Should -Be 'Ask Every Time'
                    }
                    It 'Should not have duplicates' {
                        $result.PrefType.Count | Should -Be 1
                        $result.PreferenceName.Count | Should -Be 1
                        $result.Value.Count | Should -Be 1
                    }
                }
                Context 'When current configuration exists and does not match supplied configuration' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    $result = Merge-FirefoxPreference -Configuration $firefoxPreference2
                    It 'Should not throw' {
                        {Merge-FirefoxPreference -Configuration $firefoxPreference2} | Should -Not -Throw
                    }
                    It 'Should have multiple values' {
                        $result.PrefType.Count | Should -Be 2
                        $result.PreferenceName.Count | Should -Be 2
                        $result.Value.Count | Should -Be 2
                    }
                    It 'Should have correct configuration' {
                        $result.PrefType | Should -Contain 'lockPref'
                        $result.PreferenceName | Should -Contain 'security.default_personal_cert'
                        $result.Value | Should -Contain 'Ask Every Time'
                        $result.PreferenceName | Should -Contain 'network.protocol-handler.external.shell'
                        $result.Value | Should -Contain 'false'
                    }
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}
