. ((Split-Path -Parent $MyInvocation.MyCommand.Path) + "\winbuild-utils.ps1")

# God Check - If there's no installer something has gone wrong & error checking needs tightening up!
if (!(Test-Path -Path ".\msi-installer\iso\windows\setup.exe"))
{
	Write-Host ("Error: Failed to create the installer")
	ExitWithCode -exitcode $global:failure
}

$args | Foreach-Object {$argtable = @{}} {if ($_ -Match "(.*)=(.*)") {$argtable[$matches[1]] = $matches[2];}}
$OutDir = $argtable["OutDir"]

#Create output directory
New-Item -Path $outdir -Type Directory -Force > $null
Write-Host ("Created output directory: " + $outdir) 

# Zip some bad boys up
Write-Host "Zipping up xc-windows build."
& zip -r xc-windows xc-windows 2>&1
if (!(Test-Path -Path "xc-windows.zip" -PathType Leaf))
{
	Write-Host ("Error: Check for xc-windows.zip failed.")
	ExitWithCode -exitcode $global:failure
}
Move-Item -Path "xc-windows.zip" -Destination $outdir -Force

Write-Host "Zipping up win-tools build."
& zip -r win-tools win-tools 2>&1
if (!(Test-Path -Path "win-tools.zip" -PathType Leaf))
{
	Write-Host ("Error: Check for win-tools.zip failed.")
	ExitWithCode -exitcode $global:failure
}
Move-Item -Path "win-tools.zip" -Destination $outdir -Force

Push-Location -Path "msi-installer\iso"
Write-Host "Zipping up xctools-iso directory."
& zip -r ../iso . 2>&1
if (!(Test-Path -Path "..\iso.zip" -PathType Leaf))
{
	Write-Host ("Error: Check for iso.zip failed.")
	ExitWithCode -exitcode $global:failure
}
Pop-Location
Move-Item -Path ".\msi-installer\iso.zip" -Destination ($outdir + "\xctools-iso.zip") -Force

# Create sdk zip.
Write-Host "Zipping up sdk directory."
Push-Location -Path "sdk"
& zip -r ../sdk . 2>&1
if (!(Test-Path -Path "..\sdk.zip" -PathType Leaf))
{
	Write-Host ("Error: Check for sdk.zip failed.")
	ExitWithCode -exitcode $global:failure
}
Pop-Location
Move-Item -Path ".\sdk.zip" -Destination ($outdir + "\sdk.zip") -Force

if (!(Test-Path -Path ($outdir + "\xc-windows.zip") -PathType Leaf))
{
	Write-Host "Warning: Check for xc-windows.zip failed. But it's not build vital so carry on..."
}
if (!(Test-Path -Path ($outdir + "\win-tools.zip") -PathType Leaf))
{
	Write-Host "Error: Check for win-tools.zip failed. But it's not build vital so carry on..."
}
if (!(Test-Path -Path ($outdir + "\xctools-iso.zip") -PathType Leaf))
{
	Write-Host "Error: Check for xctools-iso.zip failed. Build unsuccessful."
	ExitWithCode -exitcode $global:failure
}
if (!(Test-Path -Path ($outdir + "\sdk.zip") -PathType Leaf))
{
	Write-Host "Error: Check for sdk.zip failed. Build unsuccessful."
	ExitWithCode -exitcode $global:failure
}

Write-Host ("Completed " + $cmdinv)
ExitWithCode -exitcode $global:success
