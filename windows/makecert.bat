@ECHO OFF
if [%1]==[] goto usage

if exist %1.pfx goto exists

if exist %1.pvk del %1.pvk
if exist %1.cer del %1.cer

if defined ProgramFiles(x86) (
    set PROGRAMPATH="%ProgramFiles(x86)%"
) else (
    set PROGRAMPATH="%ProgramFiles%"
)

set Day=%date:~7,2%
set Month=%date:~4,2%
set Year=%date:~10,4%
set /a Expires=%Year%+1
set cn="cn=\"%~1\""

%PROGRAMPATH%"\Windows Kits\8.0\bin\x86\makecert" -sv %1.pvk -n %cn% %1.cer -b %Month%/%Day%/%Year% -e %Month%/%Day%/%Expires% -r
if %errorlevel% NEQ 0 goto :eof
%PROGRAMPATH%"\Windows Kits\8.0\bin\x86\PVK2PFX" -pvk %1.pvk -spc %1.cer -pfx %1.pfx
if %errorlevel% NEQ 0 goto :eof
certutil -f -user -importpfx %1.pfx

goto :eof
:usage
echo Must set certificate name
goto :eof
:exists
echo %1.pfx already exists
