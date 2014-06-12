if (!($args.Length -ieq 2))
{
    Write-Host "Visual Studio 2012 Update 4  : Incorrect number of arguments!"
    Write-Host "Visual Studio 2012 Update 4  : Args -" $args.Length
    return
}

$folder = ("{0}\VS2012U4" -f $args[0])
$setup = ("{0}\update.exe" -f $folder)
$download = $args[1]

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}

[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

Write-Host "Installing Visual Studio 2012 Update 4"
& $setup /Passive  | Write-Host
