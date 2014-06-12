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

if (!($args.Length -ieq 2))
{
    Write-Host "CAPICOM            : Must supply adequate arguments!"
    return
}

$folder =    ("{0}\capicom" -f $args[0])
$setup =     ("{0}\capicom.msi" -f $folder)
$download = $args[1]

$dll = get-program-files-path32 -file "\Microsoft CAPICOM 2.1.0.2 SDK\Lib\X86\capicom.dll"

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

#Download files
$client = new-object System.Net.WebClient
$client.DownloadFile($download, $setup)

# By piping to Write-Host, we force the script to wait
& msiexec.exe /i $setup /qn  | Write-Host
regsvr32 $dll /s