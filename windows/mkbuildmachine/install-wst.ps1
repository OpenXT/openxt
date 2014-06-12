# arguements expected
#   0: build directory
#   1: http source

if (!($args.Length -ieq 2))
{
    Write-Host "Winqual Submission Tool : Must supply build directory and HTTP URL arguments!"
    Write-Host "Winqual Submission Tool : Args -" $args[0] $args[1]
    return
}

$folder =   ("{0}\WinqualSubmissionTool" -f $args[0])
$setup =    ("{0}\WinqualSubmissionTool.msi" -f $folder)
$download = ("{0}" -f $args[1])

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

# Piping the output forces the script to wait to for the command to finish before continuing - cunning eh...
& msiexec.exe /i $setup /qn  | Write-Host
