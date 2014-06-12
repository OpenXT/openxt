# arguements expected
#   0: build directory
#   1: http source

if (!($args.Length -ieq 2))
{
    Write-Host "dotNet Framework 4.5 : Must supply build directory and HTTP URL arguments!"
    Write-Host "dotNet Framework 4.5 : Args -" $args[0] $args[1]
    return
}

$folder =   ("{0}\dotNetFx45" -f $args[0])
$setup =    ("{0}\dotNetFx45_Full_setup.exe" -f $folder)
$download = $args[1]

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

Write-Host "Installing dotNet Framework 4.5"
& $setup /passive /norestart  | Write-Host

