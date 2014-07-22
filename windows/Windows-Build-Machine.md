This page describes how to create a build machine to build the windows components of OpenXT.

# The Making of a Build Machine

Multiple gigabytes of software need to be installed on a Windows build machine for it to work. Sometimes things can go wrong during the install. We have provided a script to help.

## Install Windows

Set up either a native install or VM. Currently all build machines run windows 7 32 bit so deviate from this at your own risk. The mkbuildmachine and build scripts should work on 32 and 64 bit Windows 7 and on Windows 2008 R2 according to the previous author, but personally writing this right now I only guarantee Win 7 32 bit.

## Before You Start
The script you need to create a build machine (bare metal or VM) are stored in https://github.com/OpenXT/openxt/tree/master/windows/mkbuildmachine.ps1. Some reboots will be necessary to install all the tools. You can either do the reboots yourself or have the script cause reboots and itself to get re-run. Consider the following before starting the process of making a build machine:<br>

### Any Machine

* The installation process should be done logged in as the Administrator or with an account that has administrative access ('''and UAC turned off'''). To turn off UAC, hit start, type UAC, select "Change User Account Control Settings" and set slider to "never notify".
* To be on the safe side, '''disable''' Power Management features like Sleep after a certain period. (A '''must''' for build-slaves)
* The C: drive should be at least '''60G''' just to handle all the tools that need to be installed.
* If you wish mkbuildmachine.ps1 to handle reboots then '''Turn off''' Automatic Windows Updates as they can cause automatic reboots of the system. Suggest selecting the option "Download but let me choose when to install".
* The system should be Activated with a valid windows licence to allow the various software packages to install and update correctly. This should have been done when you installed Windows but if you haven't this is just a reminder...
* As the setup script will cause multiple reboots it is a good idea to setup autologon for the account used to run the setup scripts. From an administrator command prompt type "control userpasswords2" select the account and uncheck "Users must enter name and password" or use SysInternals' Autologon.exe.
* Run powershell as an Administrator and enter the command "Set-ExecutionPolicy Unrestricted"
* Check the UAC is turned off
* If you wish mkbuildmachine.ps1 to handle reboots then Check that no login screen shows after reboot

### VM

* If a build machine is being installed on a OpenXT VM, it is recommended that you install the OpenXT tools. It will make the VM faster.

## Ready To Start
The script https://github.com/OpenXT/openxt/tree/master/windows/mkbuildmachine.ps1 installs all necessary software, including the .Net framework, cygwin, Visual Studio 2012 premium (unactivated and usable for 30 days) and the WDK. This uses some powershell modules in the same directory, so the easiest approach is to clone the whole repository. 

mkbuildmachine.ps1 should work well on a cleanly installed Windows machine. It has checks to avoid reinstalling software. Also in the same directory is inspectbuildmachine.ps1, which will simply run the tests and you can use to verify that the build machine is in the state that mkbuildmachine.ps1 tries to get it to. If you find the XT Windows drivers won't build on a machine which these scripts thing is ready then we should work to enhance the tests. 

Install [http://msysgit.github.io/](http://msysgit.github.io). Then use the git bash shell to git clone openxt:

    git clone https://github.com/OpenXT/openxt.git 

Now, use a administrator cmd window and from the directory you cloned openxt run:

    cd openxt\windows
    powershell .\mkbuildmachine.ps1

This will download a bunch of files and create logs in your system temp directory. Or specify the -workdir option to specifiy an alternative work directory. You'll find a log in %TEMP%\mkbuildmachine.log. It doesn't render well in Notepad (since powershell doesn't put carriage returns everywhere it might) but should be fine in most other editors.

If there are errors, deal with them (e.g. reboot) and try again.

## Further Setup

Now all the software required by the build system is installed, there is however still yet more to do. For example:

* Windows update should be run to pick up all the security updates for the newly installed build tools and Windows itself. Either do this manually or set updates to self-install again.
* Consider disabling the auto-logon.

## Certificates
To run windows builds requires the signing of drivers and executables in several places, as such you need a signing certificate. Depending what you'll be using your new build machine for, use one of the two following guides:

### Development
Being a developer, you should not have access to machines with official signing certificates installed on them - if you do you better have good reasons for why. Regardless, you still need to be able to actually create test builds for your new shiny code, meaning you first need to create a test certificate for your machine. This whole process has been scripted for you in the script [makecert.bat](https://github.com/OpenXT/openxt/blob/master/windows/mkbuildmachine/makecert.bat). So, if you cloned openxt.git earlier, run "makecert.bat <Your Certificate Name>" at an Administrator command prompt, e.g. from an administrator cmd window:

    cd openxt\windows\mkbuildmachine
    makecert developer

You will be prompted for a certificate protection password several times; do not supply a password. Select yes when asked to create private key without password protection. You will also be prompted to install the certificate and should answer yes. Note that there seems to be a problem importing the certificate if you do supply a password.

What this script actually does is simple. First it creates the bits needed to sign code, wraps them into a pfx file and then adds this file to the User's personal certificate store. To test that everything went okay either run certmgr.msc or add the certificates snap in to mmc.exe. Either example should show the newly created signing key under "Certificates (Current User) -> Personal -> Certificates".

### Official Builds

An official signing certificate and key will need to be installed on the new build machine for release signed builds. This key should be installed on production build machines only by authorised Administrators.

### NOTE: 

The signing step in the build uses the Issuer Id of the certificate to locate the cert/key in the store. This name is sometimes the same for older and newer certificates - e.g. "John Doe, Inc". This can lead to a name collision if older expired certificates have the same Issuer Id and cause signing to fail. It is recommended that you remove expired certificates first before installing a new one.

# Windows Build Process

A separate page has all the details on how to perform the windows build after the Machine has been setted up.
[Windows Build Process](Windows Build Process)