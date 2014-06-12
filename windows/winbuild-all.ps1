############################################################################
### Script to download and build necessary repos                         ###
### No arguments expected                                                ###
############################################################################

#Calling a script does not change the working directory, instead use the invocation command to create paths relative to this script
$mywd = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = ([System.IO.Directory]::GetCurrentDirectory())
. ($mywd + "\BuildSupport\winbuild-utils.ps1")

#Function to execute a git's command and log the output (Only really a function to make the script a bit neater)
function execute-git-and-log([string]$command,[string]$parameters, [string]$logfile)
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
    & $command ($parameters) | Foreach-Object {$_.ToString()} | Tee-Object (".\" + $logdir + "\" + $logfile + ".log")
}

$cmdinv = $MyInvocation.MyCommand.Name

# Do the common initialization of the global vars and setup a log file
if (!(common-init -cmdinv $cmdinv))
{
    ExitWithCode -exitcode $global:failure
}

#Need the config file to know which repos to get
$cfgfile = ($root + "\config.xml")
if (!(Test-Path -Path $cfgfile -PathType Leaf))
{
    Write-Host "ERROR: Config file not present - config:" $cfgfile
    return $false
}

#Get the git URL from config & BuildTag
$giturl = read-config-value -config $global:cfgfile -name "GitUrl"
if ($giturl.Length -lt 1)
{
    log-error -err "Failed to read GitUrl value from config"
    ExitWithCode -exitcode $global:failure
}
$tag = read-config-value -config $global:cfgfile -name "BuildTag"
$branch = read-config-value -config $global:cfgfile -name "BuildBranch"

#Setup for xml parsing
[xml]$xmlContent = [xml](Get-Content -Path $cfgfile)
[System.Xml.XmlElement]$xmlroot = $xmlContent.get_DocumentElement()
[System.Xml.XmlElement]$step = $null

# Parse the config to determine how to run the build
foreach($step in $xmlroot.Steps.ChildNodes)
{
    # Filter out comment nodes
    if ($step.name.CompareTo('#comment') -ne 0)
    {
        # Treat this step as one that needs a git clone if the config specifies it
        if ($step.clone.CompareTo('false') -ne 0)
        {
            # If a local reference repo exists, use that for the clone to speed things up
            if(Test-Path -Path ("../../reference/" + $step.name +  ".reference")){
                $gitsrc = $giturl + "/" + $step.name +  ".git"
                $gitdst = $global:builddir + "\" + $step.name
                log-info -info ("Cloning: " + $gitsrc + " To: " + $gitdst + " via reference repo")
                execute-log-and-out -command ("git clone -n --reference " + ("../../reference/" + $step.name +  ".reference") + " " + $gitsrc + " 2>&1")
            }else{
                $gitsrc = $giturl + "/" + $step.name +  ".git"
                $gitdst = $global:builddir + "\" + $step.name
                log-info -info ("Cloning: " + $gitsrc + " To: " + $gitdst)
                execute-log-and-out -command ("git clone -n " + $gitsrc + " 2>&1")
            }

            # Check everything went okay
            if($LastExitCode -ne $global:success)
            {
                log-error -err ("Failed to properly clone git repo: " + $gitsrc)
                ExitWithCode -exitcode $global:failure
            }
            
            # If a branch has been specified in the config, checkout HEAD of that branch over tag info
            if ($branch.Length -gt 0)
            {
                Push-Location -Path $step.name
                log-info -info ("Checking out: " + $branch + " For: " + $step.name)
                Invoke-Expression ("git fetch origin 2>&1") #Do checkout
                Invoke-Expression ("git checkout -q origin/$branch -b $branch 2>&1") #Do checkout
                
                #If error, just do a checkout defaulted to master
                if($?){
                    Invoke-Expression ("git checkout -q -b $branch 2>&1") #Do checkout
                }
                
                Pop-Location
            }elseif ($tag.Length -gt 0)
            {
                Push-Location -Path $step.name
                log-info -info ("Checking out: " + $tag + " For: " + $step.name)
                Invoke-Expression ("git checkout -q -b " + $tag + " " + $tag + " 2>&1") #Do checkout
                Pop-Location
            }
        }

        # Check that we want to run the command for this step (Helps reduce build tests during development)
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
                          $parameters = $parameters + $parameter + "='" + $value + "' "
                        }
                    }
                }
                
                # Now we're all done parsing this step, execute the associated command and wait for it to return
                execute-git-and-log -command $step.Run.Command -parameters ("& '" + $root + "\" + $step.Run.Path + "' " + $parameters) -logfile $step.name
                if($LastExitCode -ne $global:success)
                {
                    log-info -info ("Failed trying to execute " + $step.Run.Command + " " + ($root + "\" + $step.Run.Path)) 
                    ExitWithCode $global:failure
                }
            }
        }
    }
}

log-info -info  ("Completed " + $cmdinv)
ExitWithCode -exitcode $global:success
