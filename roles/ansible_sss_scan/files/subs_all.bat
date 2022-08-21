@echo on
rem Author: Martin Denn, <martin.denn@de.ibm.com>, 2009-05-14 
rem Version: 42.00
rem $Id: subs_all_tscm.bat,v 1.28 2014/11/27 13:59:08 cvsdzmitry Exp $
rem changelog: Martin Denn - 2009-05-15 - unroll for loop (8.2)
rem changelog: Martin Denn - 2009-06-16 - include phase 9 (9.00)
rem changelog: PVB         - 2009-06-23 - include splitted db scripts phase 10
rem changelog: Martin Denn - 2009-09-25 - include phase 11 (11.00)
rem changelog: Martin Denn - 2010-02-16 - include phase 12 (12.00)
rem changelog: Martin Denn - 2010-06-02 - include phase 13 (13.00)
rem changelog: Martin Denn - 2011-03-07 - include phase 14 (14.00)
rem changelog: Dzmitry Kotsikau - 2011-08-30 - include phase 15 (15.00)
rem changelog: Dzmitry Kotsikau - 2012-02-27 - include phase 16 (16.00)
rem changelog: Maksim Pitselmakhau - 2012-06-08 - include ilk, afs,  phase 17 (17.00)
rem changelog: PVB - 2012-10-25 - seperate file for TRACE for TSCM debug
rem changelog: PVB - add phase 18 (18.00)
rem changelog: PVB - add phase 19 (19.00)
rem changelog: DK - 2013-07-30 - include shp, t4d, wts,  phase 20 (20.00)
rem changelog: DK - 2013-11-20 - include isa, nco  phase 21 (21.00)
rem changelog: DK - 2013-11-20 - fixed wrong behavior when path contains spaces
rem changelog: DK - 2013-12-13 - fixed wrong behavior when path contains spaces
rem changelog: DK - 2014-02-24 - Phase 22
rem changelog: DK - 2014-04-25 - OpenSSL scanner
rem changelog: MP/DK - 2014-04-25 - Autofix
rem changelog: MP/DK - 2014-06-18 - daemons_services, Autofix update
rem changelog: MP/DK - 2014-06-19 - DEBUG_MODE fix
rem changelog: MP - 2014-07-10 - Phase 23, include aig, cft, ina, noc, tpc
rem changelog: MP - 2014-07-22 - Phase 23, include powershell ssl part
rem changelog: MP/DK - 2014-07-22 - Phase 23, update powershell ssl part
rem changelog: DK - 2014-08-30 - Phase 23, Autofix temp cleanup 
rem changelog: MP - 2014-10-30 - Phase 23, include ssl, exclude powershell ssl part
rem changelog: VM - 2015-04-03 - Phase 24, include bes and rsa
rem changelog: VM - 2018-01-12 - Phase 36, include CBS and CFS
rem changelog: Ibrahim Ismail - 2022-05-27 - Phase 42, introduced new option 'TEMP_DIR_SWITCH' which changes temp directory to SSS folder if activated

