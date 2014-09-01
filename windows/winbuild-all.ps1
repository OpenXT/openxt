############################################################################
### Script to download and build necessary repos                         ###
### No arguments expected                                                ###
############################################################################

#Calling a script does not change the working directory, instead use the invocation command to create paths relative to this script
$mywd = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = ([System.IO.Directory]::GetCurrentDirectory())
. ($mywd + "\BuildSupport\winbuild-utils.ps1")
Import-Module $mywd\BuildSupport\invoke.psm1

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

$gitbin = read-config-value -config $global:cfgfile -name "GitBin"
if ($gitbin.Length -lt 1) {
    log-error -err "Failed to read GitBin value from config"
    ExitWithCode -exitcode $global:failure
}
if (-Not (Test-Path $gitbin)) {
    log-error -err "Git binary at $gitbin not found"
    ExitWithCode -exitcode $global:failure
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
    if ($step.name.CompareTo('#comment') -eq 0) {
         Write-Host "skipping comment node"
         continue
     }
   
    # Treat this step as one that needs a git clone if the config specifies it
    if ($step.clone.CompareTo('false') -ne 0) {
         $doclone = $true
         $gitdst = $global:builddir + "\" + $step.name
         # skip the clone if it has already been done
         if (Test-Path ($step.name+"\.git")) {
             $nfiles = (Get-ChildItem $gitdst).Count
             # it is possible a failure during an earlier clone resulted in a directory,
             # possibly with a .git subdirectory, so if we see that we still need to clone
             if ([int]$nfiles -gt 1) {
                 $doclone = $false
             }
         }
    } else {
         $doclone = $false
	 Write-Host "Clone disabled for $step.name"
    }

    if ($doclone) {
       $gitsrc = $giturl + "/" + $step.name +  ".git"
       Invoke-CommandChecked "git clone $gitsrc" $gitbin clone -n $gitsrc
       
       # If a branch has been specified in the config, checkout HEAD of that branch over tag info
       if ($branch.Length -gt 0)
       {
           Push-Location -Path $step.name
           log-info -info ("Checking out: " + $branch + " For: " + $step.name)
	   Invoke-CommandChecked "git fetch origin" $gitbin fetch origin
	   & $gitbin checkout $branch | Out-Host
	   if ($LastExitCode -ne 0) {
	       Write-Host "git checkout $branch failed; using master"
	       Invoke-CommandChecked "git checkout master" $gitbin checkout master
           }            
           Pop-Location
       }elseif ($tag.Length -gt 0)
       {
           Push-Location -Path $step.name
           Write-Host ("Checking out: " + $tag + " For: " + $step.name)
	   Invoke-CommandChecked "git checkout tag" $gitbin checkout $tag
	   Pop-Location
       } else {
	   throw "Need either tag or branch"
       }

       if (!(Test-Path $gitdst)) {
           throw "$gitdst missing after clone"
       } else {
           Write-Host "$gitdst exists"
       }
   }

   # Check that we want to run the command for this step (Helps reduce build tests during development)
   if($step.Run.execute -eq $null) {
       Write-Host ("Execute not specified in "+([string]$step.Name))
       continue
   }
   if ($step.Run.execute.CompareTo("false") -eq 0)
   {
       Write-Host ("Execute set to false in "+([string]$step.Name))
       continue
   }
   # Make certain there is a command to run
   if ($step.Run.Command.Length -eq 0) { 
       Write-Host ("No command in "+[string]($step.Name))
       continue
   }		
   # Create parameters array
   $parameters = @($root + "\"+$step.Run.Path)
   if($step.Run.Parameters -ne $null) {
        foreach($param in $step.Run.Parameters.ChildNodes) {
            $parameter = $param.'#text'
            $value = read-config-value -config $cfgfile -name $parameter
            #Check parameter value is not empty
            if($value.Length -ne 0){
                 $parameters += ("'"+$parameter + "=" + $value+"'")
            }
        }
   }
           
   # Now we're all done parsing this step, execute the associated command and wait for it to return
   $command = [string] ($step.Run.command)
   $stepName = [string] ($step.Name)
   Write-Host ""
   Write-Host "-----------------------------------------------------------------"
   Write-Host ("Executing $stepName command $command with parameters $parameters at "+(Get-Date))
   Invoke-CommandChecked "Executing step $stepName" $command $parameters 
   Write-Host ""
   Write-Host "================================================================="
   Write-Host ("Execution of $stepName command $command with parameters $parameters finished at "+(Get-Date)+" code $LastExitCode")
   if($LastExitCode -ne 0) {
        throw "Failed trying to execute $stepName command " + $command + " " + ($root + "\" + $step.Run.Path) + " code $LastExitCode"
   }
}

log-info -info  ("Completed " + $cmdinv)
ExitWithCode -exitcode $global:success
