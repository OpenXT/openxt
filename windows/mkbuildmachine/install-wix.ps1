if (!($args.Length -ieq 2))
{
    Write-Host "Wix               : Incorrect number of arguments!"
    Write-Host "Wix               : Args -" $args.Length
    return
}

$folder = ("{0}\Wix" -f $args[0])
$setup = ("{0}\wix.exe" -f $folder)
$download = "http://download-codeplex.sec.s-msft.com/Download/Release?ProjectName=wix&DownloadId=762937&FileTime=130301249344430000&Build=20911"

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}

[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

Write-Host "Installing Wix"
& $setup -passive  | Write-Host
