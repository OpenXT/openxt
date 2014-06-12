# Final configuration steps for the new build machine. This version should fetch the actual value for the Path not the
# one inherited by the process. So it can be run with the rest of the scripts (I hope).

# Get the path for 32 bit apps under ProgramFiles, on a 64bit OS this is "C:\Program Files (x86)"
#
$arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
if ($arch -eq "AMD64")
{
    $programFiles32 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles(x86)"))
}
else
{
    $programFiles32 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles"))
}

# Used to add path to signtool and inf2cat but the signing BAT files find different locations
# using the Winqual Sub Tool and the certificates dir under the WDK
# [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\WinDDK\6001.18002\bin\SelfSign", [System.EnvironmentVariableTarget]::Machine)

$path = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
$path = $path + ";C:\cygwin\bin"
$path = $path + ";" + $ProgramFiles32 + "\NSIS"

# For some reason though, the doverifysign batch file just assumes signtool is in the path (sigh), so let's add it...
$path = $path + ";C:\WinDDK\6001.18002\bin\catalog"
#$path = $path + ";C:\WinDDK\7600.16385.1\bin\x86"

[Environment]::SetEnvironmentVariable("Path", $path, [System.EnvironmentVariableTarget]::Machine)

