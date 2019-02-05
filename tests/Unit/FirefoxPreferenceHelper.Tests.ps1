Import-Module "$moduleRoot\DSCResources\FirefoxPreferenceHelper.psm1"

try
{
    InModuleScope FirefoxPreferenceHelper {
        Describe 'Test-FirefoxPreconfiguration' {
            [System.Object[]] $firefoxcfg = @(
                '// FireFox preference file'
                'lockPref("security.default_personal_cert", "Ask Every Time");'
            )

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
        Describe 'Set-FirefoxPreconfiguration' {

            $mockInstallDirectory = "$TestDrive\Mozilla Firefox"
            $autoConfigPath = "$mockInstallDirectory\defaults\pref\autoconfig.js"
            $firefoxCfgPath = "$mockInstallDirectory\Mozilla.cfg"

            Mock -CommandName New-Item
            Mock -CommandName Get-Content
            Mock -CommandName Out-File
            Mock -CommandName Set-FirefoxPreference

            Context 'When filename is incorrectly configured and file exists'{
                Mock -CommandName Test-Path -MockWith {$true}

                It 'Should not throw'{
                    {Set-FirefoxPreconfiguration -Preconfiguration 'filename' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                }
                It 'Should run only required commands' {
                    Set-FirefoxPreconfiguration -Preconfiguration 'filename' -InstallDirectory $mockInstallDirectory

                    Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath} -Exactly -Scope It
                    Assert-MockCalled -CommandName New-Item -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Get-Content -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Out-File -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1 -Exactly -Scope It
                }
            }
            Context 'When filename is incorrectly configured and file does not exist'{
                Mock -CommandName Test-Path -MockWith {$false}

                It 'Should not throw'{
                    {Set-FirefoxPreconfiguration -Preconfiguration 'filename' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                }
                It 'Should run only required commands' {
                    Set-FirefoxPreconfiguration -Preconfiguration 'filename' -InstallDirectory $mockInstallDirectory

                    Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath} -Exactly -Scope It
                    Assert-MockCalled -CommandName New-Item -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath} -Exactly -Scope It
                    Assert-MockCalled -CommandName Get-Content -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Out-File -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1 -Exactly -Scope It
                }
            }
            Context 'When obscurevalue is incorrectly configured and file exists'{
                Mock -CommandName Test-Path -MockWith {$true}

                It 'Should not throw'{
                    {Set-FirefoxPreconfiguration -Preconfiguration 'obscurevalue' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                }
                It 'Should run only required commands' {
                    Set-FirefoxPreconfiguration -Preconfiguration 'obscurevalue' -InstallDirectory $mockInstallDirectory

                    Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath} -Exactly -Scope It
                    Assert-MockCalled -CommandName New-Item -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Get-Content -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Out-File -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1 -Exactly -Scope It
                }
            }
            Context 'When obscurevalue is incorrectly configured and file does not exist'{
                Mock -CommandName Test-Path -MockWith {$false}

                It 'Should Not throw'{
                    {Set-FirefoxPreconfiguration -Preconfiguration 'obscurevalue' -InstallDirectory $mockInstallDirectory} | Should -Not -Throw
                }
                It 'Should run only required commands' {
                    Set-FirefoxPreconfiguration -Preconfiguration 'obscurevalue' -InstallDirectory $mockInstallDirectory

                    Assert-MockCalled -CommandName Test-Path -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath} -Exactly -Scope It
                    Assert-MockCalled -CommandName New-Item -Times 1 -ExclusiveFilter {$Path -eq $autoConfigPath} -Exactly -Scope It
                    Assert-MockCalled -CommandName Get-Content -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Out-File -Times 0 -Exactly -Scope It
                    Assert-MockCalled -CommandName Set-FirefoxPreference -Times 1 -Exactly -Scope It
                }
            }
        }
        Describe 'Get-FirefoxPreference' {
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

            Mock -CommandName Split-FirefoxPreference -MockWith {$firefoxPreference}
            Mock -CommandName Get-Content -MockWith {$firefoxcfg}

            Context 'When no "Preference" is defined' {
                It 'Should return the correct object'{
                    $result = Get-FirefoxPreference -InstallDirectory $firefoxPreference.InstallDirectory -File 'Mozilla'
                    $result.PreferenceType | Should -Be 'lockPref'
                    $result.PreferenceName | Should -Be 'security.default_personal_cert'
                    $result.PreferenceValue | Should -Be 'Ask Every Time'
                }
            }
            Context 'When "Preference" is defined' {
                It 'Should return the correct object'{
                    $result = Get-FirefoxPreference -PreferenceName $firefoxPreference.PreferenceName -InstallDirectory $firefoxPreference.InstallDirectory -File 'Mozilla'
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
            $firefoxPreference = @{
                PreferenceType   = 'lockPref'
                PreferenceName   = 'security.default_personal_cert'
                PreferenceValue  = 'Ask Every Time'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

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
            $firefoxPreference = @{
                PreferenceType   = 'lockPref'
                PreferenceName   = 'security.default_personal_cert'
                PreferenceValue  = 'Ask Every Time'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

            $firefoxPreference2 = @{
                PreferenceType  = 'lockPref'
                PreferenceName  = 'network.protocol-handler.external.shell'
                PreferenceValue = 'false'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

            $firefoxPath = "$($firefoxPreference.InstallDirectory)\Mozilla.cfg"
            $autoconfigPath = "$($firefoxPreference.InstallDirectory)\defaults\pref\autoconfig.js"
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
                $mergedConfiguration = @($firefoxPreference,$firefoxPreference2)

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
                    InstallDirectory = $firefoxPreference.InstallDirectory
                }

                $autoconfigPreference2 = @{
                    PreferenceType   = 'lockPref'
                    PreferenceName   = 'general.config.obscure_value'
                    PreferenceValue  = '0'
                    InstallDirectory = $firefoxPreference.InstallDirectory
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
            $firefoxPreference = @{
                PreferenceType   = 'lockPref'
                PreferenceName   = 'security.default_personal_cert'
                PreferenceValue  = 'Ask Every Time'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

            $firefoxPreference2 = @{
                PreferenceType  = 'lockPref'
                PreferenceName  = 'network.protocol-handler.external.shell'
                PreferenceValue = 'false'
                InstallDirectory = "$TestDrive\Mozilla Firefox"
            }

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
                $firefoxPreference = @{
                    PreferenceType   = 'lockPref'
                    PreferenceName   = 'security.default_personal_cert'
                    PreferenceValue  = 'Ask Every Time'
                    InstallDirectory = "$TestDrive\Mozilla Firefox"
                }
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
finally
{
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}
