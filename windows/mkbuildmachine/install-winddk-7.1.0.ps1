# arguements expected
#   0: build directory
#   1: WDK 7.1 ISO download link

if (!($args.Length -ieq 2))
{
    Write-Host "WinDDK 7.1.0   : Must supply adequate arguments!"
    return 1
}

$folder =            ("{0}\winddk7" -f $args[0])
$folderunpacked =    ("{0}\unpacked" -f $folder)
$setup =             ("{0}\KitSetup.exe" -f $folderunpacked)
$iso =               ("{0}\GRMWDK_EN_7600_1.ISO" -f $folder)
$download =          $args[1]

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $iso)

# extract iso using 7zip
& "C:\Program Files\7-Zip\7z.exe" "x" "-y" "-o$folderunpacked" "$iso"

# Piping the output forces the script to wait to for the command to finish before continuing - cunning eh...
# Assuming that the KitSetup works more or less the same way for the Win7 WDK
& $setup /install ALL /ui-level EXPRESS | Write-Host
