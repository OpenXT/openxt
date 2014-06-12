if (!($args.Length -ieq 2))
{
    Write-Host "Win8 WDK          : Incorrect number of arguments!"
    Write-Host "Win8 WDK          : Args -" $args.Length
    return
}

$folder = ("{0}\Win8WDK" -f $args[0])
$setup = ("{0}\wdksetup.exe" -f $folder)
$setup_msi = ("{0}\wdfcoinstaller.msi" -f $folder)
$download = $args[1]

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}

# Copy this junk to avoid miserable moronic muppetry
Copy-Item $download $folder -Recurse

Write-Host "Installing Windows 8 WDK"
& $setup /q /norestart | Write-Host
& msiexec.exe /i $setup_msi /qn  | Write-Host