function get-program-files-path32([string] $file)
{
    $arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
    if ($arch -eq "AMD64")
    {
        $programFiles32 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles(x86)"))
    }
    else
    {
        $programFiles32 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles"))
    }
    $path = $programFiles32 + $file
    
    return $path
}

if (!($args.Length -ieq 3))
{
    Write-Host "NSIS            : Must supply adequate arguments!"
    return
}

$folder =    ("{0}\nsis" -f $args[0])
$setup =     ("{0}\nsis-2.46-setup.exe" -f $folder)
$zip =       ("{0}\nsis-2.46-log.zip" -f $folder)
$download1 = $args[1]
$download2 = $args[2]

$dest = get-program-files-path32 -file "\NSIS"

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

#Download files
$client = new-object System.Net.WebClient
$client.DownloadFile($download1, $setup)
$client.DownloadFile($download2, $zip)

# By piping to Write-Host, we force the script to wait
& $setup /S | Write-Host

# Pile of pain to unzip using built in unzipper
# Pass it the zip file and destination before running copyhere
# 0x14 is a combination of:
#     0x10 - overwrite existing files
#     0x4  - hide windows dialog box
# Should be better than hoping the "unzip" program in cygwin is working from the command line at this stage
$shell_app = New-Object -com Shell.Application
$zip_file = $shell_app.namespace($zip)
$zip_dest = $shell_app.namespace($dest)
$zip_dest.Copyhere($zip_file.items(), 0x14)
