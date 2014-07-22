$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $ScriptDir\PackageLibrary.psm1

foreach ($p in (Get-Packages)) {
  if (&('Test-'+$p)) {
    Write-Host "$p no action needed"
  } else {
    Write-Host "$p needs installing"
  }
}

