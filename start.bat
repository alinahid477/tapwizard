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


set isexistsdi=
FOR /F "delims=" %%i IN ('docker images  ^| findstr /i "%name%"') DO set isexistsdi=%%i

if "%name%" == "%isexistsdi%" (
    echo "docker image name %isexistsdi% already exists. Will avoide build if not forcebuild..."
)

set dobuild=
if "%isexistsdi%" == "" (set dobuild=y)

if "%doforcebuild%" == "forcebuild" (set dobuild=y)
if "%dobuild%" == "y" (docker build . -t %name%)


set currdir=%cd%
docker run -it --rm -v %currdir%:/root/ --add-host kubernetes:127.0.0.1 --name %name% %name%
PAUSE
