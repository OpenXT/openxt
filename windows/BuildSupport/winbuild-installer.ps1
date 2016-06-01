. ((Split-Path -Parent $MyInvocation.MyCommand.Path) + "\winbuild-utils.ps1")

# Split each key-value pair into hash table entires
$args | Foreach-Object {$argtable = @{}} {if ($_ -Match "(.*)=(.*)") {$argtable[$matches[1]] = $matches[2];}}

$setupFile = ".\xc-windows\install\xensetup.exe"
if (!(Test-Path -Path $setupFile)) {
    throw "$setupFile not found"
}

#Set up web client to download stuff
[System.Net.WebClient] $wclient = New-Object System.Net.WebClient

# Create directory to store bootstrapper packages
new-item -ItemType directory -Path ".\msi-installer\bootstrapper\packages" -Force

# Move the newly compiled xensetup package to the packages directory
Copy-Item $setupFile .\msi-installer\bootstrapper\packages -Force -V
if (-Not ($?)) {
    throw "Unable to copy xensetup.exe"
}

# Create directory to store the necessary merge modules
new-item -ItemType directory -Path ".\msi-installer\installer\Modules" -Force

ExitWithCode -exitcode $global:success
