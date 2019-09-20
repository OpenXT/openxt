# Copyright (c) 2016 Assured Information Security, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

param
(
  [string]$mirror = ""
)

# Install all the default mkbuildmachine packages
if ($mirror) {
  & .\mkbuildmachine.ps1 -mirror $mirror
} else {
  & .\mkbuildmachine.ps1
}
if ($LastExitCode -ne 0) {
  exit 1
}

# Install specific packages required by the build daemon
if ($mirror) {
  & .\mkbuildmachine.ps1 -mirror $mirror -package python
} else {
  & .\mkbuildmachine.ps1 -package python
}
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
ssh-keygen -t rsa -N '""' -f id_rsa

# Done
Write-Host "Done. Please reboot one last time."
Write-Host "Make sure winbuildd starts and continue the host setup script."
