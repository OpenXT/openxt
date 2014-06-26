if (!($args.Length -ieq 3))
{
    Write-Host "Win8 WDK          : Incorrect number of arguments!"
    Write-Host "Win8 WDK          : Args -" $args.Length
    return
}

$folder = ("{0}\Win8WDK" -f $args[0])
$setup = ("{0}\wdksetup.exe" -f $folder)
$setup_msi = ("{0}\wdfcoinstaller.msi" -f $folder)
$download1 = $args[1]
$download2 = $args[2]

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

#Download files
$client = new-object System.Net.WebClient
$client.DownloadFile($download1, $setup)
$client = new-object System.Net.WebClient
$client.DownloadFile($download2, $setup_msi)

Write-Host "Installing Windows 8 WDK"
& $setup /q /norestart | Write-Host
& msiexec.exe /i $setup_msi /qn  | Write-Host
