. ((Split-Path -Parent $MyInvocation.MyCommand.Path) + "\winbuild-utils.ps1")

# Split each key-value pair into hash table entires
$args | Foreach-Object {$argtable = @{}} {if ($_ -Match "(.*)=(.*)") {$argtable[$matches[1]] = $matches[2];}}
$c = $argtable["BuildType"]

#Create sdk directory.
New-Item -Path .\sdk -Type Directory -Force

#Copy sdk files to sdk directory
Copy-Item .\win-tools\MSMs\bin\XenClientGuestClientConsoleTestInstaller.msi .\sdk -Force -V

#Test the copies worked
if (!(Test-Path -Path ".\sdk\XenClientGuestClientConsoleTestInstaller.msi" -PathType Leaf))
{
	Write-Host ("ERROR: Copy of XenClientGuestClientConsoleTestInstaller.msi failed.")
	ExitWithCode -exitcode $global:failure
}
