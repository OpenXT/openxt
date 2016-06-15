param
(
  [string]$mirror = "",
  [string]$proxy = ""
)

# Install all the default mkbuildmachine packages
& .\mkbuildmachine.ps1 -mirror $mirror -proxy $proxy
if ($LastExitCode -ne 0) {
  exit 1
}

# Install specific packages required by the build daemon
& .\mkbuildmachine.ps1 -mirror $mirror -proxy $proxy -package python
if ($LastExitCode -ne 0) {
  exit 1
}

# Create the certificate
& .\makecert.bat developer

# Install the build daemon
$winbuildd_exists = Test-Path("C:\winbuildd")
if ($winbuildd_exists -ne $True) {
  mkdir C:\winbuildd
}
copy BuildDaemon\winbuild.cfg C:\winbuildd\winbuild.cfg
copy BuildDaemon\winbuildd.py C:\winbuildd\winbuildd.py
copy BuildDaemon\start.ps1 C:\winbuildd\start.ps1

# Auto-start the build daemon
$startmenu = [Environment]::GetFolderPath("StartMenu")
$startup = "$($startmenu)\Programs\Startup"
$startupExists = Test-Path $($startup)
if ($startupExists -ne $True) {
  mkdir $startup
}
copy BuildDaemon\winbuildd.bat "$($startup)\winbuildd.bat"

# Create ssh key
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
cd C:\winbuildd
ssh-keygen -t rsa -N "''" -f id_rsa

# Done
Write-Host "Done. Please reboot one last time."
Write-Host "Make sure winbuildd starts and continue the host setup script."
