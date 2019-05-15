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

# Begin Tests
try
{
    InModuleScope $DscResourceName {
        Describe 'MSFT_xFirefoxPreference\Get-TargetResource' {
            $firefoxPreference = @{
                PreferenceType   = 'lockPref'
                PreferenceName   = 'security.default_personal_cert'
                PreferenceValue  = 'Ask Every Time'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

            [System.Object[]] $firefoxcfg = @(
                '// FireFox preference file'
                'lockPref("security.default_personal_cert", "Ask Every Time");'
            )

            Mock -CommandName Get-Content -MockWith {$firefoxcfg}
            Mock -CommandName Get-FirefoxPreference -MockWith {$firefoxPreference}

            Context 'When Firefox InstallDirectory is missing or incorrect' {
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq $firefoxPreference.InstallDirectory}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"'{
                    $result = Get-TargetResource -InstallDirectory $firefoxPreference.InstallDirectory -PreferenceName $firefoxPreference.PreferenceName
                    $result.InstallDirectory | Should -Be $firefoxPreference.InstallDirectory
                    $result.PreferenceType | Should -Be $null
                    $result.PreferenceName | Should -Be $null
                    $result.PreferenceValue | Should -Be $null

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 -Scope It
                }
            }
            Context 'When Mozilla.cfg path is missing or incorrect' {
                Mock -CommandName Test-Path -MockWith {$true} -ParameterFilter {$Path -eq $firefoxPreference.InstallDirectory}
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq "$($firefoxPreference.InstallDirectory)\Mozilla.cfg"}
                Mock -CommandName Write-Verbose

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"' {
                    $result = Get-TargetResource -InstallDirectory $firefoxPreference.InstallDirectory -PreferenceName $firefoxPreference.PreferenceName
                    $result.InstallDirectory | Should -Be $firefoxPreference.InstallDirectory
                    $result.PreferenceType | Should -Be $null
                    $result.PreferenceName | Should -Be $null
                    $result.PreferenceValue | Should -Be $null

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName Write-Verbose -Exactly -Times 1 -Scope It
                }
            }
            Context 'When Mozilla.cfg does exist' {
                Mock -CommandName Test-Path -MockWith {$true}

                It 'Should return the correct preferences in the correct format' {
                    $result = Get-TargetResource -InstallDirectory $firefoxPreference.InstallDirectory -PreferenceName $firefoxPreference.PreferenceName
                    $result.InstallDirectory | Should -Be $firefoxPreference.InstallDirectory
                    $result.PreferenceType | Should -Be $firefoxPreference.PreferenceType
                    $result.PreferenceName | Should -Be $firefoxPreference.PreferenceName
                    $result.PreferenceValue | Should -Be $firefoxPreference.PreferenceValue

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName Get-FirefoxPreference -Exactly -Times 1 -Scope It
                }
            }
        }

        Describe 'MSFT_xFirefoxPreference\Set-TargetResource'{
            $firefoxPreference = @{
                PreferenceType   = 'lockPref'
                PreferenceName   = 'security.default_personal_cert'
                PreferenceValue  = 'Ask Every Time'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

            Mock -CommandName Set-FirefoxPreconfiguration
            Mock -CommandName Set-FirefoxPreference

            Context 'When The Install Directory Path is incorrect'{
                Mock -CommandName Test-Path -MockWith {$false}

                It 'Should throw the correct exception' {
                    {Set-TargetResource @firefoxPreference} | Should -Throw "$($firefoxPreference.InstallDirectory) not found. Verify Firefox is installed and the correct Install Directory is defined."
                }
            }
            Context 'When Firefox preconfigurations are not complete'{
                Mock -CommandName Test-Path -MockWith {$true}
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {'autoconfigfile'}

                It 'Should call Set-FirefoxPreconfiguration' {
                    Set-TargetResource @firefoxPreference
                    Assert-MockCalled -CommandName 'Set-FirefoxPreconfiguration' -Times 1 -Exactly -Scope It
                }
                It 'Should call Set-FirefoxConfiguration' {
                    Set-TargetResource @firefoxPreference
                    Assert-MockCalled -CommandName 'Set-FirefoxPreference' -Times 1 -Exactly -Scope It
                }
            }
            Context 'When Firefox preconfigurations are complete'{
                Mock -CommandName Test-Path -MockWith {$true}
                Mock -CommandName Test-FirefoxPreconfiguration

                It 'Should not call Set-FirefoxPreconfiguration' {
                    Set-TargetResource @firefoxPreference
                    Assert-MockCalled -CommandName 'Set-FirefoxPreconfiguration' -Times 0 -Exactly -Scope It
                }
                It 'Should call Set-FirefoxPreference' {
                    Set-TargetResource @firefoxPreference
                    Assert-MockCalled -CommandName 'Set-FirefoxPreference' -Times 1 -Exactly -Scope It
                }
            }
        }

        Describe 'MSFT_xFirefoxPreference\Test-TargetResource'{
            $firefoxPreference = @{
                PreferenceType   = 'lockPref'
                PreferenceName   = 'security.default_personal_cert'
                PreferenceValue  = 'Ask Every Time'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

            Mock -CommandName Get-TargetResource -MockWith {$firefoxPreference}

            Context 'When Firefox Preconfigurations are not complete'{
                Mock -CommandName Test-FirefoxPreconfiguration -MockWith {'AutoConfigFile'}
                Mock -CommandName Test-FirefoxPreference -MockWith {$true}

                It 'Should return False'{
                    $result = Test-TargetResource @firefoxPreference
                    $result | Should -Be $false
                }
                It 'Should not call "Test-FirefoxPreference"' {
                    Test-TargetResource @firefoxPreference
                    Assert-MockCalled -CommandName Test-FirefoxPreconfiguration -Times 1 -Exactly -Scope It
                    Assert-MockCalled -CommandName Test-FirefoxPreference -Times 0 -Exactly -Scope It
                }
            }
            Context 'When Firefox preferences are incorrect' {
                Mock -CommandName Test-FirefoxPreconfiguration
                Mock -CommandName Test-FirefoxPreference -MockWith {$false}

                It 'Should return False' {
                    $result = Test-TargetResource @firefoxPreference
                    $result | Should -Be $false
                }
            }
            Context 'When Firefox preferences are correct' {
                Mock -CommandName Test-FirefoxPreconfiguration
                Mock -CommandName Test-FirefoxPreference -MockWith {$true}

                It 'Should return True' {
                    $result = Test-TargetResource @firefoxPreference
                    $result | Should -Be $true
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}
