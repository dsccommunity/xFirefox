$Script:DSCModuleName = 'xFirefox'
$Script:DSCResourceName = 'MSFT_xFirefoxPreference'
#region Header
#Unit Test Template Version: 1.0.0

$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DscResource.Tests\TestHelper.psm1') -Force
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DscResources\FirefoxPreferenceHelper.psm1')

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion


[System.Object[]] $firefoxcfg = @(
    '// FireFox preference file'
    'lockPref("security.default_personal_cert", "Ask Every Time");'
)

$firefoxPreference = @{
    PreferenceType   = 'lockPref'
    PreferenceName   = 'security.default_personal_cert'
    PreferenceValue  = 'Ask Every Time'
    InstallDirectory = ''
}

$firefoxPreference2 = @{
    PreferenceType  = 'lockPref'
    PreferenceName  = 'network.protocol-handler.external.shell'
    PreferenceValue = 'false'
    InstallDirectory = ''
}

$autoconfigPreference = @{
    PreferenceType  = 'lockPref'
    PreferenceName  = 'general.config.filename'
    InstallDirectory = ''
}
# Begin Tests
try
{
    InModuleScope $DscResourceName {
        Describe 'Get-DscResource' {
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"

            Mock -CommandName Get-Content -MockWith {$firefoxcfg}
            Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}

            Context 'When Firefox InstallDirectory is missing or incorrect'{
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq $mockInstallDirectory}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"'{
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory -PreferenceName $firefoxPreference.PreferenceName
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration | Should -Be $null
                }
            }
            Context 'When Mozilla.cfg path is missing or incorrect' {
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq "$mockInstallDirectory\Mozilla.cfg"}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"' {
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory -PreferenceName $firefoxPreference.PreferenceName
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration | Should -Be $null
                }
            }
            Context 'When Mozilla.cfg does exist' {
                Mock -CommandName Test-Path -MockWith {$true}

                It 'Should return the correct preferences in the correct format' {
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory -PreferenceName $firefoxPreference.PreferenceName
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.PreferenceType | Should -Be $firefoxPreference.PreferenceType
                    $result.PreferenceName | Should -Be $firefoxPreference.PreferenceName
                    $result.PreferenceValue | Should -Be $firefoxPreference.PreferenceValue
                }
            }
        }

        Describe 'Set-DscResource'{
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
            $firefoxPreference.InstallDirectory = $mockInstallDirectory
            Mock -CommandName Set-FirefoxPreconfigs -MockWith {}
            Mock -CommandName Set-FirefoxPreference -MockWith {}

            Context 'When The Install Directory Path is incorrect.'{
                Mock -CommandName Test-Path -MockWith {$false}

                It 'Should throw' {
                    {Set-TargetResource @firefoxPreference} | Should -Throw
                }
            }
            Context 'When Firefox preconfigurations are not complete'{
                Mock -CommandName Test-Path -MockWith {$true}
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {'autoconfigfile'}

                Set-TargetResource @firefoxPreference
                It 'Should call Set-FirefoxPreconfigs' {
                    Assert-MockCalled -CommandName 'Set-FirefoxPreconfigs' -Times 1
                }
                It 'Should call Set-FirefoxConfiguration' {
                    Assert-MockCalled -CommandName 'Set-FirefoxPreference' -Times 1
                }
            }
            Context 'When Firefox preconfigurations are complete'{
                Mock -CommandName Test-Path -MockWith {$true}
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {}

                Set-TargetResource @firefoxPreference
                It 'Should not call Set-FirefoxPreconfigs' {
                    Assert-MockCalled -CommandName 'Set-FirefoxPreconfigs' -Times 0
                }
                It 'Should call Set-FirefoxPreference' {
                    Assert-MockCalled -CommandName 'Set-FirefoxPreference' -Times 1
                }
            }
        }

        Describe 'Test-DscResource'{
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
            $firefoxPreference.InstallDirectory = $mockInstallDirectory
            Mock -CommandName Get-TargetResource -MockWith {$firefoxPreference}

            Context 'When Firefox Preconfigurations are not complete'{
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {'AutoConfigFile'}
                Mock -CommandName Test-FirefoxPreference -MockWith {$true}

                $result = Test-TargetResource @firefoxPreference
                It 'Should return False'{
                    $result = Test-TargetResource @firefoxPreference
                    $result | Should -Be $false
                }
                It ' Should not call "Test-FirefoxPreference"' {
                    Assert-MockCalled -CommandName Test-FirefoxPreconfiguration -Times 1
                    Assert-MockCalled -CommandName Test-FirefoxPreference -Times 0
                }
            }
            Context 'When Firefox preferences are incorrect' {
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {}
                Mock -CommandName Test-FirefoxPreference -MockWith {$false}

                It 'Should return False' {
                    $result = Test-TargetResource @firefoxPreference
                    $result | Should -Be $false
                }
            }
            Context 'When Firefox preferences are correct' {
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {}
                Mock -CommandName Test-FirefoxPreference -MockWith {$true}

                It 'Should return True' {
                    $result = Test-TargetResource @firefoxPreference
                    $result | Should -Be $true
                }
            }
        }

        #region helper function
        InModuleScope FirefoxPreferenceHelper {
            Describe 'Test-FirefoxPreconfiguration' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                Mock -CommandName Get-Content -MockWith {$firefoxcfg}
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
                Mock -CommandName Set-FirefoxPreference -MockWith {}

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
                        Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1
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
                        Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1
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
                        Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1
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
                        Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1
                    }
                }
            }
            Describe 'Get-FirefoxPreference' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                Mock -CommandName Split-FirefoxPreference -MockWith {$firefoxPreference}
                Mock -CommandName Get-Content -MockWith {$firefoxcfg}

                Context 'When no "Preference" is defined' {
                    It 'Should return the correct object'{
                        $result = Get-FirefoxPreference -InstallDirectory $mockInstallDirectory -File 'Mozilla'
                        $result.PreferenceType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.PreferenceValue | Should -Be 'Ask Every Time'
                    }
                }
                Context 'When "Preference" is defined' {
                    It 'Should return the correct object'{
                        $result = Get-FirefoxPreference -PreferenceName $firefoxPreference.PreferenceName -InstallDirectory $mockInstallDirectory -File 'Mozilla'
                        $result.PreferenceType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.PreferenceValue | Should -Be 'Ask Every Time'
                    }
                }
            }
            Describe 'Split-FirefoxPreference' {
                Context 'When there is one Preference Value'{
                    $result = Split-FirefoxPreference -Preference 'lockPref("security.default_personal_cert", "Ask Every Time"'

                    It 'Should return a correctly split object'{
                        $result.PreferenceType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.PreferenceValue | Should -Be 'Ask Every Time'
                    }
                }
                Context 'When there are multiple Preference Values'{
                    $result = Split-FirefoxPreference -Preference 'lockPref("plugin.disable_full_page_plugin_for_types", "PDF,FDF,XFDF,LSL,LSO,LSS"'

                    It 'Should return a correctly split object'{
                        $result.PreferenceType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'plugin.disable_full_page_plugin_for_types'
                        $result.PreferenceValue | Should -Be 'PDF,FDF,XFDF,LSL,LSO,LSS'
                    }
                }
            }
            Describe 'Test-FirefoxPreference' {
                $mockPreferenceTypeDifference = @{
                    PreferenceType  = 'Pref'
                    PreferenceName  = 'security.default_personal_cert'
                    PreferenceValue = 'Ask Every Time'
                }

                $mockValueDifference = @{
                    PreferenceType  = 'lockPref'
                    PreferenceName  = 'security.default_personal_cert'
                    PreferenceValue = 'Do not ask'
                }

                Context 'When Firefox preference does not exist.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$null}

                    It 'Should return False' {
                        $result = Test-FirefoxPreference @firefoxPreference -File 'Mozilla'
                        $result | Should -Be $false
                    }
                }
                Context 'When Firefox exists and preference matches.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}

                    It 'Should return True' {
                        $result = Test-FirefoxPreference @firefoxPreference -File 'Mozilla'
                        $result | Should -Be $true
                    }
                }
                Context 'When Firefox exists and PreferenceType does not match.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$mockPreferenceTypeDifference}

                    It 'Should return False' {
                        $result = Test-FirefoxPreference @firefoxPreference -File 'Mozilla'
                        $result | Should -Be $false
                    }
                }
                Context 'When Firefox exists and PreferenceValue does not match.' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$mockValueDifference}

                    It 'Should return False' {
                        $result = Test-FirefoxPreference @firefoxPreference -File 'Mozilla'
                        $result | Should -Be $false
                    }
                }
            }
            Describe 'Set-FirefoxConfiguration' {
                $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
                $firefoxPreference.InstallDirectory = $mockInstallDirectory
                $firefoxPath = "$mockInstallDirectory\Mozilla.cfg"
                $autoconfigPath = "$mockInstallDirectory\defaults\pref\autoconfig.js"
                $mergedConfiguration = @(
                    $firefoxPreference
                    $firefoxPreference2
                )

                Context 'When configuring Mozilla.cfg with no prior configuration' {
                    New-Item -Path $firefoxPath -ItemType File -Force
                    Mock -CommandName Merge-FirefoxPreference -MockWith {$firefoxPreference}
                    Mock -CommandName Format-FireFoxPreference -MockWith {'"Ask Every Time"'}

                    Set-FireFoxPreference @firefoxPreference
                    $content = Get-Content -Path $firefoxPath

                    It 'Should start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -match '^\\\\'} | Should -Be $true
                    }
                    It 'Should only contain 2 lines' {
                        $content.Count | Should -Be 2
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("security.default_personal_cert", "Ask Every Time");'
                    }
                }

                Context 'When configuring Mozilla.cfg with prior configuration' {
                    $firefoxPreference2.InstallDirectory = $mockInstallDirectory
                    New-Item -Path $firefoxPath -ItemType File -Force
                    Mock -CommandName Format-FireFoxPreference -ParameterFilter {$Value -eq 'Ask Every Time'} -MockWith {'"Ask Every Time"'}
                    Mock -CommandName Format-FireFoxPreference -ParameterFilter {$Value -eq 'false'} -MockWith {'false'}
                    Mock -CommandName Merge-FirefoxPreference -MockWith {$mergedConfiguration}

                    Set-FireFoxPreference @firefoxPreference2
                    $content = Get-Content -Path $firefoxPath

                    It 'Should start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -match '^\\\\'} | Should -Be $true
                    }
                    It 'Should only contain 3 lines' {
                        $content.Count | Should -Be 3
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("network.protocol-handler.external.shell", false);'
                        $content | Should -Contain 'lockPref("security.default_personal_cert", "Ask Every Time");'
                    }
                }
                Context 'When configuring autoconfig.js' {
                    $autoconfigPreference = @{
                        PreferenceType   = 'lockPref'
                        PreferenceName   = 'general.config.filename'
                        PreferenceValue  = 'Mozilla.cfg'
                        InstallDirectory = $mockInstallDirectory
                    }

                    $autoconfigPreference2 = @{
                        PreferenceType   = 'lockPref'
                        PreferenceName   = 'general.config.obscure_value'
                        PreferenceValue  = '0'
                        InstallDirectory = $mockInstallDirectory
                    }

                    New-Item -Path $autoconfigPath -ItemType File -Force
                    Mock -CommandName Merge-FirefoxPreference -MockWith {@($autoconfigPreference, $autoconfigPreference2)}
                    Mock -CommandName Format-FireFoxPreference -ParameterFilter {$Value -eq 'Mozilla.cfg'} -MockWith {'"Mozilla.cfg"'}
                    Mock -CommandName Format-FireFoxPreference -ParameterFilter {$Value -eq '0'} -MockWith {'0'}

                    Set-FireFoxPreference @autoconfigPreference -File 'Autoconfig'
                    $content = Get-Content -Path $autoconfigPath

                    It 'Should not start with a comment' {
                        {(Select-Object -InputObject $content -First 1) -notmatch '^\\\\'} | Should -Be $true
                    }
                    It 'Should contain 2 lines' {
                        $content.Count | Should -Be 2
                    }
                    It 'Should contain defined preference' {
                        $content | Should -Contain 'lockPref("general.config.filename", "Mozilla.cfg");'
                        $content | Should -Contain 'lockPref("general.config.obscure_value", 0);'
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
                        {Merge-FirefoxPreference @firefoxPreference -File 'Mozilla'} | Should -Not -Throw
                    }
                    It 'Should return the supplied configuration' {
                        $result = Merge-FirefoxPreference @firefoxPreference -File 'Mozilla'


                        $result.PreferenceType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.PreferenceValue | Should -Be 'Ask Every Time'
                    }
                }
                Context 'When current configuration exists and matches supplied configuration' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    $result = Merge-FirefoxPreference @firefoxPreference -File 'Mozilla'
                    It 'Should not throw' {
                        {Merge-FirefoxPreference @firefoxPreference -File 'Mozilla'} | Should -Not -Throw
                    }
                    It 'Should return the supplied configuration' {
                        $result.PreferenceType | Should -Be 'lockPref'
                        $result.PreferenceName | Should -Be 'security.default_personal_cert'
                        $result.PreferenceValue | Should -Be 'Ask Every Time'
                    }
                    It 'Should not have duplicates' {
                        $result.PreferenceType.Count | Should -Be 1
                        $result.PreferenceName.Count | Should -Be 1
                        $result.PreferenceValue.Count | Should -Be 1
                    }
                }
                Context 'When current configuration exists and does not match supplied configuration' {
                    Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}
                    $result = Merge-FirefoxPreference @firefoxPreference2 -File 'Mozilla'
                    It 'Should not throw' {
                        {Merge-FirefoxPreference @firefoxPreference2 -File 'Mozilla'} | Should -Not -Throw
                    }
                    It 'Should have multiple values' {
                        $result.PreferenceType.Count | Should -Be 2
                        $result.PreferenceName.Count | Should -Be 2
                        $result.PreferenceValue.Count | Should -Be 2
                    }
                    It 'Should have correct configuration' {
                        $result.PreferenceType | Should -Contain 'lockPref'
                        $result.PreferenceName | Should -Contain 'security.default_personal_cert'
                        $result.PreferenceValue | Should -Contain 'Ask Every Time'
                        $result.PreferenceName | Should -Contain 'network.protocol-handler.external.shell'
                        $result.PreferenceValue | Should -Contain 'false'
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