FOR /F "tokens=1,2 delims==" %%G IN ( %1 ) DO (set %%G=%%H)  
setlocal
set SSL_ENABLED=%SSL_ENABLED%
set SSL_COLD_START=%SSL_COLD_START%
set SSL_START_TLS=%SSL_START_TLS%
set SSL_TARGET_SCAN=%SSL_TARGET_SCAN%
set SSL_TARGET_SCAN_ex=%SSL_TARGET_SCAN_ex%
set SSL_REMOTE_HOSTS=%SSL_REMOTE_HOSTS%
set SSL_ENABLE_PFILES=%SSL_ENABLE_PFILES%
set SSL_ENABLE_KDB=%SSL_ENABLE_KDB%
set SSL_CONFIG_WIN=%SSL_CONFIG_WIN%
set SSL_PATH_LIST_WIN=%SSL_PATH_LIST_WIN%
set SSL_PROC_LIST_WIN=%SSL_PROC_LIST_WIN%
set SSL_LOG_ENABLED=%SSL_LOG_ENABLED%
set SUBS_CUST_ID=%SUBS_CUST_ID%
set SUBS_SYST_ID=%SUBS_SYST_ID%
set SUBS_FQDN=%SUBS_FQDN%
set SUBS_FQDN_CONFIG_WIN= %SUBS_FQDN_CONFIG_WIN_NIX%
set SUBS_SCAN_KILL_ZOMBIE=%SCAN_KILL_ZOMBIE%
set SCAN_KILL=%SCAN_KILL%
set SHS_CVE_CHECKS=%SHS_CVE_CHECKS%
set EXCLUDE_SCAN_LIST=%EXCLUDE_SCAN_LIST%
set DEBUG_MODE_CHECK=%DEBUG_MODE%
echo %DEBUG_MODE_CHECK%
IF "X%DEBUG_MODE_CHECK%" EQU "XY" ( set DEBUG_LIST=%DEBUG% ) ELSE ( set DEBUG_LIST=NO)
echo %DEBUG_LIST%
set TEMP_DIR_SWITCH=%TEMP_DIR_SWITCH%
IF "X%TEMP_DIR_SWITCH%" EQU "XY" (
set TEMP=%~dp0
)
set CLEAN_CS_TMP=N
set TEMP_NEW=%TEMP%\CS%random%S
IF NOT EXIST "%TEMP_NEW%" (
mkdir "%TEMP_NEW%" 2> NUL
set TEMP_OLD=%TEMP%
set TEMP=%TEMP_NEW%
set CLEAN_CS_TMP=Y
)
set SCRIPT_TEMP_DIR="%TEMP%\SSS%RANDOM%"
set SCRIPT_DIR="%~dp0"
set SCAN_SCRIPTS=aaa adi afs aig apa bea bes cbs cfs csf cft ctx db2 dir dom exc iis ilk ina isa it6 iws mal mqm msl myl nco noc ora osl res rsa sap sbe sbl scm sck shp smm spl ssh ssl syb t4d tem tim tiv tom tpc tpm tsm tws vce wts tdm ssk wpr ccm mxd oic ifx jbs skm
SetLocal EnableDelayedExpansion
FOR %%A in (%EXCLUDE_SCAN_LIST%) DO (
        set SCAN_SCRIPTS=!SCAN_SCRIPTS:%%A=!
	)
SetLocal DisableDelayedExpansion


set SCRIPT_RESULT="%~dp0\subs_scanner_result.txt"
set SCRIPT_TRACE="%~dp0\subs_scanner_trace.txt"

set SCRIPT_RESULT_BACKUP="%~dp0\subs_scanner_result.bk"

set SUBS_AUTOFIX_SCRIPT="%~dp0\autofix.vbs"
set SUBS_AUTOFIX_RESULT="%~dp0\subs_autofix_result.txt"
set SUBS_AUTOFIX_TRACE="%~dp0\subs_autofix_trace.txt"

IF EXIST %SCRIPT_RESULT% erase /F /Q %SCRIPT_RESULT% > NUL
IF EXIST %SCRIPT_TRACE% erase /F /Q %SCRIPT_TRACE% > NUL
IF EXIST %SUBS_AUTOFIX_RESULT% erase /F /Q %SUBS_AUTOFIX_RESULT% > NUL
IF EXIST %SUBS_AUTOFIX_TRACE% erase /F /Q %SUBS_AUTOFIX_TRACE% > NUL

setlocal
pushd %SCRIPT_DIR%

set DEBUG_MODE=FALSE
IF /I NOT "X%DEBUG_LIST%" EQU "X" (
IF /I NOT "X%DEBUG_LIST%" EQU "XNO" set DEBUG_MODE=TRUE
)

IF EXIST %SUBS_AUTOFIX_SCRIPT% cscript.exe //nologo %SUBS_AUTOFIX_SCRIPT% /random:%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%
set DEBUG_MODE=FALSE
popd
endlocal

rem create TEMP directory
IF EXIST %SCRIPT_TEMP_DIR% rmdir /S /Q %SCRIPT_TEMP_DIR%
mkdir %SCRIPT_TEMP_DIR% 2> NUL
pushd %SCRIPT_TEMP_DIR%

FOR %%A in (%SCAN_SCRIPTS%) DO (
	call:ExecScanner %%A 
	)
IF EXIST subs.zzz.log type subs.zzz.log >> %SCRIPT_RESULT%
rem cleanup
popd

