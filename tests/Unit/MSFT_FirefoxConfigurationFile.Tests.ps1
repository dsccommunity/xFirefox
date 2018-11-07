$Script:DSCModuleName = 'xFirefox'
$Script:DSCResourceName = 'MSFT_FirefoxConfigurationFile'
#region Header
#Unit Test Template Version: 1.0.0

#$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
#if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
#     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
#{
#    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
#}
#
#Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
#
#$TestEnvironment = Initialize-TestEnvironment `
#    -DSCModuleName $script:DSCModuleName `
#    -DSCResourceName $script:DSCResourceName `
#    -TestType Unit
##endregion

[System.Object[]] $firefoxcfg = @(
    '// FireFox preference file'
    'lockPref("security.default_personal_cert", "Ask Every Time");'
    'lockPref("network.protocol-handler.external.shell", false);'
)

$currentPref = @(
    @{
        PrefType       = 'lockPref'
        PreferenceName = 'security.default_personal_cert'
        Value          = 'Ask Every Time'
    }
    @{
        PrefType       = 'lockPref'
        PreferenceName = 'network.protocol-handler.external.shell'
        Value          = 'false'
    }
)
#
## Begin Tests
#try
#{

    Import-Module C:\Source\Repos\xFirefox\xFirefox.psd1
    InModuleScope $DSCResourceName {
        Describe 'Get-DscResource'{
            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
            Mock -CommandName Get-Content -MockWith {$firefoxcfg}
            Mock -CommandName Get-FirefoxPreference -MockWith {$currentPref}

            Context 'When Firefox InstallDirectory is missing or incorrect'{
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq $mockInstallDirectory}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"'{
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration | Should -Be $null
                }
            }
            Context 'When firefox.cfg path is missing or incorrect' {
                Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter {$Path -eq "$mockInstallDirectory\firefox.cfg"}

                It 'Should return a null "CurrentConfiguration" and the desired "InstallDirectory"' {
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory
                    $result.InstallDirectory | Should -Be $mockInstallDirectory
                    $result.CurrentConfiguration | Should -Be $null
                }
            }
            Context 'When firefox.cfg does exist' {
                Mock -CommandName Test-Path -MockWith {$true}

                It 'Should the correct preferences in the correct format' {
                    $result = Get-TargetResource -InstallDirectory $mockInstallDirectory
                    $result | Should -Not -BeNullOrEmpty
                }
            }
        }

        Describe 'Set-DscResource'{

        }

        Describe 'Test-DscResource'{

        }

        Describe 'Helper functions'{

        }
    }
#}
#finally
#{
#    Restore-TestEnvironment -TestEnvironment $TestEnvironment
#}
