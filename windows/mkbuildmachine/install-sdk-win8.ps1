if (!($args.Length -ieq 2))
{
    Write-Host "Win8 SDK          : Incorrect number of arguments!"
    Write-Host "Win8 SDK          : Args -" $args.Length
    return
}

$folder =  ("{0}\Win8SDK" -f $args[0])
$setup =   ("{0}\sdksetup.exe" -f $folder)
$vs_log =  ("{0}\sdk-vs-win8.log" -f $folder)
$download =  $args[1]

if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}

# Copy this junk to avoid miserable moronic muppetry
Copy-Item $download $folder -Recurse

Write-Host "Installing Windows 8 SDK"
& $setup /q /norestart /Log $vs_log | Write-Host
