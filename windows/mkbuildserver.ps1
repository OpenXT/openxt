# Install all the default mkbuildmachine packages
& .\mkbuildmachine.ps1
if ($LastExitCode -ne 0) {
  exit 1
}

# Install specific packages required by the build daemon
& .\mkbuildmachine.ps1 -package python
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
xcopy BuildDaemon\winbuildd.bat "$($startup)\winbuildd.bat"
