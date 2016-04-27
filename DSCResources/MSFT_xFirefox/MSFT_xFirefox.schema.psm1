Configuration MSFT_xFirefox
{
    param
    (
        [string]
        $VersionNumber = "latest",
        [string]
        $Language = "en-US",
        [string]
        $OS = "win",
        [ValidateSet("x86", "x64")]
        [string]
        $MachineBits = "x86",
        [string]
        $LocalPath = "$env:SystemDrive\Windows\DtlDownloads\Firefox Setup " + $VersionNumber +".exe"
    )
    
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    if ($MachineBits -eq "x64") {
        $OS += "64"
    }

    xRemoteFile Downloader
    {
        Uri = "https://download.mozilla.org/?product=firefox-" + $VersionNumber + "&os=" + $OS + "&lang=" + $Language
        DestinationPath = $LocalPath
    }
     
    Package Installer
    {
        Ensure = "Present"
        Path = $LocalPath
        Name = "Mozilla Firefox " + $VersionNumber + " (" + $MachineBits + " " + $Language +")"
        ProductId = ''
        Arguments = "/SilentMode"
        DependsOn = "[xRemoteFile]Downloader"
    }
}
