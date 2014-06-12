# arguments expected
#   0: build directory
#   1: http source

if (!($args.Length -ieq 2))
{
    Write-Host "SQLSEC 4 x32  : Must supply build directory and exe URL!"
    Write-Host "SQLSEC 4 x32  : Args -" $args[0] $args[1]
    return
}

Write-Host "Installing SQLSEC 4 x32"
$folder =   ("{0}\SQLSECx32" -f $args[0])
$setup =    ("{0}\SQLSECx32.exe" -f $folder)
$download = $args[1]

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

& $setup /package /passive | Write-Host
