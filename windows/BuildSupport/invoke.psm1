# TODO: this is pasted from xc-windows.git/do_build.ps1 but I would like to find a way
# to share code. For now if you fix a bug here please fix it in that version
# as well.

# run a command with output redirection so that we wait
# and check the error code and fail if non-zero
function Invoke-CommandChecked {
  Write-Host ("Invoke "+([string]$args))
  $description = $args[0]
  $command = $args[1]
  # doing "& *args" now would be good if it didn't take all the arguments and turn 
  # it into a string and try and run that. We need to specify the command name separately.
  # we cannot remove items from arrays
  # see http://technet.microsoft.com/en-us/library/ee692802.aspx
  # so we turn the args into an arraylist instead
  $arglist = New-Object System.Collections.ArrayList
  $arglist.AddRange($args)
  # ... then remove the first two argument
  $arglist.RemoveRange(0,2)
  Write-Host ("+$command "+[string]$arglist)
  & $command $arglist | Out-Host
  Write-Host "$command exited with code $LastExitCode"
  if ($LastExitCode -ne 0) {
      throw "failed $description; $command exited with code $LastExitCode"
  }
}

