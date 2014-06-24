# arguements expected
#   0: build directory
#   1: http source

if (!($args.Length -ieq 3))
{
    Write-Host "Cygwin          : Must supply adequate arguments!"
    return 1
}

$folder =   ("{0}\cygwin" -f $args[0])
$setup =    ("{0}\setup.exe" -f $folder)
$download = $args[1]
$mirror =   $args[2]

# Clean start
if ([IO.Directory]::Exists($folder))
{
    [IO.Directory]::Delete($folder, $true)
}
[IO.Directory]::CreateDirectory($folder)

$client = New-Object System.Net.WebClient
$client.DownloadFile($download, $setup)

# Ideally we would like to run the cygwin installer with something like the following package list:
#  -P "vim,git,rsync,zip,unzip,libiconv,guilt,openssh"
# Unfortunately doing this with the -q silent option does not work. The workaround is to do the following:
# 1. Add the -X option to the command line below, disabling validation of setup.ini
# 2. From the local package repository mirror, get a copy of setup.bz2 and unpack it.
# 3. Open the "setup" file that is unzipped and change the Category of each of the package list items you want to be "Base".
# 4. Make a copy of setup as setup.ini and bzip2 the new setup back to setup.bz2.
# 5. Overwrite setup.ini and setup.bz2 in the root of the mirror with these new files.

# Piping the output to Write-Host forces the script to wait for Cygwin and gives us nice logs
& $setup -q -X -O -s $mirror -P "git,zip,unzip" | Write-Host

