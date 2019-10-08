@echo off

:: -------------------------------------------------------------------------------------------------------------
:: -------------------------------------------------------------------------------------------------------------
:: -------------------------------------------------------------------------------------------------------------
::
:: Information: Make einer WinPE-BootUSB inkl. WLAN-Treiber
::
:: Autor(en): D.Casota (DCa)
::
::
:: History:
::            10.04.2018 V1.0  DCa   Erstversion
::
:: ADK W10v1703: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
:: Surface Drivers W10v1703 : https://www.microsoft.com/en-us/download/confirmation.aspx?id=49498&6B49FDFB-8E5B-4B07-BC31-15695C5A2143=1
:: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-drivers
:: https://winpeguy.wordpress.com/2015/07/30/winpe-wireless-support-in-winre-10/
::
:: -------------------------------------------------------------------------------------------------------------
:: -------------------------------------------------------------------------------------------------------------
:: -------------------------------------------------------------------------------------------------------------


:: -------------------------------------------------------------------------------------------------------------
:: Variables
:: -------------------------------------------------------------------------------------------------------------
set _CurrentPath=%~dp0?
set _CurrentPath=%_CurrentPath:\?=%
set _thisscript=%~nx0

set _SILENT=
:: -------------------------------------------------------------------------------------------------------------


:: -------------------------------------------------------------------------------------------------------------
:: prerequisites
:: -------------------------------------------------------------------------------------------------------------
:: Installed Win10v1709 MDT
:: Win10v1709 OS (install.wim)
:: WLAN driver
:: exported WLAN.xml configuration
echo Check prerequisites ...

set WinPERoot=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment
set OSCDImgRoot=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg

set _InstallWim=X:\Repository\MDT-Share\_OS\15063.0.170317-1834.RS2_RELEASE_CLIENTENTERPRISEEVAL_OEMRET_X64FRE_DE-DE\sources\install.wim
set _DriverInf1=%_CurrentPath%\SurfacePro4_Win10_1701001_0\Drivers\Network\WiFi\mrvlpcie8897.inf
set WLANFile=%_CurrentPath%\WLAN-Config.xml


if not exist "%WinPERoot%\." call :ERROR "No directory %WinPERoot% found!"& goto end
:: -------------------------------------------------------------------------------------------------------------


:: -------------------------------------------------------------------------------------------------------------
:: mount .wim
:: -------------------------------------------------------------------------------------------------------------
set _MountDir=C:\WinPE_amd64
start "" /wait cmd.exe /c "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\copype.cmd" amd64 %_MountDir%
Dism /Mount-Image /ImageFile:"%_MountDir%\media\sources\boot.wim" /index:1 /MountDir:"%_MountDir%\mount"
:: -------------------------------------------------------------------------------------------------------------


:: -------------------------------------------------------------------------------------------------------------
:: embedded prepare customized WinRE
:: -------------------------------------------------------------------------------------------------------------
if not exist "%_MountDir%\W101709" mkdir "%_MountDir%\W101709"
if not exist "%_MountDir%\W101709WinRe" mkdir "%_MountDir%\W101709WinRe"
dism /mount-image /imagefile:"%_InstallWim%" /index:1 /Mountdir:"%_MountDir%\W101709"
Dism /Mount-Image /ImageFile:"%_MountDir%\W101709\Windows\System32\Recovery\winre.wim" /index:1 /MountDir:"%_MountDir%\W101709WinRe"
dism /image:"%_MountDir%\W101709WinRe" /get-features |find /I "WIFI"

copy /y "%WLANFile%" "%_MountDir%\W101709WinRe\Windows\System32\wlan-cfg.xml"

set _WLANFile="%_MountDir%\W101709WinRe\Windows\System32\wlan.cmd
(echo net start wlansvc)						>"%_WLANFile%"
(echo netsh wlan add profile filename=x:\windows\system32\wlan-cfg.xml)	>>"%_WLANFile%"
(echo netsh wlan connect name="FOClient Test" ssid=FOClient Test)	>>"%_WLANFile%"
(echo ping localhost -n 30 ^>nul)					>>"%_WLANFile%"

copy /y "%_MountDir%\W101709\Windows\System32\dmcmnutils.dll" "%_MountDir%\W101709WinRe\Windows\System32"
copy /y "%_MountDir%\W101709\Windows\System32\mdmregistration.dll" "%_MountDir%\W101709WinRe\Windows\System32"
copy /y "%_MountDir%\W101709\Windows\System32\mdmpostprocessevaluator.dll "%_MountDir%\W101709WinRe\Windows\System32"

Dism /Add-Driver /Image:"%_MountDir%\mount" /Driver:"%_DriverInf1%"

del /Q "%_MountDir%\W101709\Windows\System32\winpeshl.ini"

Dism /Unmount-Image /MountDir:"%_MountDir%\W101709WinRe" /commit

dir "%_MountDir%\W101709\Windows\System32\Recovery\winre.wim"
:: -------------------------------------------------------------------------------------------------------------


:: TODO www.scconfigmgr.com/2018/03/06/build-a-winpe-with-wireless-support
:: netsh wlan export profile name=YourNetwork key=clear
(echo wpeinit)			>C:\WinPE_amd64\mount\Windows\System32\startnet.cmd

Dism /Unmount-Image /MountDir:"%_MountDir%\mount" /commit
copy "%_MountDir%\media\sources\boot.wim" "%_MountDir%\media\sources\boot_old.wim"
copy /y "%_MountDir%\W101709\Windows\System32\Recovery\winre.wim" "%_MountDir%\media\sources\boot.wim"

Dism /Unmount-Image /MountDir:"%_MountDir%\W101709" /discard
:: -------------------------------------------------------------------------------------------------------------
:: Create BootUSB
:: -------------------------------------------------------------------------------------------------------------
set _TargetDrive=F
echo Legen Sie den USB-Disk ins Laufwerk %_TargetDrive%:
IF /I not "%_SILENT%"=="" pause
"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\MakeWinPEMedia.cmd" /UFD "%_MountDir%" %_TargetDrive%:

copy /y "%_CurrentPath%\%_thisscript%" %_TargetDrive%:\
Dism /Unmount-Image /MountDir:"%_MountDir%" /discard

goto end
:: -------------------------------------------------------------------------------------------------------------



:: -------------------------------------------------------------------------------------------------------------
:ERROR
:: -------------------------------------------------------------------------------------------------------------
set _Error=%*
echo ERROR: %_Error%
call :EOF
:: -------------------------------------------------------------------------------------------------------------



:end