setlocal

set DEBUG_MODE=FALSE
IF /I NOT "X%DEBUG_LIST%" EQU "X" (
  IF /I NOT "X%DEBUG_LIST%" EQU "XNO" set DEBUG_MODE=TRUE
)

set SCRIPT_NAME="%~dp0\daemons_services.vbs"
IF EXIST %SCRIPT_NAME% start /D %SCRIPT_TEMP_DIR%   /LOW /B /WAIT cscript //nologo  %SCRIPT_NAME% > NUL
IF %DEBUG_MODE% == TRUE (
  IF EXIST script_trace.txt type script_trace.txt >> %SCRIPT_TRACE%
  IF EXIST script_trace.txt erase /F /Q  script_trace.txt
)


copy NUL %SCRIPT_RESULT_BACKUP%

IF EXIST %SCRIPT_RESULT% type %SCRIPT_RESULT% > %SCRIPT_RESULT_BACKUP%

IF EXIST %SCRIPT_RESULT% erase /F /Q %SCRIPT_RESULT% > NUL

SetLocal EnableDelayedExpansion

set /a IsLastLineEmpty=1
for /f "usebackq tokens=*" %%x in (%SCRIPT_RESULT_BACKUP%) do (
	IF !IsLastLineEmpty! EQU 0 echo !LastLine!>> %SCRIPT_RESULT%
	set LastLine=%%x
	set /a IsLastLineEmpty=0	
)
>> %SCRIPT_RESULT% (echo | set /p ECHO_WITHOUT_LINEBREAK=%LastLine%)
SetLocal DisableDelayedExpansion

IF EXIST %SCRIPT_RESULT_BACKUP% erase /F /Q %SCRIPT_RESULT_BACKUP% > NUL


rem =======================================================
pushd %SCRIPT_TEMP_DIR%
	call:ExecScanner fqn
popd
rem =======================================================

copy NUL %SCRIPT_RESULT_BACKUP%

IF EXIST %SCRIPT_RESULT% type %SCRIPT_RESULT% > %SCRIPT_RESULT_BACKUP%

IF EXIST %SCRIPT_RESULT% erase /F /Q %SCRIPT_RESULT% > NUL

SetLocal EnableDelayedExpansion

set /a IsLastLineEmpty=1
for /f "usebackq tokens=*" %%x in (%SCRIPT_RESULT_BACKUP%) do (
	IF !IsLastLineEmpty! EQU 0 echo !LastLine!>> %SCRIPT_RESULT%
	set LastLine=%%x
	set /a IsLastLineEmpty=0	
)
>>%SCRIPT_RESULT% (echo | set /p ECHO_WITHOUT_LINEBREAK=%LastLine%)
SetLocal DisableDelayedExpansion

IF EXIST %SCRIPT_RESULT_BACKUP% erase /F /Q %SCRIPT_RESULT_BACKUP% > NUL


endlocal

rmdir /S /Q %SCRIPT_TEMP_DIR%

GOTO END
	
:ExecScanner
	setlocal
	set DEBUG_MODE=FALSE
	set ERRORLEVEL=
	echo %DEBUG_LIST% | findstr /I "ALL"   > NUL
	if %ERRORLEVEL% == 0 set DEBUG_MODE=TRUE
    
	set SCRIPT_NAME="%~dp0\subs_%~1_win.vbs"
	rem echo  RUN SCRIPT %SCRIPT_NAME% using DEBUG_MODE=%DEBUG_MODE% DEBUG_LIST=%DEBUG_LIST%
	IF EXIST %SCRIPT_NAME% start /D %SCRIPT_TEMP_DIR%  /LOW /B /WAIT cscript //nologo  %SCRIPT_NAME% > NUL
	IF EXIST subs.%~1.log type subs.%~1.log >> %SCRIPT_RESULT%
	if %DEBUG_MODE% == TRUE (
	IF EXIST script_trace.txt type script_trace.txt >> %SCRIPT_TRACE%
    )
	endlocal
	goto:eof
:END
IF "%CLEAN_CS_TMP%" EQU "Y" (
set TEMP=%TEMP_OLD%
rmdir /S /Q "%TEMP_NEW%" 
)
endlocal
