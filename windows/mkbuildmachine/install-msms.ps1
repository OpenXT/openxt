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

# arguements expected
#   0: build directory
#   1: cis/smb share

if (!($args.Length -ieq 1))
{
    Write-Host "VS2005 MSMs          : Must supply adequate arguments!"
    return
}

$msms = $args[0]
$msmdest = get-program-files-path32 -file "\Common Files\Merge Modules"

# Copy the MSM merge module files from Visual Studio 2005 for xc-windows.git build
& Copy-Item -Path $msms -Destination $msmdest
