if (!($args.Length -ieq 2))
{
    Write-Host "7zip               : Must supply adequate arguments!"
    return
}

$folder =    ("{0}\7zip" -f $args[0])
$setup =     ("{0}\7zip.msi" -f $folder)
$download = $args[1]

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

#Download files
$client = new-object System.Net.WebClient
$client.DownloadFile($download, $setup)

Write-Host "Installing 7zip"
& msiexec /i $setup /q | Write-Host
