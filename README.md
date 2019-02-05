[![Build status](https://ci.appveyor.com/api/projects/status/pe6p3pghfqkvbw77/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xfirefox/branch/master)

# xFirefox

The **xFirefox** module contains the **MSFT_xFirefox** composite resource which allows you to install the Firefox web browser


This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Resources

### MSFT_xFirefox

* **Language**: Specify the language of the browser to be installed.
The default value is English.
* **VersionNumber**: Specify the version number of the browser to be installed.
By default, the latest version is installed.
* **OS**: Specify the operating system on which the browser is to be installed.
By default, the operating system is Windows.
* **MachineBits**: Specifies the machine's operating system bit number.
The default is x86.
* **LocalPath**: The local path on the machine where the installation file should be downloaded.

### MSFT_xFirefoxPreference

* **PreferenceType**: Specify the type of Preference { Pref | lockPref | defaultPref | unlockPref | clearPref }
Specifies the preference type of the Firefox Preference to be configured
* **PreferenceName**: Specify the name of the Preference.
Specifies the name of the Firefox Preference to be configured
* **PreferenceValue**: Specify the value of the Preference.
Specifies value of the Firefox Preference to be configured
* **InstallDirectory**: Specifies the location where Mozilla Firefox is installed.
Specifies the directory where Firefox is installed

## Versions

### Unreleased

* Update appveyor.yml to use the default template.
* Added default template files .codecov.yml, .gitattributes, and .gitignore, and
  .vscode folder.
* The module manifest now contain the correct PowerShell version.
* Added xFirefoxPreference Resource to automate Firefox Preference Configuration

### 1.2.0.0

* Added logic to download installer with correct machine bits
* Added dependency on xPSDesiredStateConfiguration

### 1.1.0.0

* Updated MFST_xFireFox to pull latest version by default and use HTTPS

### 1.0.0.0

* Initial release with the following resources
    - MSFT_xFirefox

## Examples

### Install the Firefox browser

```powershell
Configuration Sample_InstallFirefoxBrowser
{
    param
    (

    [Parameter(Mandatory)]
    $VersionNumber,

    [Parameter(Mandatory)]
    $Language,

    [Parameter(Mandatory)]
    $OS,

    [Parameter(Mandatory)]
    $LocalPath

    )

    Import-DscResource -module xFirefox

    MSFT_xFirefox Firefox
    {
    VersionNumber = $VersionNumber
    Language = $Language
    OS = $OS
    LocalPath = $LocalPath
    }
}
```
