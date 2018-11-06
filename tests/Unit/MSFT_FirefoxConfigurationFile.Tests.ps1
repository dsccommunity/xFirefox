$Script:DSCModuleName = 'xFirefox'
$Script:DSCResourceName = 'MSFT_FirefoxConfigurationFile'

$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))
}

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Script:DSCModuleName `
    -DSCResourceName $Script:DSCResourceName `
    -TestType Unit

try
{
    Describe 'Get-DscResource'{
        Context 'When Firefox InstallDirectory is missing or incorrect'{
            Mock -CommandName Test-Path -MockWith {$false} -ParameterFilter $TestDrive\
        }
    }

    Describe 'Set-DscResource'{

    }

    Describe 'Test-DscResource'{

    }

    Describe 'Helper functions'{

    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}
