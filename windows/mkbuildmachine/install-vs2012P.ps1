# arguments expected
#   0: build directory
#   1: URL

if (!($args.Length -ieq 2))
{
    Write-Host "VS2012P           : Incorrect number of arguments!"
    return 1
}

$folder = ("{0}\visual_studio_2012_P" -f $args[0])
$setup = ("{0}\vs_premium.exe" -f $folder)
$download = $args[1]
$logP = ("{0}\visual-studio-2012P-setup.log" -f $folder)

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

# Piping the output to Out-File forces the script to wait to for the command to finish before continuing - cunning eh...
Write-Host "Installing VS2012 Premium"
& $setup  /passive /norestart /Log $logP | Write-Host

return 0
