# arguments expected
#   0: build directory
#   1: http source

if($ENV:Processor_Architecture -eq "x86") { return 0 }

if (!($args.Length -ieq 2))
{
    Write-Host "SQLSEC 4 x64  : Must supply build directory and exe URL!"
    Write-Host "SQLSEC 4 x64  : Args -" $args[0] $args[1]
    return
}

Write-Host "Installing SQLSEC 4 x64"
$folder =   ("{0}\SQLSECx64" -f $args[0])
$setup =    ("{0}\SQLSECx64.exe" -f $folder)
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
