############################################################################
### Script to download and install necessary tools                       ###
### No arguments expected                                                ###
############################################################################

function ExitWithCode([int32]$exitcode)
{
    $host.SetShouldExit($exitcode)
    Exit
}

#Function to execute a step's command and log the output (Only really a function to make the script a bit neater)
function execute-step-and-log([string]$command,[string]$parameters, [string]$logfile)
{
    # Trace out a basic log header
    log-info -info "--------------------------------------------------------"
    log-info -info ("Windows Build Log - " + (Get-Date))
    log-info -info ("Executing " + $command + " " + $parameters)
    log-info -info ("Working Dir: " + $global:builddir)
    log-info -info ("Logging To:  " + $global:logdir + "\" + $logfile + ".log")
    log-info -info "--------------------------------------------------------"
    # Execute the command and tee output to the log directory
    $logdir = read-config-value -config $global:cfgfile -name "LogDir"
    & $command ($parameters) | Foreach-Object {$_.ToString()} | Tee-Object ($logdir + "\" + $logfile + ".log")
}

function read-config-value([string]$config, [string]$name)
{
    [System.Xml.XmlDocument] $xd = New-Object System.Xml.XmlDocument

    $xd.Load($config)
    
    $node = $xd.SelectSingleNode("/WinbuildConfig/{0}" -f $name)

    if (!$node)
    {
        return
    }
    return $node.get_InnerXml()
}

function write-config-value([string]$config, [string]$name, [string]$value)
{
    [System.Xml.XmlDocument] $xd = New-Object System.Xml.XmlDocument

    $xd.Load($config)
    
    $node = $xd.SelectSingleNode("/WinbuildConfig/{0}" -f $name)

    if (!$node)
    {
        return $false
    }
    $node.set_InnerXml($value)
    
    $xd.Save($config)
    return $true
}


function init([string]$cmdinv, [string]$config)
{        
    # Make sure the config file is present. Running winbuild-prepare.ps1 would have copied
    # the config file to the build dir and updated it.
    $global:cfgfile = ($global:builddir + "\" + $config)
    if (!(Test-Path -Path $global:cfgfile -PathType Leaf))
    {
        Write-Host "ERROR: Config file not present - config:" $global:cfgfile
        return $false
    }

    #Setup reboot counter
    $global:RebootCount = (read-config-value -config $global:cfgfile -name "RebootCount") -as [int]

    # Setup the log file, create the logging dir if not present
    # Note the syntax when calling functions. If you supply a comma separated list (w/ or w/o
    # parens), ps turns it into an array assigned to the first arg.
    $global:logdir = read-config-value -config $global:cfgfile -name "LogDir"
    if ($global:logdir.Length -lt 1)
    {
        $global:logdir = $global:builddir + "\logs"
        
        if (!(write-config-value -config $global:cfgfile -name "LogDir" -value $global:logdir))
        {
            Write-Host "Could not write logs directory to config"
            ExitWithCode -exitcode 1
        }
    }
    
    if (!(Test-Path -Path $global:logdir -PathType Container))
    {
        New-Item -Path $global:logdir -Type Directory -Force
    }
    $global:logfile = $global:logdir + "\" + $cmdinv + ".log"

    # Set up the helpers directory
    $global:HelperDir = read-config-value -config $global:cfgfile -name "HelperDir"
    if ($global:HelperDir.Length -lt 1)
    {
        $global:HelperDir = $global:builddir + "\helpers"
        
        if (!(write-config-value -config $global:cfgfile -name "HelperDir" -value $global:HelperDir))
        {
           Write-Host "Could not write helpers directory to config"
           ExitWithCode -exitcode 1
        }
    }
    
    if (!(Test-Path -Path $global:HelperDir -PathType Container))
    {
        New-Item -Path $global:HelperDir -Type Directory -Force
    }
    
    $global:HelperURL = read-config-value -config $global:cfgfile -name "HelperURL"
    if ($global:HelperURL.Length -lt 1)
    {
           Write-Host "Could not read HelperURL from config"
           ExitWithCode -exitcode 1
    }
    
    # Trace out a basic log header
    log-info -info "--------------------------------------------------------"
    log-info -info ("Windows Build Log - " + (Get-Date))
    log-info -info ("Command:     " + $cmdinv)
    log-info -info ("Working Dir: " + $global:builddir)
    log-info -info ("Logging To:  " + $global:logfile)
    log-info -info "--------------------------------------------------------"

    return $true
}

function log-info([string]$info)
{
    Write-Host $info
    Add-Content -Path $global:logfile -Value $info
}

#Calling a script does not change the working directory, instead use the invocation command to create paths relative to this script
$cmdinv = $MyInvocation.MyCommand.Name
$global:builddir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
if (!($args.Length -ieq 1))
{
    Write-Host "Must supply a config argument to winbuild-all.ps1"
    return 1
}

# Do the common initialization of the global vars and setup a log file
if (!(init -cmdinv $cmdinv -config $args[0]))
{
    ExitWithCode -exitcode 1
}

#Setup for xml parsing
[xml]$xmlContent = [xml](Get-Content -Path $cfgfile)
[System.Xml.XmlElement]$xmlroot = $xmlContent.get_DocumentElement()
[System.Xml.XmlElement]$step = $null

#Set up web client to download stuff
[System.Net.WebClient] $wclient = New-Object System.Net.WebClient
$wclient.Proxy = $null

# Parse the config to determine how to run the build
foreach($step in $xmlroot.Steps.ChildNodes)
{
    # Filter out comment nodes
    if ($step.name.CompareTo('#comment') -ne 0)
    {
    
        if($step.name.CompareTo('REBOOT') -ne 0){
            if($global:RebootCount -eq 0){
                if ($step.helper.Length -gt 0)
                {
                    $HelperURL = $global:HelperURL + $step.helper
                    log-info -info ("Downloading helper: " + $HelperURL)

                    #Download the helper file
                    $wclient.DownloadFile($HelperURL, ($global:HelperDir + "\" + $step.helper))
                    if (!(Test-Path -Path ($global:HelperDir + "\" + $step.helper)))
                    {
                        Write-Host ("Error: Failed to download")
                        Write-Host ("Will try once more and once more only.")
                        $wclient.DownloadFile($HelperURL, ($global:HelperDir + "\" + $step.helper))
                    }
                    
                    # Check that we want to run the command for this step
                    if($step.Run.execute -ne $null -and $step.Run.execute.CompareTo("false") -ne 0)
                    {
                        # Make certain there is a command to run
                        if ($step.Run.Command.Length -gt 0)
                        {
                            $parameters = $null
                            # Create parameters string
                            if($step.Run.Parameters -ne $null)
                            {
                                foreach($param in $step.Run.Parameters.ChildNodes)
                                {
                                    $parameter = $param.'#text'
                                    $value = read-config-value -config $cfgfile -name $parameter
                                    #Check parameter value is not empty
                                    if($value.Length -ne 0){
                                      $parameters = $parameters + " " + $value #$parameter + "='" + $value + "' "
                                    }
                                }
                            }
                            
                            # Now we're all done parsing this step, execute the associated command and wait for it to return
                            execute-step-and-log -command $step.Run.Command -parameters ("& '" + ($global:HelperDir + "\" + $step.helper) + "' " + $parameters) -logfile $step.name
                            if($LastExitCode -ne 0)
                            {
                                log-info -info ("Failed trying to execute " + $step.Run.Command + " " + ($global:HelperDir + "\" + $step.helper)) 
                                ExitWithCode 1
                            }
                        }
                    }
                }
            }
        }
        else
        {
            if($global:RebootCount -eq 0)
            {
                Write-Host "Going down for a reboot"
                $NewRebootCount = (read-config-value -config $global:cfgfile -name "RebootCount") -as [int]
                $NewRebootCount++
                
                if (!(write-config-value -config $global:cfgfile -name "RebootCount" -value $NewRebootCount))
                {
                    Write-Host "Could not write RebootCount to config"
                    ExitWithCode -exitcode 1
                }
                
                Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -name "Restart-And-Resume" -value ""
                Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -name "Restart-And-Resume" -value ((Join-Path $env:windir "System32\WindowsPowershell\v1.0\powershell.exe") +" " + $MyInvocation.MyCommand.Path + " " + $args[0])
                Restart-Computer
                exit
            }
            else
            {
                $global:RebootCount--
                Write-Host $global:RebootCount
            }
        }
    }
}

Remove-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -name "Restart-And-Resume"
log-info -info  ("Completed " + $cmdinv)
Write-Host "Completed Installation of Tools - Press enter to exit"
$null = Read-Host
ExitWithCode -exitcode 0
