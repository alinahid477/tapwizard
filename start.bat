@ECHO OFF
echo "Unix convert start,..." 
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './converter.ps1'"
echo "Unix convert end,..."

set name=%1
set doforcebuild=%2

if "%name%" == "forcebuild" (
    set name=
    set doforcebuild="forcebuild"    
)

if "%name%" == "" (
    echo "assuming default name is: merlin-tapwizard"
    set name="merlin-tapwizard"
)


set isexists=
FOR /F "delims=" %%i IN ('docker images  ^| findstr /i "%name%"') DO set isexists=%%i

if "%name%" == "%isexists%" (
    echo "docker image name %isexists% already exists. Will avoide build if not forcebuild..."
)

set dobuild=
if "%isexists%" == "" (set dobuild=y)

if "%doforcebuild%" == "forcebuild" (set dobuild=y)
if "%dobuild%" == "y" (docker build . -t %name%)


set currdir=%cd%
docker run -it --rm -v %currdir%:/root/ --add-host kubernetes:127.0.0.1 --name %name% %name%
PAUSE
