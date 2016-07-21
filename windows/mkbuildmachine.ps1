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
  [string]$mirror = "",
  [string]$workdir = $env:temp,
  [string]$package
)

function Handle($p) {
  if (&('Test-'+$p)) {
    Write-Host "$p no action needed"
  } else {
    Write-Host "$p missing"
    &('Install-'+$p)
  }
}

$ErrorActionPreference = "Stop"

if ($workdir -ne $env:temp) {
  if (-Not (Test-Path $workdir)) {
     mkdir $workdir
  }
  $env:temp = $workdir
}

Start-Transcript -Append -Path ($env:temp+'\mkbuildmachine.log')

$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $ScriptDir\PackageLibrary.psm1 -ArgumentList $mirror

if ($package) {
  Handle($package)
  Write-Host "$package package successfully installed"
  Stop-Transcript
} else {
  foreach ($p in (Get-Packages)) {
    Handle($p)
  }
  Write-Host "Default packages successfully installed"
  Stop-Transcript
  exit 0
}

