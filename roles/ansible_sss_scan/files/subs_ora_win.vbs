'***********************************************************************************************
'$Id: subs_ora_win.vbs,v 1.54 2015/02/17 13:46:12 cvsmaksim Exp $
'***********************************************************************************************
'* The script detects if Oracle database is installed and running and creates one line in log 
'* and MIF files for each database found.
'***********************************************************************************************
'* Debug scan:
'*  set debug_mode=true 
'*  cscript /nologo subs_ora_win.vbs 
'* or this command
'*  cmd /c set debug_mode=true&&cscript /nologo subs_ora_win.vbs 
'* 
'* As a result the script creates script_trace.txt with debug info. The second line
'* in the file is CVS Id.
'***********************************************************************************************
'* <Version> - <Date>     - <Author>              - <Changes>
'* <0.0.1> - <14.04.2009> - <Maksim Pitselmakhau> -
'*                          <Pillas G.>           
'*                          <Sergey Cozhemyakin>  
'*                          <Patrick van Benthem>  
'* <0.0.2> - <22.04.2009> - <MP>                  - <test version for different version of oracle(8 and 7)>
'* <8.0.3> - <29.04.2009> - <PB>                  - <WshEnv("ORACLE_HOME") = strPathEnv>
'*                                                  <WshEnv("PATH") = strPathEnv & "\bin" & ";" & WshEnv("PATH")>
'* <8.0.4> - <05.05.2009> - <MP>                  - <new template>
'* <8.0.5> - <13.05.2009> - <MP>                  - <UpdateOldEvironment sub was added>
'* <8.0.6> - <14.05.2009> - <PB/MP>               - <DM was Added>
'* <8.0.7> - <25.05.2009> - <PB/MP>               - <Changed svrmgrl / sqlplus based on versionnumber>
'* <9.0.1> - <26.05.2009> - <PB/MP>               - <Update run of DM part>
'* <9.0.2> - <26.05.2009> - <PB/MP>               - <Added Err.clear>
'* <9.03>  - <01.06.2009> - <MP>                  - <check WScript and Windows versions, env.file and path to instance in log>
'* <9.04>  - <05.06.2009> - <MP>                  - <updated CheckConditions sub>
'* <9.05>  - <10.06.2009> - <MP>                  - <update of mif file>
'* <10.01> - <24.06.2009> - <MP>                  - <update from subscan_inventory_oracle to subscan_inventory_ora>
'* <10.02> - <24.06.2009> - <PB>                  - <create Empty/MIF changed to ORA>
'* <10.03> - <02.07.2009> - <PB/MP>               - <strFIXPACK = Mid(strFIXPACK, 4, 3) & Mid(strFIXPACK, 9, 2)>
'* <10.04> - <10.07.2009> - <MP/Dzmitry Kotsikau> - <Class CVersionInfo>
'* <10.05> - <27.07.2009> - <PvB/MP>              - <strFIXPACK update>
'* <11.00> - <21.08.2009> - <DK>                  - <Updated: Implemented requirement [#122655] TRACE Capability ON/OFF> 
'* <11.01> - <02.09.2009> - <MP>                  - <Updated: Implemented requirement [#109928] add SCANNER_VERSION to log and mif
'*                                                   Implemented requirement [#122565] add MW_VERSION="O.S. Not supported">
'* <11.02> - <07.09.2009> - <MP>                  - <strSERVER_TYPE = "WINDOWS" added to CreateEmptyLogIfNotExist and CreateLogIfOSNotSupported>
'* <12.00> - <10.02.2010> - <DK>                  - <Updated: New approach to get hosthame
'*                                                   Updated: New template>
'* <13.00> - <15.03.2010> - <MP>                  - <use strFind>
'* <13.01> - <01.04.2010> - <MP>                  - <INSTANCE_PORT update - "\find.exe">
'* <13.02> - <08.04.2010> - <MP>                  - <GetInstPortOracle update>
'* <14.00> - <30.11.2010> - <DK>                  - <CVS Id in the trace file>
'* <14.01> - <06.12.2010> - <MP>                  - <if Port is not Integer that INSTANCE_PORT = "">
'* <14.02> - <07.12.2010> - <MP>                  - <use uppercase for "NOT FOUND">
'* <15.00> - <14.05.2011> - <DK>                  - <Implemented: [#119004] Length control
'*         - <03.06.2011> - <MP>                     Implemented: [#122029] Directory Structure - "%TEMP%\cscans\ora\" instead "c:\tmp\cscans\db\datamining\win\"
'*         - <09.06.2011> - <MP>                     Implemented: [#164933] Scanners with blanks in MW_edition, MW_version; DEFAULT_VERSION = "0.0.0" and DEFAULT_EDITION = "UNKNOWN"
'*         - <16.09.2011> - <MP>                     SAP info updated>
'* <16.00> - <31.01.2012> - <MP>                  - <PHASE 16>
'* <17.00> - <25.05.2012> - <MP>                  - <PHASE 17, CreateOrUpdateEnvFileAndGetValue update>
'* <18.00> - <12.10.2012> - <MP>                  - <PHASE 18, delete CreateOrUpdateEnvFileAndGetValue sub, add GetHostNameTCP sub>
'* <19.00> - <19.02.2013> - <MP>                  - <PHASE 19>
'* <20.00> - <17.06.2013> - <MP>                  - <PHASE 20, Updated GetNewSys_id function - requirement [#63918] any.any.MWInventoryV1 collector failes to get SYST_ID, added ExtractData function>
'* <20.01> - <04.07.2013> - <MP>                  - <Added: extraction of port from listener.ora file; extraction of version from "lsnrctl version" command; extraction of edition from dll file
'*                                                   Implemented: [#39107] SAP instance naming - CI // split up the instance having SAP_INSTALLED=Y in 2 instances, the first one is ORA instance and the second one is SAP instance>
'* <20.02> - <16.07.2013> - <MP>                  - <updated GetInstPortOracleFromListenerOra function>
'* <20.03> - <22.07.2013> - <MP>                  - <added separate SAP instance>
'* <20.04> - <24.07.2013> - <MP>                  - <updated SAP instance>
'* <21.00> - <24.07.2013> - <MP>                  - <PHASE 20, implemented export SAP instances to SAP scan
'*         - <15.11.2013> - <MP>                     Implemented: [#88542] incorrect output and unnecessary instances because of WMI issue>
'* <22.00> - <12.02.2014> - <MP>                  - <PHASE 22>
'* <22.01> - <28.02.2014> - <MP>                  - <in SAP instance swap SUBSYSTEM_INSTANCE and DB_NAME>
'* <22.02> - <18.06.2014> - <MP>                  - <Implemented: [103121] Change and improvement all scanners scripts, autofix.vbs, daemons_services.vbs and bat files, update of all scanners>
'* <22.03> - <25.06.2014> - <MP>                  - <deleted getVersion function, CVersionInfo and VSInfo classes, added GetFileProperties function>
'* <23.00> - <10.07.2014> - <MP>                  - <PHASE 23>
'* <24.00> - <24.02.2015> - <MP>                  - <PHASE 24>
'* 24.01 - 22.04.2015 - Dzmitry Kotsikau - #110938: Function get_hostname fails on comparison of value retrieved from WMI and from registry
'* <31.00> - <24.03.2017> - <Dzmitry Kochurau>    - <Added support of detailed version number of the Oracle server when PSU and DBBP patches applying>
'* <32.00> - <07.04.2017> - <Dzmitry Kochurau>    - <Added support of the 12c Oracle Database>
'* <32.02> - <26.04.2017> - <Dzmitry Kochurau>    - <Added support of automatic detection of Oracle Instances in case of Multi-tenant architecture (pluggable databases)> 
'***********************************************************************************************
'_______________________________________________________________________________________________
'                                  Required variables declarations          
'_______________________________________________________________________________________________
Option Explicit

Const Version = "42.00"

Const DEFAULT_VERSION = "0.0.0"
Const DEFAULT_EDITION = "UNKNOWN"

Dim DEBUG_MODE

Const HKLM = &h80000002	
Dim NotSupported	
Const OS_NotSupported = "O.S. Not supported"
Const VB_NotSupported = "VBScript version not supported"
Const WMI_NotSupported = "Operating System WMI issues"

'Const SZ_COMPUTER_SYS_ID    =
Const SZ_CUST_ID            = 12
Const SZ_SYST_ID            = 8
Const SZ_HOSTNAME           = 64
Const SZ_SUBSYSTEM_INSTANCE = 128
Const SZ_SUBSYSTEM_TYPE     = 16
Const SZ_MW_VERSION         = 16
Const SZ_MW_EDITION         = 64
Const SZ_FIXPACK            = 80
Const SZ_INSTANCE_PATH      = 254
Const SZ_DB_NAME            = 64
'Const SZ_SCAN_TIME          =
Const SZ_SAP_INSTALLED      = 2
Const SZ_SAP_CVERS          = 64
Const SZ_OS_VERSION         = 40
Const SZ_INSTANCE_PORT      = 64
Const SZ_NB_TABLES          = 16
Const SZ_NB_INDEXES         = 16
Const SZ_ALLOC_DB           = 16
Const SZ_USED_DB            = 16
Const SZ_ALLOC_LOG          = 16
Const SZ_USED_LOG           = 16
Const SZ_DB_PART            = 16
Const SZ_TABLE_PART         = 16
Const SZ_INDEX_PART         = 16
Const SZ_SERVER_TYPE        = 16
Const SZ_DB_TYPE            = 16
Const SZ_DBMS_TYPE          = 16
Const SZ_SDC                = 16
Const SZ_DB_USAGE           = 16
Const SZ_SVC_OFFERED        = 16
Const SZ_HC_REQUIRED        = 24
Const SZ_MW_INST_ID         = 24
Const SZ_MW_MODULE          = 16
Const SZ_MW_NB_EAR          = 256
Const SZ_MW_NB_USERS        = 16
Const SZ_MW_NB_MNDTS        = 16
Const SZ_SW_BUNDLE          = 16
Const SZ_SCANNER_VERSION    = 16

Dim strCOMPUTER_SYS_ID
Dim strCUST_ID
Dim strSYST_ID
Dim strHOSTNAME
Dim strSUBSYSTEM_INSTANCE
Dim strSUBSYSTEM_TYPE
Dim strMW_VERSION
Dim strMW_EDITION
Dim strFIXPACK
Dim strINSTANCE_PATH
Dim strDB_NAME
Dim strSCAN_TIME
Dim strSAP_INSTALLED
Dim strSAP_CVERS
Dim strOS_VERSION
Dim strINSTANCE_PORT
Dim strNB_TABLES
Dim strNB_INDEXES
Dim strALLOC_DB
Dim strUSED_DB
Dim strALLOC_LOG
Dim strUSED_LOG
Dim strDB_PART
Dim strTABLE_PART
Dim strINDEX_PART
Dim strSERVER_TYPE
Dim strDB_TYPE
Dim strDBMS_TYPE
Dim strSDC
Dim strDB_USAGE
Dim strSVC_OFFERED
Dim strHC_REQUIRED
Dim strMW_INST_ID
Dim strMW_MODULE
Dim strMW_NB_EAR
Dim strMW_NB_USERS
Dim strMW_NB_MNDTS
Dim strSW_BUNDLE
Dim strSCANNER_VERSION

Dim strDetailedVersion
Dim strIS_CDB
Dim strPDB_LIST

Dim strNewSys_id, strNewCompSys_id, strWindowsVersion, fso

'_______________________________________________________________________________________________
'                         SCANNING ROUTINES. PLACE YOUR CODE HERE
'_______________________________________________________________________________________________

'***********************************************************************************************
'* Main ORACLE Subscan procedure
'***********************************************************************************************

Sub SubscanOracle
    DiscoverOracleInstances        ' and Collect Instances Info
End Sub

'***********************************************************************************************
'* Look for Oracle instance
'***********************************************************************************************

Sub DiscoverOracleInstances
    
    Dim strComputer, iCnt, counter, strPathEnv, strCmd, strCmd2, SrtError, strLine, str, i, strMW_VERSION1, strMW_VERSION2, strINST_PORT
    Dim objWMIService, colItems, objItem, WshShell, WshEnv, oExec, tabInfo, fdescLog, fdesc1, RunVal
    Dim strMW, strPathLSNRCTL, strResult, arrLine, Line, strFind, strBasicVerson, re, objMatch
    Dim fdescSAPLog, SwapStr
    
    strComputer = "."
    On Error Resume Next
    Trace("*********Starting DiscoverOracleInstances*********")
    Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2")
    Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Service",,48)
    iCnt = 0
    counter = 0
    
    For Each objItem In colItems
        counter = counter + 1
        Trace("N" & counter & "   objItem =      " & objItem.name & "     -->    " & objitem.PathName)
        If (InStr(LCase(LTrim(RTrim(objitem.name))),"oracleservice") > 0) And (LCase(objitem.state)="running" ) And (InStr(LCase(objitem.PathName),"oracle.exe") > 0) Then
            
            SetBlankValues
            Set WshShell = CreateObject("Wscript.Shell")
            CreateDM_Oracle WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\")
            Trace("lcase(ltrim(rtrim(objitem.name)))= " & LCase(LTrim(RTrim(objitem.name))))
            strSUBSYSTEM_INSTANCE = Trim(Right(objitem.name, Len(objitem.name) - 13))
            
            Set WshEnv = WshShell.Environment("PROCESS")
            WshEnv("ORACLE_SID") = strSUBSYSTEM_INSTANCE
            
            Trace("strSUBSYSTEM_INSTANCE = " & strSUBSYSTEM_INSTANCE)
            Trace("objitem.PathName = " & objitem.PathName)
            strPathEnv = Left(objitem.PathName, InStr(objitem.PathName,"\bin"))
            
            WshEnv("ORACLE_HOME") = strPathEnv
            WshEnv("PATH") = strPathEnv & "bin" & ";" & WshEnv("PATH")
            
            Trace("strPathEnv = " & strPathEnv)
            Trace("PATH="         & WshEnv("PATH"))
            Trace("ORACLE_HOME="  & WshEnv("ORACLE_HOME"))
            Trace("ORACLE_SID="   & WshEnv("ORACLE_SID"))
            
            
            strFind = WshShell.ExpandEnvironmentStrings("%windir%\system32\find.exe")
            
            If fso.FileExists(strPathEnv & "bin\svrmgrl.exe") Then
                strCmd ="cmd.exe /c @echo  exit  | svrmgrl | " & strFind & "  /V /I ""Server Manager"" "
                strCmd2 =""
            Else
                'Assume if not svrmgrl to use sqlplus
                strCmd ="cmd.exe /c @echo select * from v$version;  | sqlplus -s ""/ as sysdba"""
                strCmd2 ="cmd.exe /c @echo select DBID from v$database; | sqlplus -s ""/ as sysdba"
            End If
            Trace("strCmd= " & strCmd)
            Trace("strCmd2= " & strCmd2)
            
            Err.Clear
            
            Set oExec = WshShell.Exec(strCmd)
            If Err.number <> 0 Then 
                SrtError = Err.number
                Trace("error: " & CStr(Err.number ) & CStr(Err.Description))
                Err.Clear
            Else
                Do While Not oExec.stdout.AtEndOfStream
                    strLine=oExec.stdOut.ReadLine
                    Trace("strLine= " & strLine)
                    If InStr(UCase(strLine),"ORACLE") > 0 And InStr(UCase(strLine),"PL/SQL") = 0 And InStr(UCase(strLine),"CORE") = 0 And InStr(UCase(strLine),"TNS") = 0 And InStr(UCase(strLine),"NLSRTL") = 0 Then
                        Trace("strLine = " & strLine)
                        strMW = Trim(Left(strLine,InStr(strLine," - ") - 1 )) 
                        Trace("strMW         = " & strMW)
                        strMW_EDITION = Trim(Left(strMW, InStr(strMW,"Release") - 2))
                        Trace("strMW_EDITION = " & strMW_EDITION)
                        Trace("strMW         = " & strMW)
                        strMW_VERSION = Trim(Mid(strMW, InStr(strMW,"Release") + 8))
                        Trace("strMW_VERSION = " & strMW_VERSION)
                    End If
                Loop
            End If

            If strCmd2 <> "" Then
                Set oExec = WshShell.Exec(strCmd2)
                If Err.number <> 0 Then 
                    SrtError = Err.number
                    Trace("error: " & CStr(Err.number ) & CStr(Err.Description))
                    Err.Clear
                Else
                    Do While Not oExec.stdout.AtEndOfStream
                        strLine=oExec.stdOut.ReadLine
                        Trace("strLine= " & strLine)
                        strLine = Trim(strLine)
                        If strLine <> "" Then 
                            strDB_PART = strLine
                        End If
                    Loop
                End If
            End If
            
            If strMW_VERSION = "" Then
                strMW_VERSION = GetFileProperties(Left(objItem.PathName, InStr(objItem.PathName, " ")), "File Version")
                strMW_EDITION = DEFAULT_EDITION
                Trace("-------------------------------------------------")
                Trace("version = " & strMW_VERSION)
                
                strMW_VERSION = Left(strMW_VERSION, InStr(strMW_VERSION, " ") - 1)
                
                Trace("strMW_VERSION = " & strMW_VERSION)
                Trace("strMW_EDITION = " & strMW_EDITION)
                Trace("-------------------------------------------------")
            End If
            
            Set fdescLog = fso.OpenTextFile("subs.ora.log", 8, True)
            
            Set oExec = Nothing
            
            strSERVER_TYPE = "WINDOWS"
            strDBMS_TYPE = "ORACLE"
            If strNewSys_id <> "Sys_id not found" Then strSYST_ID = strNewSys_id 
            If strNewCompSys_id <> "Computer_Sys_id not found" Then strCOMPUTER_SYS_ID = strNewCompSys_id
            strSW_BUNDLE = "N"
            
            If SrtError = 0 Then
                strMW_VERSION1 = CInt(Left(strMW_VERSION, InStr(strMW_VERSION, ".") - 1))
                strMW_VERSION2 = CInt(Left(Mid(strMW_VERSION, InStr(strMW_VERSION, ".") + 1), InStr(Mid(strMW_VERSION, InStr(strMW_VERSION, ".") + 1), ".") - 1))
                Set fdesc1 = fso.OpenTextFile(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\dm.bat"), 2, True)
                fdesc1.WriteLine("setlocal")
                fdesc1.WriteLine("set PATH=" & strPathEnv & "bin" & ";" & "%PATH%")
                fdesc1.WriteLine("set ORACLE_HOME=" & strPathEnv)
                fdesc1.WriteLine("set ORACLE_SID=" & strSUBSYSTEM_INSTANCE)
                If ((10 * strMW_VERSION1) + strMW_VERSION2) < 80 Then
                    Trace("run svrmgrl.exe")
                    fdesc1.WriteLine(strPathEnv & "bin\svrmgrl.exe < " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\get_oracle8min.sql")) & " > " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt")))
                Else
                    Trace("run sqlplus.exe")
                    If ((10 * strMW_VERSION1) + strMW_VERSION2) < 120 Then
                        fdesc1.WriteLine(strPathEnv & "bin\sqlplus.exe /nolog < " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\get_oracle8pls.sql")) & " > " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt")))
                    Else
                        Trace("=== v12c ===")
                        fdesc1.WriteLine(strPathEnv & "bin\sqlplus.exe /nolog < " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\get_oracle12pls.sql")) & " > " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt")))
                    End If
                End If
                fdesc1.WriteLine("endlocal")
                fdesc1.Close()
            End If
            RunVal = WshShell.Run(QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\dm.bat")),0,True)
            Trace("DM - OK")
            
            strSUBSYSTEM_TYPE = "ORA"
            strINSTANCE_PATH  = strPathEnv & "bin\"
            strDB_NAME        = strSUBSYSTEM_INSTANCE
            
            '===========================================
            strDetailedVersion = ""
            strIS_CDB = ""
            strPDB_LIST = ""
            GetDMParameters		'!!!
            '===========================================
            
            If strMW_VERSION = "" Then
                Trace "run " & strINSTANCE_PATH & "lsnrctl version"
                strPathLSNRCTL = strINSTANCE_PATH & "lsnrctl"
                strResult = ""
                If strPath <> "" Then
                    Trace "cmd /c " & QuotedPath(strPathLSNRCTL) & " version"
                    strResult = RunShellCommand("cmd /c " & QuotedPath(strPathLSNRCTL) & " version")
                    
                    arrLine = Split(strResult & vbCrLf, vbCrLf)
                    For Each Line In arrLine
                        If InStr(Line, "Windows: Version") > 0 And strMW_VERSION = "" Then
                            Trace "Line = " & Line
                            strMW_VERSION = Mid(Line, InStr(Line, "Windows: Version") + 17, InStr(InStr(Line, "Windows: Version") + 17, Line, "-") - InStr(Line, "Windows: Version") - 18 )
                            Trace "strMW_VERSION= " & strMW_VERSION
                        End If
                    Next
                    Trace ""
                End If
            End If
            
            '-----------------------------------------------------------------------------
            Trace "strMW_VERSION: " & strMW_VERSION
            Trace "Detailed version: " & strDetailedVersion
            If strDetailedVersion<>"" Then
                If Len(strMW_VERSION)<=Len(strDetailedVersion)Then strMW_VERSION = strDetailedVersion
            End If
            '-----------------------------------------------------------------------------
            
            strINST_PORT = ""
            strINST_PORT = GetInstPortOracleFromListenerOra(strSUBSYSTEM_INSTANCE, strPathEnv)
            If strINST_PORT = "" Then strINSTANCE_PORT = GetInstPortOracle(strSUBSYSTEM_INSTANCE, strPathEnv)
            If IsNumeric(strINST_PORT) Then strINSTANCE_PORT = CInt(strINST_PORT)
            
            'Read edition from dll file
            If (strMW_EDITION = "" Or strMW_EDITION = DEFAULT_EDITION) And InStr(strMW_VERSION, ".") > 0 Then
                strBasicVerson = Trim(Left(strMW_VERSION, InStr(strMW_VERSION, ".") - 1))
                If strBasicVerson <> "" Then
                    If IsNumeric(strBasicVerson) Then
                        strMW_EDITION = GetStringEdition(strPathEnv & "bin\oravsn" & strBasicVerson & ".dll", DEFAULT_EDITION)
                    End If
                End If
            End If
            
            '-----------------------------------------------------------------------------
            Trace "strIS_CDB: " & strIS_CDB
            Trace "strPDB_LIST: " & strPDB_LIST
            
            If UCase(strIS_CDB)="YES" Then 
                Dim strSID
                strSID = strSUBSYSTEM_INSTANCE
                strSUBSYSTEM_INSTANCE=strSID&":CDB$ROOT"
                strDB_NAME=strSUBSYSTEM_INSTANCE
                fdescLog.WriteLine(WriteEntryToLog)
                
                'create pdb.bat file
                Set fdesc1 = fso.OpenTextFile(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\pdb.bat"), 2, True)
                fdesc1.WriteLine("setlocal")
                fdesc1.WriteLine("set PATH=" & strPathEnv & "bin" & ";" & "%PATH%")
                fdesc1.WriteLine("set ORACLE_HOME=" & strPathEnv)
                fdesc1.WriteLine("set ORACLE_SID=" & strSID)
                fdesc1.WriteLine(strPathEnv & "bin\sqlplus.exe /nolog < " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\get_oracle_pdb.sql")) & " > " & QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt")))
                fdesc1.WriteLine("endlocal")
                fdesc1.Close()
                
                Dim strPDB
                strPDB = Split (strPDB_LIST, " ")
                For Each Line In strPDB
                    Trace vbCrLf & "PDB Name = " & Line
                    '*********************************************
                    strSUBSYSTEM_INSTANCE=strSID & ":" & Line
                    strDB_NAME=strSUBSYSTEM_INSTANCE
                    
                    CreateDM_Oracle_PDB WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\"), Line	'create new get_oracle_pdb.sql file !!!
                    
                    RunVal = WshShell.Run(QuotedPath(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\pdb.bat")),0,True)	'run pdb.bat !!!
                    Trace("PDB - OK")
                    
                    GetDMParameters		'!!!
                    '-----------------------------------------------------------------------------
                    Trace "strMW_VERSION: " & strMW_VERSION
                    Trace "Detailed version: " & strDetailedVersion
                    If strDetailedVersion<>"" Then
                        If Len(strMW_VERSION)<=Len(strDetailedVersion)Then strMW_VERSION = strDetailedVersion
                    End If
                    '-----------------------------------------------------------------------------
                    
                    fdescLog.WriteLine(WriteEntryToLog)
                    '*********************************************
                Next
            Else    
                fdescLog.WriteLine(WriteEntryToLog)
            End If
            '-----------------------------------------------------------------------------
            
            If strSAP_INSTALLED = "Y" Then
                'fdescLog.WriteLine(WriteEntryToLog)
                
                Set fdescSAPLog = fso.OpenTextFile("importORAtoSAP.tmp", 2, True)
                
                SwapStr = strSUBSYSTEM_INSTANCE
                strSUBSYSTEM_INSTANCE = strDB_NAME
                strDB_NAME = SwapStr
                
                strSUBSYSTEM_TYPE = "SAP"
                strDBMS_TYPE = ""
                strMW_VERSION = DEFAULT_VERSION
                strMW_EDITION = "DB"
                
                strFIXPACK = ""
                strNB_TABLES = ""
                strNB_INDEXES = ""
                strALLOC_DB = ""
                strUSED_DB = ""
                strALLOC_LOG = ""
                strUSED_LOG = ""
                strTABLE_PART = ""
                strINDEX_PART = ""
                strDB_PART = ""
                
                fdescSAPLog.WriteLine(WriteEntryToLog)
                fdescSAPLog.Close()
                Set fdescSAPLog = Nothing
                
                strDB_NAME = strSUBSYSTEM_INSTANCE
                strSUBSYSTEM_INSTANCE = SwapStr
                'Else
                'fdescLog.WriteLine(WriteEntryToLog)
            End If
            
            fdescLog.Close()
            Set fdescLog = Nothing
            iCnt = iCnt + 1
        End If
    Next
    
    Trace("iCnt = " & iCnt)
    If iCnt = 0 Then
        Trace("the output is empty")
    End If
    
    Set colItems = Nothing
    Set objWMIService = Nothing
    Trace("*********End DiscoverOracleInstances*********")
    
End Sub


Sub GetDMParameters
    
    Dim WshShell, fdesc1, str
    
    On Error Resume Next
    
    Err.Clear
    
    
    Set WshShell = CreateObject("Wscript.Shell")
    If fso.FileExists(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt")) Then
        Set fdesc1 = fso.OpenTextFile(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt"), 1, False)
        Do While fdesc1.AtEndOfStream <> True
            
            str = fdesc1.ReadLine
            If Err.number <> 0 Then
                Trace("reading of tmp_sql_out.txt Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                Exit Do
            End If
            
            Trace("str = " & str)
            
            If InStr(str, "FIXPACK=") > 0 Then
                str = Replace(str, "FIXPACK=", "")
                '--------------------------------------------------------------------------
                'PSU 11.2.0.4.161018
                If InStr(str, "PSU") = 1 Then 
                    strDetailedVersion = Trim(Replace(str, "PSU", ""))
                End If
                'WinBundle 11.2.0.4.20
                If InStr(str, "WinBundle") = 1 Then 
                    strDetailedVersion = Trim(Replace(str, "WinBundle", ""))
                End If
                'DBP: 12.1.0.2.161018
                If InStr(str, "DBP:") = 1 Then 
                    strDetailedVersion = Trim(Replace(str, "DBP:", ""))
                End If
                '--------------------------------------------------------------------------
                If InStr(str, "CPU") = 1 Then 
                    strFIXPACK = Mid(str, 4, 3) & Mid(str, 9, 2)
                End If
                If InStr(strFIXPACK, "PATCH") = 1 Then 
                    strFIXPACK = Replace(str, "PATCH", "P")
                End If
            End If
            
            If InStr(str, "SAP_INSTALLED=") > 0 Then
                strSAP_INSTALLED = Replace(str, "SAP_INSTALLED=", "")
            End If
            
            If InStr(str, "SAP_CVERS=") > 0 Then
                strSAP_CVERS = Replace(str, "SAP_CVERS=", "")
            End If
            
            If InStr(str, "MW_NB_USERS=") > 0 Then
                strMW_NB_USERS = Replace(str, "MW_NB_USERS=", "")
            End If
            
            If InStr(str, "MW_NB_MNDTS=") > 0 Then
                strMW_NB_MNDTS = Replace(str, "MW_NB_MNDTS=", "")
            End If
            
            If InStr(str, "NB_TABLES=") > 0 Then
                strNB_TABLES = Replace(str, "NB_TABLES=", "")
            End If
            
            If InStr(str, "NB_INDEXES=") > 0 Then
                strNB_INDEXES = Replace(str, "NB_INDEXES=", "")
            End If
            
            If InStr(str, "ALLOC_DB=") > 0 Then
                strALLOC_DB = Replace(str, "ALLOC_DB=", "")
            End If
            
            If InStr(str, "USED_DB=") > 0 Then
                strUSED_DB = Replace(str, "USED_DB=", "")
            End If
            
            If InStr(str, "ALLOC_LOG=") > 0 Then
                strALLOC_LOG = Replace(str, "ALLOC_LOG=", "")
            End If
            
            If InStr(str, "USED_LOG=") > 0 Then
                strUSED_LOG = Replace(str, "USED_LOG=", "")
            End If
            If InStr(str, "MW_NB_EAR=") > 0 Then
                strMW_NB_EAR = Replace(str, "MW_NB_EAR=", "")
            End If
            If InStr(str, "DB_PART=") > 0 Then
                strDB_PART = Replace(str, "DB_PART=", "")
            End If
            
            If InStr(str, "TABLE_PART=") > 0 Then
                strTABLE_PART = Replace(str, "TABLE_PART=", "")
            End If
            
            If InStr(str, "INDEX_PART=") > 0 Then
                strINDEX_PART = Replace(str, "INDEX_PART=", "")
            End If
            '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
            If InStr(str, "IS_CDB=") > 0 Then
                strIS_CDB = Replace(str, "IS_CDB=", "")
            End If
            If InStr(str, "PDB_LIST=") > 0 Then
                strPDB_LIST = Replace(str, "PDB_LIST=", "")
            End If
            '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        Loop
        
        If strSAP_INSTALLED <> "Y" Then
            strSAP_CVERS   = ""
            strMW_NB_USERS = ""
            strMW_NB_MNDTS = ""
        End If
        
        fdesc1.Close()
        Set fdesc1 = Nothing
    Else
        Trace("unfortunatelly " & WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\tmp_sql_out.txt") & " is not exist")
    End If
    
End Sub


'***********************************************************************************************
'* Create Oracle DataMining files
'***********************************************************************************************

Function CreateDM_Oracle(ByRef DMPathString)
    
    Dim a(223)
    Dim fdesc, i
    
    a(1)   = "connect internal"
    a(2)   = "set serveroutput on;"
    a(3)   = "set termout on"
    a(4)   = ""
    a(5)   = "DECLARE"
    a(6)   = "    stmt_text         varchar2(2000);"
    a(7)   = "    stmt_result       number;"
    a(8)   = ""
    a(9)   = "    ora_host          varchar2(64);"
    a(10)  = "    ora_name          varchar2(64);"
    a(11)  = "    ora_version       varchar2(64);"
    a(12)  = "    ora_edition       varchar2(200);"
    a(13)  = "    ora_fixpack       varchar2(30);"
    a(14)  = ""
    a(15)  = "    sap_owner         varchar2(30);"
    a(16)  = "    sap_ins           varchar2(5);"
    a(17)  = "    sap_ver           varchar2(40);"
    a(18)  = "    sap_nbr           number;"
    a(19)  = "    sap_mndt          number;"
    a(20)  = "    sap_cnt           number;"
    a(21)  = "    sap_dt_applied    varchar2(64);"
    a(22)  = "    sap_patch_applied varchar2(64);"
    a(23)  = ""
    a(24)  = "    dmi_tables           number;"
    a(25)  = "    dmi_indexes          number;"
    a(26)  = "    dmi_table_partitions number;"
    a(27)  = "    dmi_index_partitions number;"
    a(28)  = "    dmi_MB_data_files    number;"
    a(29)  = "    dmi_MB_used          number;"
    a(30)  = "    dmi_MB_log_space     number;"
    a(31)  = "    dmi_MB_dic_tempfiles number;"
    a(32)  = "    dmi_MB_undo_files    number;"
    a(33)  = "    dmi_MB_undo_segments number;"
    a(34)  = "    dmi_MB_allocated     number;"
    a(35)  = "    ora_dbid             number; ora_db_owner     varchar2(64);"
    a(36)  = ""
    a(37)  = "BEGIN"
    a(38)  = "---"
    a(39)  = "--- Basic information"
    a(40)  = "---"
    a(41)  = "    select name,DBID into ora_name,ora_dbid "
    a(42)  = "           from v$database;select username into ora_db_owner from v$process where program like '%PMON%';"
    a(43)  = ""
    a(44)  = "    select banner "
    a(45)  = "           into ora_edition"
    a(46)  = "           from v$version"
    a(47)  = "           where banner like 'Oracle%';"
    a(48)  = "---"
    a(49)  = "--- FIXPACK does not exist in 7.3 and 8.0 "
    a(50)  = "---"
    a(51)  = "    ora_fixpack := '';"
    a(52)  = "--- "
    a(53)  = "--- PRINT ORA Basic information"
    a(54)  = "---"
    a(55)  = ""
    a(56)  = "    dbms_output.put_line('HOSTNAME='||ora_host);dbms_output.put_line('DB_PART='||ora_dbid);dbms_output.put_line('MW_NB_EAR='||ora_db_owner);"
    a(57)  = "    dbms_output.put_line('SUBSYSTEM_INSTANCE='||ora_name); "
    a(58)  = "    dbms_output.put_line('MW_VERSION='||ora_version);"
    a(59)  = "    dbms_output.put_line('MW_EDITION='||ora_edition);"
    a(60)  = "    dbms_output.put_line('FIXPACK='||ora_fixpack);"
    a(61)  = "---"
    a(62)  = "--- SAP"
    a(63)  = "---"
    a(64)  = ""
    a(65)  = "    sap_ins := 'N';"
    a(66)  = "    sap_ver := '';"
    a(67)  = "    sap_nbr := 0;"
    a(68)  = "    sap_mndt := 0;"
    a(69)  = "    select count(*) into sap_cnt from dba_objects where object_name='CVERS_TXT';"
    a(70)  = "    if sap_cnt > 0 then"
    a(71)  = "       sap_ins := 'Y';"
    a(72)  = "---"
    a(73)  = "---    NEEDS TO BE REWRITTEN IF NEEDED."
    a(74)  = "---"
    a(75)  = "---    select owner into sap_owner from dba_objects where object_name='CVERS_TXT';"
    a(76)  = "---    stmt_text := 'select STEXT from '||sap_owner||'.CVERS_TXT where LANGU=''E''';"
    a(77)  = "---    execute immediate stmt_text into sap_ver;"
    a(78)  = "---    stmt_text := 'select count(distinct BNAME) from '||sap_owner||'.USR02';"
    a(79)  = "---    execute immediate stmt_text into sap_nbr;"
    a(80)  = "---    stmt_text := 'select count(distinct MANDT) from '||sap_owner||'.T000';"
    a(81)  = "---    execute immediate stmt_text into sap_mndt;"
    a(82)  = "    end if;"
    a(83)  = "    sap_dt_applied := '';"
    a(84)  = "    sap_patch_applied := '';"
    a(85)  = "---"
    a(86)  = "--- PRINT SAP Information"
    a(87)  = "---"
    a(88)  = ""
    a(89)  = "dbms_output.put_line ( 'SAP_INSTALLED='    || sap_ins );"
    a(90)  = "dbms_output.put_line ( 'SAP_CVERS='        || sap_ver );"
    a(91)  = "dbms_output.put_line ( 'MW_NB_USERS='      || sap_nbr );"
    a(92)  = "dbms_output.put_line ( 'MW_NB_MNDTS='      || sap_mndt );"
    a(93)  = "dbms_output.put_line ( 'SAP_DT_APPLIED='   || sap_dt_applied );"
    a(94)  = "dbms_output.put_line ( 'SAP_PATH_APPLIED=' || sap_patch_applied );"
    a(95)  = ""
    a(96)  = "---"
    a(97)  = "--- DATAMINING"
    a(98)  = "---"
    a(99)  = "    SELECT count(*) INTO dmi_tables"
    a(101) = "           FROM all_tables"
    a(102) = "           WHERE OWNER NOT IN ('SYS','SYSTEM');"
    a(103) = ""
    a(104) = "    SELECT count(*) INTO dmi_indexes"
    a(105) = "           FROM all_indexes"
    a(106) = "           WHERE owner NOT IN ('SYS','SYSTEM');"
    a(107) = ""
    a(108) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_data_files"
    a(109) = "           FROM dba_data_files;"
    a(110) = "---"
    a(111) = "--- Partitioned tables not checked"
    a(112) = "---"
    a(113) = "    dmi_table_partitions := 0;"
    a(114) = "    dmi_index_partitions := 0;"
    a(115) = ""
    a(116) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_used"
    a(117) = "           FROM dba_segments;"
    a(118) = ""
    a(119) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_log_space"
    a(120) = "          FROM v$log;"
    a(121) = ""
    a(122) = "---"
    a(123) = "--- Correction of space"
    a(124) = "---"
    a(125) = "--- Collect temporary space"
    a(126) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_dic_tempfiles"
    a(127) = "           FROM dba_data_files"
    a(128) = "        WHERE tablespace_name like 'TEMP%';"
    a(129) = ""
    a(130) = "--- Collect used rollback"
    a(131) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_files"
    a(132) = "           FROM dba_data_files df,  (SELECT distinct(tablespace_name) tablespace_name"
    a(133) = "                                     FROM dba_rollback_segs"
    a(134) = "                                     WHERE tablespace_name NOT in ('SYSTEM')) rb"
    a(135) = "           WHERE df.tablespace_name = rb.tablespace_name;"
    a(136) = ""
    a(137) = "--- Collect undo segments"
    a(138) = "        SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_segments"
    a(139) = "           FROM dba_segments"
    a(140) = "        WHERE segment_type in ('ROLLBACK','TYPE2 UNDO');"
    a(141) = ""
    a(142) = ""
    a(143) = "        dmi_MB_allocated := dmi_MB_data_files - dmi_MB_dic_tempfiles - dmi_MB_undo_files;"
    a(144) = "        dmi_MB_used      := dmi_MB_used - dmi_MB_undo_segments;"
    a(145) = ""
    a(146) = "---"
    a(147) = "--- PRINT DMI information"
    a(148) = "---"
    a(149) = "    DBMS_OUTPUT.PUT_LINE( 'NB_TABLES='  || dmi_tables ) ;"
    a(150) = "    DBMS_OUTPUT.PUT_LINE( 'NB_INDEXES=' || dmi_indexes );"
    a(151) = "    DBMS_OUTPUT.PUT_LINE( 'TABLE_PART=' || dmi_table_partitions );"
    a(152) = "    DBMS_OUTPUT.PUT_LINE( 'INDEX_PART=' || dmi_index_partitions );"
    a(153) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_DB='   || dmi_MB_allocated );"
    a(154) = "    DBMS_OUTPUT.PUT_LINE( 'USED_DB='    || dmi_MB_used );"
    a(155) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_LOG='  || dmi_MB_log_space );"
    a(156) = "    DBMS_OUTPUT.PUT_LINE( 'USED_LOG='   || dmi_MB_log_space );"
    a(157) = ""
    a(158) = "END;"
    a(159) = "/"
    a(160) = "exit"
    
    Set fdesc = fso.OpenTextFile(DMPathString+"get_oracle8min.sql", 2, True)
    For i=1 To 160
        fdesc.WriteLine(a(i))
    Next
    fdesc.Close()
    
    
    Erase a
    
    a(1)   = "connect / as sysdba"
    a(2)   = ""
    a(3)   = "set serveroutput on;"
    a(4)   = ""
    a(5)   = "set verify on"
    a(6)   = "set termout on"
    a(7)   = "set feedback on"
    a(8)   = "set linesize 130"
    a(9)   = ""
    a(10)  = "DECLARE"
    a(11)  = "    stmt_text         varchar2(2000);"
    a(12)  = "    stmt_result       number;"
    a(13)  = ""
    a(14)  = "    ora_host          varchar2(64);"
    a(15)  = "    ora_name          varchar2(64);"
    a(16)  = "    ora_version       varchar2(64);"
    a(17)  = "    ora_edition       varchar2(200);"
    a(18)  = "    ora_fixpack       varchar2(30);"
    a(19)  = ""
    a(20)  = "    sap_owner         varchar2(30);"
    a(21)  = "    sap_ins           varchar2(5);"
    a(22)  = "    sap_ver           varchar2(40);"
    a(23)  = "    sap_nbr           number;"
    a(24)  = "    sap_mndt          number;"
    a(25)  = "    sap_cnt           number;"
    a(26)  = "    sap_dt_applied    varchar2(64);"
    a(27)  = "    sap_patch_applied varchar2(64);"
    a(28)  = ""
    a(29)  = "    dmi_tables           number;"
    a(30)  = "    dmi_indexes          number;"
    a(31)  = "    dmi_table_partitions number;"
    a(32)  = "    dmi_index_partitions number;"
    a(33)  = "    dmi_MB_data_files    number;"
    a(34)  = "    dmi_MB_used          number;"
    a(35)  = "    dmi_MB_log_space     number;"
    a(36)  = "    dmi_MB_dic_tempfiles number;"
    a(37)  = "    dmi_MB_undo_files    number;"
    a(38)  = "    dmi_MB_undo_segments number;"
    a(39)  = "    dmi_MB_allocated     number;"
    a(40)  = "    ora_dbid             number; ora_db_owner     varchar2(64);"
    a(41)  = ""
    a(42)  = "BEGIN"
    a(43)  = "---"
    a(44)  = "--- Basic information"
    a(45)  = "---"
    a(46)  = "    select host_name, instance_name, version "
    a(47)  = "           into ora_host, ora_name, ora_version "
    a(48)  = "           from v$instance;select DBID into ora_dbid from v$database;select username into ora_db_owner from v$process where program like '%PMON%';"
    a(49)  = "    select banner "
    a(50)  = "           into ora_edition"
    a(51)  = "           from v$version"
    a(52)  = "           where banner like 'Oracle%';"
    a(53)  = "---"
    a(54)  = "--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition);"
    a(55)  = "---"
    a(56)  = "--- FIXPACK "
    a(57)  = "---"
    a(58)  = "    ora_fixpack := '';"
    a(59)  = "    select count(*) into stmt_result"
    a(60)  = "           from all_tables"
    a(61)  = "           where table_name = 'REGISTRY$HISTORY';"
    a(62)  = ""
    a(63)  = "    if stmt_result > 0 then"
    a(64)  = "--- table exists"
    a(65)  = "       stmt_text:= 'select count(ACTION) from REGISTRY$HISTORY where ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER''';"
    a(66)  = "       execute immediate stmt_text into stmt_result;"
    a(67)  = "       if stmt_result > 0 then"
    a(68)  = "          stmt_text:= 'select COMMENTS from REGISTRY$HISTORY where ACTION_TIME = (select max(ACTION_TIME) from REGISTRY$HISTORY where ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER'') and ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER''';"
    a(69)  = "          execute immediate stmt_text into ora_fixpack;"
    a(70)  = "       end if;"
    a(71)  = "    end if;"
    a(72)  = "--- PRINT FIXPACK"
    a(73)  = "--- dbms_output.put_line('FIXPACK1='||ora_fixpack);"
    a(74)  = "---"
    a(75)  = "--- PRINT ORA Basic information"
    a(76)  = "---"
    a(77)  = "--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition||','||ora_fixpack);"
    a(78)  = "    dbms_output.put_line('HOSTNAME='||ora_host);dbms_output.put_line('DB_PART='||ora_dbid);dbms_output.put_line('MW_NB_EAR='||ora_db_owner);"
    a(79)  = "    dbms_output.put_line('SUBSYSTEM_INSTANCE='||ora_name); "
    a(80)  = "    dbms_output.put_line('MW_VERSION='||ora_version);"
    a(81)  = "    dbms_output.put_line('MW_EDITION='||ora_edition);"
    a(82)  = "    dbms_output.put_line('FIXPACK='||ora_fixpack);"
    a(83)  = "---"
    a(84)  = "--- SAP"
    a(85)  = "---"
    a(86)  = ""
    a(87)  = "    sap_ins := 'N';"
    a(88)  = "    sap_ver := '';"
    a(89)  = "    sap_nbr := 0;"
    a(90)  = "    sap_mndt := 0;"
    a(91)  = "    select count(*) into sap_cnt from dba_objects where object_name='CVERS_TXT';"
    a(92)  = "    if sap_cnt > 0 then"
    a(93)  = "       sap_ins := 'Y';"
    a(94)  = "       select owner into sap_owner from dba_objects where object_name='CVERS_TXT';"
    a(95)  = "       stmt_text := 'select STEXT from '||sap_owner||'.CVERS_TXT where LANGU=''E''';"
    a(96)  = "       execute immediate stmt_text into sap_ver;"
    a(97)  = "       stmt_text := 'select count(distinct BNAME) from '||sap_owner||'.USR02';"
    a(98)  = "       execute immediate stmt_text into sap_nbr;"
    a(99)  = "       stmt_text := 'select count(distinct MANDT) from '||sap_owner||'.T000';"
    a(101) = "       execute immediate stmt_text into sap_mndt;"
    a(102) = "    end if;"
    a(103) = "    sap_dt_applied := '';"
    a(104) = "    sap_patch_applied := '';"
    a(105) = "---"
    a(106) = "--- PRINT SAP Information"
    a(107) = "---"
    a(108) = "--- dbms_output.put_line('SAP_INFO='||sap_ins||','||sap_ver||','||sap_nbr||','||sap_mndt||','||sap_dt_applied||','||sap_patch_applied);"
    a(109) = ""
    a(110) = "dbms_output.put_line ( 'SAP_INSTALLED='    || sap_ins );"
    a(111) = "dbms_output.put_line ( 'SAP_CVERS='        || sap_ver );"
    a(112) = "dbms_output.put_line ( 'MW_NB_USERS='      || sap_nbr );"
    a(113) = "dbms_output.put_line ( 'MW_NB_MNDTS='      || sap_mndt );"
    a(114) = "dbms_output.put_line ( 'SAP_DT_APPLIED='   || sap_dt_applied );"
    a(115) = "dbms_output.put_line ( 'SAP_PATH_APPLIED=' || sap_patch_applied );"
    a(116) = ""
    a(117) = "---"
    a(118) = "--- DATAMINING"
    a(119) = "---"
    a(120) = "    SELECT count(*) INTO dmi_tables"
    a(121) = "           FROM all_tables"
    a(122) = "           WHERE PARTITIONED = 'NO'"
    a(123) = "           AND OWNER NOT IN ('SYS','SYSTEM');"
    a(124) = ""
    a(125) = "    SELECT count(*) INTO dmi_table_partitions"
    a(126) = "           FROM all_tab_partitions"
    a(127) = "           WHERE TABLE_OWNER  NOT IN ('SYS','SYSTEM');"
    a(128) = ""
    a(129) = "    SELECT count(*) INTO dmi_index_partitions"
    a(130) = "           FROM dba_ind_partitions"
    a(131) = "           WHERE INDEX_OWNER  NOT IN ('SYS','SYSTEM');"
    a(132) = ""
    a(133) = "    SELECT count(*) INTO dmi_indexes"
    a(134) = "           FROM all_indexes"
    a(135) = "           WHERE PARTITIONED = 'NO'"
    a(136) = "           AND owner NOT IN ('SYS','SYSTEM');"
    a(137) = ""
    a(138) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_data_files"
    a(139) = "           FROM dba_data_files;"
    a(140) = ""
    a(141) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_used"
    a(142) = "           FROM dba_segments;"
    a(143) = ""
    a(144) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_log_space"
    a(145) = "          FROM v$log;"
    a(146) = ""
    a(147) = "---"
    a(148) = "--- Correction of space"
    a(149) = "---"
    a(150) = "--- Collect temporary space"
    a(151) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_dic_tempfiles"
    a(152) = "           FROM dba_tablespaces ts, dba_data_files df"
    a(153) = "           WHERE ts.tablespace_name = df.tablespace_name"
    a(154) = "           AND   ts.contents = 'TEMPORARY';"
    a(155) = ""
    a(156) = "--- Collect used rollback"
    a(157) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_files"
    a(158) = "           FROM dba_data_files df,  (SELECT distinct(tablespace_name) tablespace_name"
    a(159) = "                                     FROM dba_rollback_segs"
    a(160) = "                                     WHERE tablespace_name NOT in ('SYSTEM')) rb"
    a(161) = "           WHERE df.tablespace_name = rb.tablespace_name;"
    a(162) = ""
    a(163) = "--- Collect undo segments"
    a(164) = "        SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_segments"
    a(165) = "           FROM dba_segments"
    a(166) = "        WHERE segment_type in ('ROLLBACK','TYPE2 UNDO');"
    a(167) = ""
    a(168) = ""
    a(169) = "        dmi_MB_allocated := dmi_MB_data_files - dmi_MB_dic_tempfiles - dmi_MB_undo_files;"
    a(170) = "        dmi_MB_used      := dmi_MB_used - dmi_MB_undo_segments;"
    a(171) = ""
    a(172) = "---"
    a(173) = "--- PRINT DMI information"
    a(174) = "---"
    a(175) = "    DBMS_OUTPUT.PUT_LINE( 'NB_TABLES='  || dmi_tables );"
    a(176) = "    DBMS_OUTPUT.PUT_LINE( 'NB_INDEXES=' || dmi_indexes );"
    a(177) = "    DBMS_OUTPUT.PUT_LINE( 'TABLE_PART=' || dmi_table_partitions );"
    a(178) = "    DBMS_OUTPUT.PUT_LINE( 'INDEX_PART=' || dmi_index_partitions );"
    a(179) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_DB='   || dmi_MB_allocated );"
    a(180) = "    DBMS_OUTPUT.PUT_LINE( 'USED_DB='    || dmi_MB_used );"
    a(181) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_LOG='  || dmi_MB_log_space );"
    a(182) = "    DBMS_OUTPUT.PUT_LINE( 'USED_LOG='   || dmi_MB_log_space );"
    a(183) = ""
    a(184) = "END;"
    a(185) = "/"
    a(186) = "exit;"
    
    Set fdesc = fso.OpenTextFile(DMPathString+"get_oracle8pls.sql", 2, True)
    For i=1 To 186
        fdesc.WriteLine(a(i))
    Next
    fdesc.Close()
    
    
    Erase a
    
    a(1)   = "connect / as sysdba"
    a(2)   = ""
    a(3)   = "set serveroutput on;"
    a(4)   = ""
    a(5)   = "set verify on"
    a(6)   = "set termout on"
    a(7)   = "set feedback on"
    a(8)   = "set linesize 130"
    a(9)   = ""
    a(10)  = "DECLARE"
    a(11)  = "    stmt_text         varchar2(2000);"
    a(12)  = "    stmt_result       number;"
    a(13)  = ""
    a(14)  = "    ora_host          varchar2(64);"
    a(15)  = "    ora_name          varchar2(64);ora_dbid       number; ora_db_owner     varchar2(64);"
    a(16)  = "    ora_version       varchar2(64);"
    a(17)  = "    ora_edition       varchar2(200);"
    a(18)  = "    ora_fixpack       varchar2(30);"
    a(19)  = ""
    a(20)  = "    sap_owner         varchar2(30);"
    a(21)  = "    sap_ins           varchar2(5);"
    a(22)  = "    sap_ver           varchar2(40);"
    a(23)  = "    sap_nbr           number;"
    a(24)  = "    sap_mndt          number;"
    a(25)  = "    sap_cnt           number;"
    a(26)  = "    sap_dt_applied    varchar2(64);"
    a(27)  = "    sap_patch_applied varchar2(64);"
    a(28)  = ""
    a(29)  = "    dmi_tables           number;"
    a(30)  = "    dmi_indexes          number;"
    a(31)  = "    dmi_table_partitions number;"
    a(32)  = "    dmi_index_partitions number;"
    a(33)  = "    dmi_MB_data_files    number;"
    a(34)  = "    dmi_MB_used          number;"
    a(35)  = "    dmi_MB_log_space     number;"
    a(36)  = "    dmi_MB_dic_tempfiles number;"
    a(37)  = "    dmi_MB_undo_files    number;"
    a(38)  = "    dmi_MB_undo_segments number;"
    a(39)  = "    dmi_MB_allocated     number;"
    a(40)  = "    is_cdb            varchar2(3);"
    a(41)  = "    pdb_list          varchar2(1024);"
    a(42)  = "BEGIN"
    a(43)  = "---"
    a(44)  = "--- Basic information"
    a(45)  = "---"
    a(46)  = "    select host_name, instance_name, version "
    a(47)  = "           into ora_host, ora_name, ora_version "
    a(48)  = "           from v$instance;select DBID into ora_dbid from v$database;select username into ora_db_owner from v$process where program like '%PMON%';"
    a(49)  = "    select banner "
    a(50)  = "           into ora_edition"
    a(51)  = "           from v$version"
    a(52)  = "           where banner like 'Oracle%';"
    a(53)  = "---"
    a(54)  = "--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition);"
    a(55)  = "---"
    a(56)  = "--- FIXPACK "
    a(57)  = "---"
    a(58)  = "    ora_fixpack := '';"
    a(59)  = "    select count(*) into stmt_result"
    a(60)  = "           from all_tables"
    a(61)  = "           where table_name = 'REGISTRY$HISTORY';"
    a(62)  = ""
    a(63)  = "    if stmt_result > 0 then"
    a(64)  = "--- table exists"
    a(65)  = "       stmt_text:= 'select count(ACTION) from REGISTRY$HISTORY where ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER''';"
    a(66)  = "       execute immediate stmt_text into stmt_result;"
    a(67)  = "       if stmt_result > 0 then"
    a(68)  = "          stmt_text:= 'select COMMENTS from REGISTRY$HISTORY where ACTION_TIME = (select max(ACTION_TIME) from REGISTRY$HISTORY where ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER'') and ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER''';"
    a(69)  = "          execute immediate stmt_text into ora_fixpack;"
    a(70)  = "       end if;"
    a(71)  = "    end if;"
    a(72)  = "--- PRINT FIXPACK"
    a(73)  = "--- dbms_output.put_line('FIXPACK1='||ora_fixpack);"
    a(74)  = "---"
    
    a(75)  = "---"
    a(76)  = "--- Since Oracle Database v12.1.0.1 they use DBA_REGISTRY_SQLPATCH instead of DBA_REGISTRY_HISTORY to track PSUs and BPs applied to the database."
    a(77)  = "---"
    a(78)  = "    select count(*) into stmt_result"
    a(79)  = "           from all_tables"
    a(80)  = "           where table_name = 'REGISTRY$SQLPATCH';"
    a(81)  = ""
    a(82)  = "    if stmt_result > 0 then"
    a(83)  = "--- table exists"
    a(84)  = "       stmt_text:= 'select count(ACTION) from REGISTRY$SQLPATCH where ACTION in (''CPU'', ''APPLY'') and STATUS=''SUCCESS''';"
    a(85)  = "       execute immediate stmt_text into stmt_result;"
    a(86)  = "       if stmt_result > 0 then"
    a(87)  = "          stmt_text:= 'select DESCRIPTION from REGISTRY$SQLPATCH where ACTION_TIME = (select max(ACTION_TIME) from REGISTRY$SQLPATCH where ACTION in (''CPU'', ''APPLY'') and STATUS=''SUCCESS'') and ACTION in (''CPU'', ''APPLY'') and STATUS=''SUCCESS''';"
    a(88)  = "          execute immediate stmt_text into ora_fixpack;"
    a(89)  = "       end if;"
    a(90)  = "    end if;"
    a(91)  = "--- PRINT FIXPACK"
    a(92)  = "--- dbms_output.put_line('FIXPACK2='||ora_fixpack);"
    a(93)  = "---"
    
    a(94)  = "---"
    a(95)  = "--- PRINT ORA Basic information"
    a(96)  = "---"
    a(97)  = "--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition||','||ora_fixpack);"
    a(98)  = "    dbms_output.put_line('HOSTNAME='||ora_host);dbms_output.put_line('DB_PART='||ora_dbid);dbms_output.put_line('MW_NB_EAR='||ora_db_owner);"
    a(99)  = "    dbms_output.put_line('SUBSYSTEM_INSTANCE='||ora_name); "
    a(100)  = "    dbms_output.put_line('MW_VERSION='||ora_version);"
    a(101)  = "    dbms_output.put_line('MW_EDITION='||ora_edition);"
    a(102)  = "    dbms_output.put_line('FIXPACK='||ora_fixpack);"
    a(103)  = "---"
    a(104)  = "--- SAP"
    a(105)  = "---"
    a(106)  = ""
    a(107)  = "    sap_ins := 'N';"
    a(108)  = "    sap_ver := '';"
    a(109)  = "    sap_nbr := 0;"
    a(110)  = "    sap_mndt := 0;"
    a(111)  = "    select count(*) into sap_cnt from dba_objects where object_name='CVERS_TXT';"
    a(112)  = "    if sap_cnt > 0 then"
    a(113)  = "       sap_ins := 'Y';"
    a(114)  = "       select owner into sap_owner from dba_objects where object_name='CVERS_TXT';"
    a(115)  = "       stmt_text := 'select STEXT from '||sap_owner||'.CVERS_TXT where LANGU=''E''';"
    a(116)  = "       execute immediate stmt_text into sap_ver;"
    a(117)  = "       stmt_text := 'select count(distinct BNAME) from '||sap_owner||'.USR02';"
    a(118)  = "       execute immediate stmt_text into sap_nbr;"
    a(119)  = "       stmt_text := 'select count(distinct MANDT) from '||sap_owner||'.T000';"
    a(121) = "       execute immediate stmt_text into sap_mndt;"
    a(122) = "    end if;"
    a(123) = "    sap_dt_applied := '';"
    a(124) = "    sap_patch_applied := '';"
    a(125) = "---"
    a(126) = "--- PRINT SAP Information"
    a(127) = "---"
    a(128) = "--- dbms_output.put_line('SAP_INFO='||sap_ins||','||sap_ver||','||sap_nbr||','||sap_mndt||','||sap_dt_applied||','||sap_patch_applied);"
    a(129) = ""
    a(130) = "dbms_output.put_line ( 'SAP_INSTALLED='    || sap_ins );"
    a(131) = "dbms_output.put_line ( 'SAP_CVERS='        || sap_ver );"
    a(132) = "dbms_output.put_line ( 'MW_NB_USERS='      || sap_nbr );"
    a(133) = "dbms_output.put_line ( 'MW_NB_MNDTS='      || sap_mndt );"
    a(134) = "dbms_output.put_line ( 'SAP_DT_APPLIED='   || sap_dt_applied );"
    a(135) = "dbms_output.put_line ( 'SAP_PATH_APPLIED=' || sap_patch_applied );"
    a(136) = ""
    a(137) = "---"
    a(138) = "--- DATAMINING"
    a(139) = "---"
    a(140) = "    SELECT count(*) INTO dmi_tables"
    a(141) = "           FROM all_tables"
    a(142) = "           WHERE PARTITIONED = 'NO'"
    a(143) = "           AND OWNER NOT IN ('SYS','SYSTEM');"
    a(144) = ""
    a(145) = "    SELECT count(*) INTO dmi_table_partitions"
    a(146) = "           FROM all_tab_partitions"
    a(147) = "           WHERE TABLE_OWNER  NOT IN ('SYS','SYSTEM');"
    a(148) = ""
    a(149) = "    SELECT count(*) INTO dmi_index_partitions"
    a(150) = "           FROM dba_ind_partitions"
    a(151) = "           WHERE INDEX_OWNER  NOT IN ('SYS','SYSTEM');"
    a(152) = ""
    a(153) = "    SELECT count(*) INTO dmi_indexes"
    a(154) = "           FROM all_indexes"
    a(155) = "           WHERE PARTITIONED = 'NO'"
    a(156) = "           AND owner NOT IN ('SYS','SYSTEM');"
    a(157) = ""
    a(158) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_data_files"
    a(159) = "           FROM dba_data_files;"
    a(160) = ""
    a(161) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_used"
    a(162) = "           FROM dba_segments;"
    a(163) = ""
    a(164) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_log_space"
    a(165) = "          FROM v$log;"
    a(166) = ""
    a(167) = "---"
    a(168) = "--- Correction of space"
    a(169) = "---"
    a(170) = "--- Collect temporary space"
    a(171) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_dic_tempfiles"
    a(172) = "           FROM dba_tablespaces ts, dba_data_files df"
    a(173) = "           WHERE ts.tablespace_name = df.tablespace_name"
    a(174) = "           AND   ts.contents = 'TEMPORARY';"
    a(175) = ""
    a(176) = "--- Collect used rollback"
    a(177) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_files"
    a(178) = "           FROM dba_data_files df,  (SELECT distinct(tablespace_name) tablespace_name"
    a(179) = "                                     FROM dba_rollback_segs"
    a(180) = "                                     WHERE tablespace_name NOT in ('SYSTEM')) rb"
    a(181) = "           WHERE df.tablespace_name = rb.tablespace_name;"
    a(182) = ""
    a(183) = "--- Collect undo segments"
    a(184) = "        SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_segments"
    a(185) = "           FROM dba_segments"
    a(186) = "        WHERE segment_type in ('ROLLBACK','TYPE2 UNDO');"
    a(187) = ""
    a(188) = ""
    a(189) = "        dmi_MB_allocated := dmi_MB_data_files - dmi_MB_dic_tempfiles - dmi_MB_undo_files;"
    a(190) = "        dmi_MB_used      := dmi_MB_used - dmi_MB_undo_segments;"
    a(191) = ""
    a(192) = "---"
    a(193) = "--- PRINT DMI information"
    a(194) = "---"
    a(195) = "    DBMS_OUTPUT.PUT_LINE( 'NB_TABLES='  || dmi_tables );"
    a(196) = "    DBMS_OUTPUT.PUT_LINE( 'NB_INDEXES=' || dmi_indexes );"
    a(197) = "    DBMS_OUTPUT.PUT_LINE( 'TABLE_PART=' || dmi_table_partitions );"
    a(198) = "    DBMS_OUTPUT.PUT_LINE( 'INDEX_PART=' || dmi_index_partitions );"
    a(199) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_DB='   || dmi_MB_allocated );"
    a(200) = "    DBMS_OUTPUT.PUT_LINE( 'USED_DB='    || dmi_MB_used );"
    a(201) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_LOG='  || dmi_MB_log_space );"
    a(202) = "    DBMS_OUTPUT.PUT_LINE( 'USED_LOG='   || dmi_MB_log_space );"
    a(203) = ""
    a(204) = "---"
    a(205) = "--- CDB check"
    a(206) = "---"
    a(207) = "SELECT cdb INTO is_cdb FROM v$database;"
    a(208) = "    if is_cdb = 'YES' then"
    a(209) = "        pdb_list:='';"
    a(210) = "        stmt_text:= 'select count(name) from V$CONTAINERS WHERE name != ''CDB$ROOT'' AND name != ''PDB$SEED'' ';"
    a(211) = "        execute immediate stmt_text into stmt_result;"
    a(212) = "        if stmt_result > 0 then"
    a(213) = "            stmt_text:= 'select LISTAGG(NAME, '' '') WITHIN GROUP(ORDER BY NAME) from V$CONTAINERS WHERE name != ''CDB$ROOT'' AND  name != ''PDB$SEED'' ';"
    a(214) = "            execute immediate stmt_text into pdb_list;"
    a(215) = "        end if;"
    a(216) = "    end if;"
    a(217) = ""
    a(218) = "    DBMS_OUTPUT.PUT_LINE( 'IS_CDB='     || is_cdb );"
    a(219) = "    DBMS_OUTPUT.PUT_LINE( 'PDB_LIST='   || pdb_list );"
    a(220) = ""
    a(221) = "END;"
    a(222) = "/"
    a(223) = "exit;"
    
    Set fdesc = fso.OpenTextFile(DMPathString+"get_oracle12pls.sql", 2, True)
    For i=1 To 223
        fdesc.WriteLine(a(i))
    Next
    fdesc.Close()
    
    Set fdesc= Nothing
    
End Function



Function CreateDM_Oracle_PDB(ByRef DMPathString, PDBName)
    
    Dim a(206)
    Dim fdesc, i
    
    a(1)   = "connect / as sysdba"
    a(2)   = "alter session set container="&PDBName&";"
    a(3)   = "set serveroutput on;"
    a(4)   = ""
    a(5)   = "set verify on"
    a(6)   = "set termout on"
    a(7)   = "set feedback on"
    a(8)   = "set linesize 130"
    a(9)   = ""
    a(10)  = "DECLARE"
    a(11)  = "    stmt_text         varchar2(2000);"
    a(12)  = "    stmt_result       number;"
    a(13)  = ""
    a(14)  = "    ora_host          varchar2(64);"
    a(15)  = "    ora_name          varchar2(64);"
    a(16)  = "    ora_version       varchar2(64);"
    a(17)  = "    ora_edition       varchar2(200);"
    a(18)  = "    ora_fixpack       varchar2(30);"
    a(19)  = ""
    a(20)  = "    sap_owner         varchar2(30);"
    a(21)  = "    sap_ins           varchar2(5);"
    a(22)  = "    sap_ver           varchar2(40);"
    a(23)  = "    sap_nbr           number;"
    a(24)  = "    sap_mndt          number;"
    a(25)  = "    sap_cnt           number;"
    a(26)  = "    sap_dt_applied    varchar2(64);"
    a(27)  = "    sap_patch_applied varchar2(64);"
    a(28)  = ""
    a(29)  = "    dmi_tables           number;"
    a(30)  = "    dmi_indexes          number;"
    a(31)  = "    dmi_table_partitions number;"
    a(32)  = "    dmi_index_partitions number;"
    a(33)  = "    dmi_MB_data_files    number;"
    a(34)  = "    dmi_MB_used          number;"
    a(35)  = "    dmi_MB_log_space     number;"
    a(36)  = "    dmi_MB_dic_tempfiles number;"
    a(37)  = "    dmi_MB_undo_files    number;"
    a(38)  = "    dmi_MB_undo_segments number;"
    a(39)  = "    dmi_MB_allocated     number;"
    a(40)  = "    ora_dbid             number; ora_db_owner     varchar2(64);"
    a(41)  = ""
    a(42)  = "BEGIN"
    a(43)  = "---"
    a(44)  = "--- Basic information"
    a(45)  = "---"
    a(46)  = "    select host_name, instance_name, version "
    a(47)  = "           into ora_host, ora_name, ora_version "
    a(48)  = "           from v$instance;select DBID into ora_dbid from v$database;select username into ora_db_owner from v$process where program like '%PMON%';"
    a(49)  = "    select banner "
    a(50)  = "           into ora_edition"
    a(51)  = "           from v$version"
    a(52)  = "           where banner like 'Oracle%';"
    a(53)  = "---"
    a(54)  = "--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition);"
    a(55)  = "---"
    a(56)  = "--- FIXPACK "
    a(57)  = "---"
    a(58)  = "    ora_fixpack := '';"
    a(59)  = "    select count(*) into stmt_result"
    a(60)  = "           from all_tables"
    a(61)  = "           where table_name = 'REGISTRY$HISTORY';"
    a(62)  = ""
    a(63)  = "    if stmt_result > 0 then"
    a(64)  = "--- table exists"
    a(65)  = "       stmt_text:= 'select count(ACTION) from REGISTRY$HISTORY where ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER''';"
    a(66)  = "       execute immediate stmt_text into stmt_result;"
    a(67)  = "       if stmt_result > 0 then"
    a(68)  = "          stmt_text:= 'select COMMENTS from REGISTRY$HISTORY where ACTION_TIME = (select max(ACTION_TIME) from REGISTRY$HISTORY where ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER'') and ACTION in (''CPU'', ''APPLY'') and NAMESPACE=''SERVER''';"
    a(69)  = "          execute immediate stmt_text into ora_fixpack;"
    a(70)  = "       end if;"
    a(71)  = "    end if;"
    a(72)  = "--- PRINT FIXPACK"
    a(73)  = "--- dbms_output.put_line('FIXPACK1='||ora_fixpack);"
    a(74)  = "---"
    
    a(75)  = "---"
    a(76)  = "--- Since Oracle Database v12.1.0.1 they use DBA_REGISTRY_SQLPATCH instead of DBA_REGISTRY_HISTORY to track PSUs and BPs applied to the database."
    a(77)  = "---"
    a(78)  = "    select count(*) into stmt_result"
    a(79)  = "           from all_tables"
    a(80)  = "           where table_name = 'REGISTRY$SQLPATCH';"
    a(81)  = ""
    a(82)  = "    if stmt_result > 0 then"
    a(83)  = "--- table exists"
    a(84)  = "       stmt_text:= 'select count(ACTION) from REGISTRY$SQLPATCH where ACTION in (''CPU'', ''APPLY'') and STATUS=''SUCCESS''';"
    a(85)  = "       execute immediate stmt_text into stmt_result;"
    a(86)  = "       if stmt_result > 0 then"
    a(87)  = "          stmt_text:= 'select DESCRIPTION from REGISTRY$SQLPATCH where ACTION_TIME = (select max(ACTION_TIME) from REGISTRY$SQLPATCH where ACTION in (''CPU'', ''APPLY'') and STATUS=''SUCCESS'') and ACTION in (''CPU'', ''APPLY'') and STATUS=''SUCCESS''';"
    a(88)  = "          execute immediate stmt_text into ora_fixpack;"
    a(89)  = "       end if;"
    a(90)  = "    end if;"
    a(91)  = "--- PRINT FIXPACK"
    a(92)  = "--- dbms_output.put_line('FIXPACK2='||ora_fixpack);"
    a(93)  = "---"
    
    a(94)  = "---"
    a(95)  = "--- PRINT ORA Basic information"
    a(96)  = "---"
    a(97)  = "--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition||','||ora_fixpack);"
    a(98)  = "    dbms_output.put_line('HOSTNAME='||ora_host);dbms_output.put_line('DB_PART='||ora_dbid);dbms_output.put_line('MW_NB_EAR='||ora_db_owner);"
    a(99)  = "    dbms_output.put_line('SUBSYSTEM_INSTANCE='||ora_name); "
    a(100)  = "    dbms_output.put_line('MW_VERSION='||ora_version);"
    a(101)  = "    dbms_output.put_line('MW_EDITION='||ora_edition);"
    a(102)  = "    dbms_output.put_line('FIXPACK='||ora_fixpack);"
    a(103)  = "---"
    a(104)  = "--- SAP"
    a(105)  = "---"
    a(106)  = ""
    a(107)  = "    sap_ins := 'N';"
    a(108)  = "    sap_ver := '';"
    a(109)  = "    sap_nbr := 0;"
    a(110)  = "    sap_mndt := 0;"
    a(111)  = "    select count(*) into sap_cnt from dba_objects where object_name='CVERS_TXT';"
    a(112)  = "    if sap_cnt > 0 then"
    a(113)  = "       sap_ins := 'Y';"
    a(114)  = "       select owner into sap_owner from dba_objects where object_name='CVERS_TXT';"
    a(115)  = "       stmt_text := 'select STEXT from '||sap_owner||'.CVERS_TXT where LANGU=''E''';"
    a(116)  = "       execute immediate stmt_text into sap_ver;"
    a(117)  = "       stmt_text := 'select count(distinct BNAME) from '||sap_owner||'.USR02';"
    a(118)  = "       execute immediate stmt_text into sap_nbr;"
    a(119)  = "       stmt_text := 'select count(distinct MANDT) from '||sap_owner||'.T000';"
    a(121) = "       execute immediate stmt_text into sap_mndt;"
    a(122) = "    end if;"
    a(123) = "    sap_dt_applied := '';"
    a(124) = "    sap_patch_applied := '';"
    a(125) = "---"
    a(126) = "--- PRINT SAP Information"
    a(127) = "---"
    a(128) = "--- dbms_output.put_line('SAP_INFO='||sap_ins||','||sap_ver||','||sap_nbr||','||sap_mndt||','||sap_dt_applied||','||sap_patch_applied);"
    a(129) = ""
    a(130) = "dbms_output.put_line ( 'SAP_INSTALLED='    || sap_ins );"
    a(131) = "dbms_output.put_line ( 'SAP_CVERS='        || sap_ver );"
    a(132) = "dbms_output.put_line ( 'MW_NB_USERS='      || sap_nbr );"
    a(133) = "dbms_output.put_line ( 'MW_NB_MNDTS='      || sap_mndt );"
    a(134) = "dbms_output.put_line ( 'SAP_DT_APPLIED='   || sap_dt_applied );"
    a(135) = "dbms_output.put_line ( 'SAP_PATH_APPLIED=' || sap_patch_applied );"
    a(136) = ""
    a(137) = "---"
    a(138) = "--- DATAMINING"
    a(139) = "---"
    a(140) = "    SELECT count(*) INTO dmi_tables"
    a(141) = "           FROM all_tables"
    a(142) = "           WHERE PARTITIONED = 'NO'"
    a(143) = "           AND OWNER NOT IN ('SYS','SYSTEM');"
    a(144) = ""
    a(145) = "    SELECT count(*) INTO dmi_table_partitions"
    a(146) = "           FROM all_tab_partitions"
    a(147) = "           WHERE TABLE_OWNER  NOT IN ('SYS','SYSTEM');"
    a(148) = ""
    a(149) = "    SELECT count(*) INTO dmi_index_partitions"
    a(150) = "           FROM dba_ind_partitions"
    a(151) = "           WHERE INDEX_OWNER  NOT IN ('SYS','SYSTEM');"
    a(152) = ""
    a(153) = "    SELECT count(*) INTO dmi_indexes"
    a(154) = "           FROM all_indexes"
    a(155) = "           WHERE PARTITIONED = 'NO'"
    a(156) = "           AND owner NOT IN ('SYS','SYSTEM');"
    a(157) = ""
    a(158) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_data_files"
    a(159) = "           FROM dba_data_files;"
    a(160) = ""
    a(161) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_used"
    a(162) = "           FROM dba_segments;"
    a(163) = ""
    a(164) = "    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_log_space"
    a(165) = "          FROM v$log;"
    a(166) = ""
    a(167) = "---"
    a(168) = "--- Correction of space"
    a(169) = "---"
    a(170) = "--- Collect temporary space"
    a(171) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_dic_tempfiles"
    a(172) = "           FROM dba_tablespaces ts, dba_data_files df"
    a(173) = "           WHERE ts.tablespace_name = df.tablespace_name"
    a(174) = "           AND   ts.contents = 'TEMPORARY';"
    a(175) = ""
    a(176) = "--- Collect used rollback"
    a(177) = "    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_files"
    a(178) = "           FROM dba_data_files df,  (SELECT distinct(tablespace_name) tablespace_name"
    a(179) = "                                     FROM dba_rollback_segs"
    a(180) = "                                     WHERE tablespace_name NOT in ('SYSTEM')) rb"
    a(181) = "           WHERE df.tablespace_name = rb.tablespace_name;"
    a(182) = ""
    a(183) = "--- Collect undo segments"
    a(184) = "        SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_segments"
    a(185) = "           FROM dba_segments"
    a(186) = "        WHERE segment_type in ('ROLLBACK','TYPE2 UNDO');"
    a(187) = ""
    a(188) = ""
    a(189) = "        dmi_MB_allocated := dmi_MB_data_files - dmi_MB_dic_tempfiles - dmi_MB_undo_files;"
    a(190) = "        dmi_MB_used      := dmi_MB_used - dmi_MB_undo_segments;"
    a(191) = ""
    a(192) = "---"
    a(193) = "--- PRINT DMI information"
    a(194) = "---"
    a(195) = "    DBMS_OUTPUT.PUT_LINE( 'NB_TABLES='  || dmi_tables );"
    a(196) = "    DBMS_OUTPUT.PUT_LINE( 'NB_INDEXES=' || dmi_indexes );"
    a(197) = "    DBMS_OUTPUT.PUT_LINE( 'TABLE_PART=' || dmi_table_partitions );"
    a(198) = "    DBMS_OUTPUT.PUT_LINE( 'INDEX_PART=' || dmi_index_partitions );"
    a(199) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_DB='   || dmi_MB_allocated );"
    a(200) = "    DBMS_OUTPUT.PUT_LINE( 'USED_DB='    || dmi_MB_used );"
    a(201) = "    DBMS_OUTPUT.PUT_LINE( 'ALLOC_LOG='  || dmi_MB_log_space );"
    a(202) = "    DBMS_OUTPUT.PUT_LINE( 'USED_LOG='   || dmi_MB_log_space );"
    a(203) = ""
    a(204) = "END;"
    a(205) = "/"
    a(206) = "exit;"
    
    Set fdesc = fso.OpenTextFile(DMPathString+"get_oracle_pdb.sql", 2, True)
    For i=1 To 206
        fdesc.WriteLine(a(i))
    Next
    fdesc.Close()
    
    Set fdesc= Nothing
    
End Function


'***********************************************************************************************
'* Retrieve InstancePort for Oracle
'***********************************************************************************************

Function GetInstPortOracle(ByRef InstN, ByRef strPathEnvParam)
    
    Dim fdesc, strMySecondLine, strMyLine, strflag, inPORT, inBracket, strTemp, inSID
    
    On Error Resume Next
    
    GetInstPortOracle = ""
    If fso.FileExists(strPathEnvParam & "network\admin\tnsnames.ora") Then
        Set fdesc = fso.OpenTextFile(strPathEnvParam & "network\admin\tnsnames.ora", 1, True)
        
        strMyLine = ""
        strMySecondLine = ""
        
        Do While fdesc.AtEndOfStream <> True
            strMySecondLine = fdesc.ReadLine
            If Err.number <> 0 Then 
                Trace "GetInstPortOracle. Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source
                Exit Do 
            End If
            strMyLine = strMyLine  & " " & strMySecondLine
        Loop
        
        Trace("strMyLine = " & strMyLine)
        
        strflag = False
        Do While strflag <> True
            If (InStr(strMyLine, InstN) > 0) And (InStr(strMyLine, "PORT") > 0) And (InStr(strMyLine, "SID") = 0) Then
                inPORT = InStr(strMyLine, "PORT")
                inBracket = InStr( InStr( strMyLine, "PORT"), strMyLine, ")")
                strTemp = Mid(strMyLine, inPORT, inBracket - inPORT)
                GetInstPortOracle = Trim(Mid(strTemp, InStr(strTemp, "=")+ 1 ))
                Trace "SID not found"
                strflag = True
                
            ElseIf (InStr(strMyLine, InstN) > 0) And (InStr(strMyLine, "PORT") > 0) And (InStr(strMyLine, "SID") > 0) Then
                inSID = InStr( strMyLine, "SID")
                inBracket = InStr( InStr( strMyLine, "SID"), strMyLine, ")")
                strTemp = Mid(strMyLine, inSID, inBracket - inSID)
                strTemp = Trim(Mid(strTemp, InStr(strTemp, "=")+ 1 ))
                Trace strTemp & " ?= "  & InstN
                If strTemp = InstN Then
                    inPORT = InStr(strMyLine, "PORT")
                    inBracket = InStr( InStr( strMyLine, "PORT"), strMyLine, ")")
                    strTemp = Mid(strMyLine, inPORT, inBracket - inPORT)
                    GetInstPortOracle = Trim(Mid(strTemp, InStr(strTemp, "=")+ 1 ))
                    strflag = True
                Else
                    strMyLine = Mid(strMyLine, inBracket + 1)
                End If
                
            Else strflag = True
            End If
        Loop
        
        Trace "Port from tnsnames.ora - GetInstPortOracle = " & GetInstPortOracle
        fdesc.Close()
        Set fdesc = Nothing
    End If
End Function

'***********************************************************************************************
'* Retrieve InstancePort for Oracle from Listener.ora
'***********************************************************************************************

Function GetInstPortOracleFromListenerOra(ByRef InstN, ByRef strPathEnvParam)
    
    Dim arrLine, Line, strSID_NAME
    Dim strListenerName, str
    Dim fStart, iCountBracket, iCnt
    Dim re, objMatch
    
    On Error Resume Next
    
    str = ""
    str = readFile(strPathEnvParam & "network\admin\listener.ora")
    strSID_NAME = InstN
    GetInstPortOracleFromListenerOra = ""
    
    Trace "_________________________________________"
    Trace ""
    
    strListenerName = ""
    ArrLine = Split(str & vbCrLf,vbCrLf)
    For Each Line In ArrLine
        If InStr(Line, "SID_LIST_") > 0 Then
            strListenerName = Trim(Mid(Line, InStr(Line, "SID_LIST_") + 9, InStr(Line, "=") - InStr(Line, "SID_LIST_") - 9 ))
        End If
        If strListenerName <> "" And InStr(Line, "SID_NAME") > 0 Then
            If Trim(Replace(Replace(Mid(Line, InStr(Line, "SID_NAME") + 8, Len(Line) - InStr(Line, "SID_NAME") - 7 ), "=", ""), ")", "")) = strSID_NAME Then
                Trace "strListenerName = " & strListenerName
                Exit For
            End If
        End If
    Next
    
    fStart = False
    iCountBracket = -1
    
    For Each Line In ArrLine
        
        If (iCountBracket > 0 Or strListenerName = "" ) And InStr(Line, "PORT") > 0 Then
            iCountBracket = -1
            
            Set re = New RegExp
            re.IgnoreCase = True
            re.Pattern = "^.*?PORT\s*=\s*(\d+)\D*$"
            Set objMatch = re.Execute(Replace(Line, " ", ""))
            
            If objMatch.Count > 0 Then
                Trace "Port from listener.ora - objMatch(0).SubMatches(0) = " & objMatch(0).SubMatches(0)
                GetInstPortOracleFromListenerOra = objMatch(0).SubMatches(0)
                Exit For
            End If
            
        End If
        
        If strListenerName <> "" Then
            If StrComp(Replace(Line, " ", ""), strListenerName & "=") = 0 And InStr(Line, "SID_LIST_") = 0 Then
                Trace Line
                fStart = True
            End If
            
            If fStart And InStr(Line, "(") Then
                fStart = False
                iCountBracket = 0
            End If
            
            If Not fStart And iCountBracket >= 0 Then
                For iCnt = 1 To Len(Line)
                    If Mid(Line, iCnt, 1) = "(" Then iCountBracket = iCountBracket + 1
                    If Mid(Line, iCnt, 1) = ")" Then iCountBracket = iCountBracket - 1
                Next
            End If
        End If
    Next
    
End Function

'***********************************************************************************************
'* Find a edition in an dll file
'*********************************************************************************************** 
Function GetStringEdition(strFilename, strDefault)
    Dim bs, str, locale
    Dim iStart, iEnd, iEnd2, i, iFileSize, iTraceLen
    Dim strPossibleEdition
    Dim code, strChar
    On Error Resume Next
    Trace "******* GetStringEdition *******"
    Trace "<< Filename: " & strFilename
    Trace "<< Default: " & strDefault
    str = ""
    
    GetStringEdition = strDefault
    Locale = SetLocale(1033)
    Set bs = CreateObject("ADODB.Stream")
    If Err.number <> 0 Then
        SetLocale(Locale)
        Trace "Set bs = CreateObject(""ADODB.Stream""): " & Err.Number & " " & Err.Description
        Trace "1------- GetStringEdition -------"
        Exit Function
    End If
    'Open the file in a binary mode
    bs.Type = 1
    bs.Open
    bs.LoadFromFile(strFilename)
    'Switch to a text mode
    bs.Position = 0
    bs.Type = 2
    bs.CharSet = "x-ansi"
    str = bs.ReadText(bs.Size)
    bs.Close
    Set bs = Nothing
    iEnd = 0
    iFileSize = Len(str) 
    Trace "File size: " & iFileSize
    strPossibleEdition = ""
    
    iStart = InStr(1, Str, "Oracle ", 0)
    Do While iStart > 0 
        iEnd = InStr(iStart, str, Chr(0), 0)
        Trace "iStart: " & iStart
        Trace "iEnd:" & iEnd
        'Limit to 64 chars
        If iEnd - iStart > 64 Then
            iEnd = iStart + 64
            Trace "Limit the string to 64 chars. iEnd: " & iEnd
        End If
        strPossibleEdition = CheckAndTrimStr(Mid(str, iStart, iEnd - iStart))
        Trace "Possible edition: " & strPossibleEdition
        
        If DEBUG_MODE Then
            If iStart + 64 > iFileSize Then
                iTraceLen = iFileSize
            Else
                iTraceLen = iStart + 64
            End If 
            
            For i = iStart To iTraceLen
                strChar = Mid(str, I, 1)
                code = Asc(strChar)
                If code>31 And code<127 Then 
                    Trace strChar & " - " & code
                Else
                    Trace " " & " - " & code
                End If	
            Next
        End If
        'Skip some lines
        If InStr(strPossibleEdition, "%d" ) > 7 Then
            Trace "---Possible Edition found..."
            GetStringEdition = Left(strPossibleEdition, InStr(strPossibleEdition, "%d" ) - 1)
            Trace "+++Chose this one..."
        End If	
        
        iStart = InStr(iEnd + 1, Str, "Oracle ", 0)
    Loop
    SetLocale(Locale)
    
    If GetStringEdition = "" Then GetStringEdition = strDefault	
    Trace ">> Edition:" & GetStringEdition
    
    If Err.Number <> 0 Then
        Trace "Error # " & Err.Number & " " & Err.Description
        Err.Clear
    End If
    
    GetStringEdition = Trim(Replace(Trim(GetStringEdition), "Release", ""))
    If InStr(1, str, "Personal") > 0 Then GetStringEdition = GetStringEdition & " Personal Edition"
    Trace ">>>> Edition:" & GetStringEdition
    
    Trace "2------- GetStringEdition -------"
End Function

Function CheckAndTrimStr(str)
    Dim i, code, isCorrectStr, strLen
    Dim strChar
    Trace "******* CheckAndTrimStr *******"
    strLen = Len("" & str)
    Trace "<< Length: " & strLen
    isCorrectStr = (strLen>0 And strLen<65)
    For i=1 To Len(str)
        strChar = Mid(str,i,1)
        code = Asc(strChar)
        If code = 0 And i > 1 Then
            isCorrectStr = True
            CheckAndTrimStr = Left(str,i-1)
            Trace ">> Result: " & CheckAndTrimStr
            Trace ">> Length: " & i-1
            Trace "1------- CheckAndTrimStr -------"
            Exit Function
        End If
        If code<32 Or code>126 Then 
            isCorrectStr = False
            Exit For
        End If
        Trace strChar
    Next
    If isCorrectStr Then CheckAndTrimStr = str Else CheckAndTrimStr = ""
    Trace ">> Result: " & CheckAndTrimStr
    Trace ">> Length: " & Len(CheckAndTrimStr)
    Trace "2------- CheckAndTrimStr -------"
End Function

'***********************************************************************************************
'* Retrieve SAP Details for Oracle
'***********************************************************************************************

Function GetSAPinfoToOracle(ByRef InstN, ByRef CONNECT_STR, strORACLE_HOME)
    
    Dim WshShellSAP, WshEnvSAP, strCmd, oExec1, strLine, strSQLOwner, tabOwner, strOwner, strSQLCTEXT, oExec2
    Dim strFindVersion, tabVersion, strSQLNBUSER, strFindNBUSER, tabNBUSER, strSQLMANDANT, strFindMandant, tabMandant
    
    On Error Resume Next
    Set WshShellSAP = CreateObject("Wscript.Shell")    
    Set WshEnvSAP = WshShellSAP.Environment("PROCESS")
    '    WshEnvSAP("ORACLE_SID") = InstN
    '    WshEnv("ORACLE_HOME") = strORACLE_HOME
    '    WshEnv("PATH") = strORACLE_HOME & "\bin" & ";" & WshEnv("PATH")
    
    strCmd ="cmd.exe /c @echo  select decode(count(*),0,'NOSAP','ISSAP') from dba_objects where object_name='CVERS_TXT';  | " & CONNECT_STR
    Set oExec1 = WshShellSAP.Exec(strCmd)
    
    If Err.number = 0 Then 
        
        strSAP_INSTALLED="N"
        '        strSAP_CVERS=""  
        '        strMW_NB_USERS=""   
        '        strMW_NB_MNDTS=""   
        
        Do While Not oExec1.stdout.AtEndOfStream
            strLine=oExec1.stdOut.ReadLine
            Trace("strLine = " & strLine)
            
            If InStr(strLine,"SAP") > 0   Then
                If InStr(strLine,"ISSAP") > 0  Then
                    
                    strSAP_INSTALLED="Y" 
                    
                    strSQLOwner = "cmd.exe /c @echo  select concat(owner,'#') from dba_objects where object_name='CVERS_TXT'; | " & CONNECT_STR
                    Set oExec2 = WshShellSAP.Exec(strSQLOwner)
                    
                    Do While Not oExec2.stdOut.AtEndOfStream
                        strFindOwner= oExec2.stdOut.ReadLine
                        Trace("strFindOwner = " & strFindOwner)
                        
                        If InStr(strFindOwner,"#") > 0  And InStr(LCase(strFindOwner),"concat") = 0 Then
                            tabOwner= Split(strFindOwner,"#")
                            strOwner = tabOwner(0)
                            Trace("strOwner = " & strOwner)
                        End If
                    Loop
                    
                    strSQLCTEXT = "cmd.exe /c @echo  select concat(STEXT,'#') from "& strOwner & ".CVERS_TXT where LANGU='E'; | " & CONNECT_STR
                    Set oExec2 = WshShellSAP.Exec(strSQLCTEXT)
                    
                    Do While Not oExec2.stdOut.AtEndOfStream
                        strFindVersion= oExec2.stdOut.ReadLine
                        Trace("strFindVersion = " & strFindVersion)
                        If InStr(strFindVersion,"#") > 0  And InStr(LCase(strFindVersion),"concat") = 0 Then
                            tabVersion= Split(Trim(strFindVersion),"#")
                            strSAP_CVERS = tabVersion(0)
                            Trace("strSAP_CVERS = " & strSAP_CVERS)
                        End If
                    Loop
                    
                    strSQLNBUSER = "cmd.exe /c @echo  select concat(count(distinct BNAME),'#') from "& strOwner & ".USR02; | " & CONNECT_STR
                    Set oExec2 = WshShellSAP.Exec(strSQLNBUSER)
                    
                    Do While Not oExec2.stdOut.AtEndOfStream
                        strFindNBUSER= oExec2.stdOut.ReadLine
                        Trace("strFindNBUSER = " & strFindNBUSER)
                        
                        If InStr(strFindNBUSER,"#") > 0  And InStr(LCase(strFindNBUSER),"concat") = 0 Then
                            tabNBUSER= Split(Trim(strFindNBUSER),"#")
                            strMW_NB_USERS = tabNBUSER(0)
                            Trace("strMW_NB_USERS = " & strMW_NB_USERS)
                        End If
                    Loop
                    
                    strSQLMANDANT = "cmd.exe /c @echo select concat(count(distinct MANDT),'#') from "& strOwner & ".T000; | " & CONNECT_STR
                    Set oExec2 = WshShellSAP.Exec(strSQLMANDANT)
                    
                    Do While Not oExec2.stdOut.AtEndOfStream
                        strFindMandant= oExec2.stdOut.ReadLine
                        Trace("strFindMandant = " & strFindMandant)
                        
                        If InStr(strFindMandant,"#") > 0  And InStr(LCase(strFindMandant),"concat") = 0 Then
                            tabMandant= Split(Trim(strFindMandant),"#")
                            strMW_NB_MNDTS = tabMandant(0)
                            Trace("strMW_NB_MNDTS = " & strFindMandant)
                        End If
                    Loop
                    Set oExec2 = Nothing
                End If 'issap
            End If
        Loop
        Set oExec1 = Nothing                       	
        
    End If
    
    Set WshEnvSAP = Nothing
    Set WshShellSAP = Nothing
    
End Function

'***********************************************************************************************
'* Retrieve FIXPACK for Oracle
'***********************************************************************************************

Function GetCPUPATCHOracle(ByRef InstN, ByRef CONNECT_STR, strORACLE_HOME)
    
    Dim WshShellORA, WshEnvORA, strCmd, oExec1, strLine
    
    On Error Resume Next
    Set WshShellORA = CreateObject("Wscript.Shell") 
    Set WshEnvORA = WshShellORA.Environment("PROCESS")   
    '    WshEnvORA("ORACLE_SID") = InstN
    '    WshEnv("ORACLE_HOME") = strORACLE_HOME
    '    WshEnv("PATH") = strORACLE_HOME & "\bin" & ";" & WshEnv("PATH")
    
    strFIXPACK=""
    
    strCmd = "cmd.exe /c @echo "
    strCmd = strCmd & "SELECT comments from registry$history "
    strCmd = strCmd &         "where ACTION_TIME  = ( select max(ACTION_TIME) from registry$history "
    strCMd = strCmd &                                   "where ACTION='CPU' and NAMESPACE='SERVER') "
    strCmd = strCmd &         "and ACTION='CPU' and NAMESPACE='SERVER'; "
    strCmd = strCmd & " | " & CONNECT_STR
    Trace("strCmd = " & strCmd)
    Set oExec1 = WshShellORA.Exec(strCmd)
    Do While Not oExec1.stdout.AtEndOfStream
        strLine=oExec1.stdOut.ReadLine
        Trace("strLine = " & strLine)
        
        If InStr(strLine,"CPU") = 1  Then
            Trace ( "FixPACK Instr=" & CStr(InStr(strLine,"CPU")) )
            strFIXPACK=Mid(strLine,1,10)
            Exit Do  
        End If
    Loop
    Trace ( "strFIXPACK=" & strFIXPACK)
    Set oExec1 = Nothing                       	
    Set WshShellORA = Nothing
    Set WshEnvORA = Nothing
    
End Function


'***********************************************************************************************
'* MAIN
'***********************************************************************************************

Sub Main()
    Const strLogFileName = "subs.ora.log"
    Const strMifFileName = "SUBS_ORA_INV.mif"
    Const strScannerName = "ORA"
    Const strDescription = "DESCRIPTION = ""The script automatically lists instances, databases, and size of Oracle databases on WINDOWS servers"""
    
    On Error Resume Next
    
    SetGlobalVariables
    
    If DEBUG_MODE Then DeleteTemporaryFile("script_trace.txt")
    
    Trace (Version)
    Trace ("$Id: subs_ora_win.vbs,v 1.54 2015/02/17 13:46:12 cvsmaksim Exp $")
    
    Dim WshShell
    Set WshShell = CreateObject("Wscript.Shell")
    
    DeleteTemporaryFolder(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\"))
    DeleteTemporaryFile(strLogFileName)
    DeleteTemporaryFile(strMifFilename)
    
    CreateDirectories WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\ora\")
    
    GetHostAndGlobalParameters
    
    CheckConditions
    
    If strMW_EDITION <> NotSupported Then
        SubscanOracle
        CreateEmptyLogIfNotExist strLogFileName, strScannerName, ""
    Else
        CreateEmptyLogIfNotExist strLogFileName, strScannerName, NotSupported
    End If
    
    CreateMIFfile strMifFileName, strDescription, strScannerName, strLogFileName
    DeleteTemporaryFolder(WshShell.ExpandEnvironmentStrings("%TEMP%\cscans\"))
    Set fso = Nothing 
End Sub

'_______________________________________________________________________________________________
'                                      Run "Main" sub
'_______________________________________________________________________________________________

Main

'_______________________________________________________________________________________________
'                  Required functions and classes. You can't delete it. 
'_______________________________________________________________________________________________

'***********************************************************************************************
'* Class "IniFile" encapsulates API of ini files
'* Using:  Dim objIni 
'*         set objIni = New IniFile
'*             objIni.Open(strFileName)
'*             strValue = objIni.getString(strSection,strKey,strDefaulValue) 
'*             objIni.setString strSection, strKey, strValue
'*             objIni.writeIni(strFileName)   
'***********************************************************************************************

Class IniFile
    Private objIniFile
    
    Private Sub Class_Initialize()
        Set objIniFile = WScript.CreateObject("Scripting.Dictionary")
        objIniFile.CompareMode = 1
    End Sub
    
    Private Sub Class_Terminate()
        On Error Resume Next
        Set objIniFile = Nothing
    End Sub	
    
    Function Open(strIniFileName)
        On Error Resume Next
        Dim SectionKeys, strSection
        Dim intEquals, sKey, sVal, i, sLine, tsIni
        
        Err.Clear
        
        If fso.FileExists(strIniFileName) Then
            
            Set tsIni = fso.OpenTextFile(strIniFileName)
            
            Do While Not tsIni.AtEndOfStream
                
                sLine = ""
                sLine = Trim(Replace(tsIni.ReadLine, Chr(9), " "))
                If Err.number <> 0 Then 
                    Trace("IniFile.Open " & strIniFileName & " Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                    Exit Do 
                End If
                
                If sLine <> "" Then
                    If Left(sLine, 1) <> ";" Then
                        If Left(sLine, 1) = "[" Then
                            'blnFoundSection = True
                            'Msgbox sLine & " section found"
                            strSection = Left(sLine, Len(sLine) - 1)
                            strSection = Right(strSection, Len(strSection) - 1)
                            Set SectionKeys = WScript.CreateObject("Scripting.Dictionary")
                            SectionKeys.CompareMode = 1
                            If Not objIniFile.Exists(strSection) Then objIniFile.Add strSection, SectionKeys
                        Else
                            'key and value logic
                            intEquals = InStr(1, sLine, "=")
                            If (intEquals <= 1) Then
                                Trace "IniFile.Open " & strIniFileName & " line: " & sLine
                            Else
                                'weve found a valid line
                                sKey = Trim(Left(sLine, intEquals - 1))
                                sVal = Trim(Right(sLine, Len(sLine) - intEquals))
                                If Not SectionKeys.Exists(sKey) Then 
                                    SectionKeys.Add sKey, sVal
                                Else
                                    Trace "IniFile.Open: " & strIniFileName & " The key already exists! " & _
                                    vbCrLf & "It has been skipped: " & sKey & "=" & SectionKeys(sKey) & " -> " & sLine
                                    'SectionKeys(sKey) = sVal
                                End If
                                'key and value logic end if
                            End If
                        End If
                    End If
                End If
            Loop
            
            tsIni.Close
            Set tsIni = Nothing
        End If
    End Function
    
    Function getString(strSection, strKey, strDefValue)
        getString = strDefValue
        
        If objIniFile.Exists(strSection) Then
            If	objIniFile.Item(strSection).Exists(strKey) Then
                getString = objIniFile.Item(strSection).Item(strKey)
            End If
        End If
    End Function
    
    Function EnumSections
        EnumSections = objIniFile.Keys 
    End Function
    
    Function CountSections
        CountSections = objIniFile.Count 
    End Function
    
    Function EnumKeys(strSection)
        If objIniFile.Exists(strSection) Then
            EnumKeys = objIniFile.Item(strSection).Keys
        Else
            EnumKeys = Null
        End If
    End Function	
    
    Sub setString(strSection, strKey, strValue)
        Dim SectionKeys
        If objIniFile.Exists(strSection) = False Then 
            Set SectionKeys = WScript.CreateObject("Scripting.Dictionary")
            SectionKeys.CompareMode = 1
            objIniFile.Add strSection, SectionKeys
        End If
        If objIniFile.Item(strSection).Exists(strKey) = False Then
            objIniFile.Item(strSection).add strKey, strValue
        Else
            objIniFile.Item(strSection).Item(strKey) = strValue
        End If	
    End Sub
    
    Sub WriteIni(strIniFileName)
        On Error Resume Next
        Dim tsIni, strSection, StrKey  
        If objIniFile.Count > 0 Then 
            
            Set tsIni = fso.OpenTextFile(strIniFileName, 2, True)
            If Err.number <> 0 Then
                Trace("IniFile.writeIni " & strIniFileName & "Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)  
                Exit Sub
            End If
            
            
            For Each strSection In objIniFile.Keys 
                tsIni.WriteLine("[" & strSection & "]")
                If Err.number <> 0 Then 
                    Trace("IniFile.writeIni " & strIniFileName & " Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                    Exit For 
                End If
                
                For Each strKey In objIniFile.Item(strSection).Keys  
                    tsIni.WriteLine strKey & "=" & objIniFile.Item(strSection).item(strKey)
                    If Err.number <> 0 Then 
                        Trace("IniFile.writeIni " & strFilename & " Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                        Exit For 
                    End If
                Next
                tsIni.WriteLine("")	
            Next
            tsIni.Close()
            Set tsIni = Nothing
        End If
    End Sub
    
End Class

'***********************************************************************************************
'* Set blank values
'***********************************************************************************************

Sub SetBlankValues
    
    strCOMPUTER_SYS_ID = ""
    strCUST_ID = ""
    strSYST_ID = ""
    '        strHOSTNAME=""
    strSUBSYSTEM_INSTANCE = ""
    strSUBSYSTEM_TYPE = ""
    strMW_VERSION = ""
    strMW_EDITION = ""
    strFIXPACK = ""
    strINSTANCE_PATH = ""
    strDB_NAME = ""
    '        strSCAN_TIME=""
    strSAP_INSTALLED = ""
    strSAP_CVERS = ""
    '        strOS_VERSION=""
    strINSTANCE_PORT = ""
    strNB_TABLES = ""
    strNB_INDEXES = ""
    strALLOC_DB = ""
    strUSED_DB = ""
    strALLOC_LOG = ""
    strUSED_LOG = ""
    strDB_PART = ""
    strTABLE_PART = ""
    strINDEX_PART = ""
    strSERVER_TYPE = ""
    strDB_TYPE = ""
    strDBMS_TYPE = ""
    '	strSDC = ""
    strDB_USAGE = ""
    strSVC_OFFERED = ""
    strHC_REQUIRED = ""
    strMW_INST_ID = ""
    strMW_MODULE = ""
    strMW_NB_EAR = ""
    strMW_NB_USERS = ""
    strMW_NB_MNDTS = ""
    strSW_BUNDLE = ""
    '	strSCANNER_VERSION = ""
    
End Sub

'***********************************************************************************************
'* Delete temporary files
'***********************************************************************************************

Sub DeleteTemporaryFile(ByRef strFile)
    
    If fso.FileExists(strFile) Then
        fso.DeleteFile(strFile)
    End If
    
End Sub

'***********************************************************************************************
'* Create a field=value pair
'***********************************************************************************************

Function GetTruncated(strFieldName, ByRef strField, size)
    Dim DELIM, AFFECT, SEP, str
    SEP  = ";"
    DELIM = ""
    AFFECT = "="
    
    If Len(strField) > size Then
        str = Left(strField, size)
        Trace "*****Warning! " & strFieldName & "=" & strField & "The value has been tuncatued. " 
        Trace "              " & strFieldName & "=" & str
        strField = str	
    End If
    
    GetTruncated = DELIM & strFieldName & DELIM & AFFECT & DELIM & strField & DELIM & SEP
End Function

'***********************************************************************************************
'* Create a .log file line
'***********************************************************************************************

Function WriteEntryToLog
    
    If strSUBSYSTEM_INSTANCE <> "NO" Then
        If strMW_EDITION = "" Then
            strMW_EDITION = DEFAULT_EDITION
            Trace("use default value for MW_EDITION")
        End If
        If strMW_VERSION = "" Then
            strMW_VERSION = DEFAULT_VERSION
            Trace("use default value for MW_VERSION")
        End If
    End If
    
    WriteEntryToLog = _
    GetTruncated ("COMPUTER_SYS_ID", strCOMPUTER_SYS_ID, 1024) & _
    GetTruncated ("CUST_ID", strCUST_ID, SZ_CUST_ID) & _
    GetTruncated ("SYST_ID", strSYST_ID, SZ_SYST_ID) & _
    GetTruncated ("HOSTNAME", strHOSTNAME, SZ_HOSTNAME) & _
    GetTruncated ("SUBSYSTEM_INSTANCE", strSUBSYSTEM_INSTANCE, SZ_SUBSYSTEM_INSTANCE) & _
    GetTruncated ("SUBSYSTEM_TYPE", strSUBSYSTEM_TYPE, SZ_SUBSYSTEM_TYPE) & _
    GetTruncated ("MW_VERSION", strMW_VERSION, SZ_MW_VERSION) & _
    GetTruncated ("MW_EDITION", strMW_EDITION, SZ_MW_EDITION) & _
    GetTruncated ("FIXPACK", strFIXPACK, SZ_FIXPACK) & _
    GetTruncated ("INSTANCE_PATH", strINSTANCE_PATH, SZ_INSTANCE_PATH) & _
    GetTruncated ("DB_NAME", strDB_NAME, SZ_DB_NAME) & _
    GetTruncated ("SCAN_TIME", strSCAN_TIME, 20) & _
    GetTruncated ("SAP_INSTALLED", strSAP_INSTALLED, SZ_SAP_INSTALLED) & _
    GetTruncated ("SAP_CVERS", strSAP_CVERS, SZ_SAP_CVERS) & _
    GetTruncated ("OS_VERSION", strOS_VERSION, SZ_OS_VERSION) & _
    GetTruncated ("INSTANCE_PORT", strINSTANCE_PORT, SZ_INSTANCE_PORT) & _
    GetTruncated ("NB_TABLES", strNB_TABLES, SZ_NB_TABLES) & _
    GetTruncated ("NB_INDEXES", strNB_INDEXES, SZ_NB_INDEXES) & _
    GetTruncated ("ALLOC_DB", strALLOC_DB, SZ_ALLOC_DB) & _
    GetTruncated ("USED_DB", strUSED_DB, SZ_USED_DB) & _
    GetTruncated ("ALLOC_LOG", strALLOC_LOG, SZ_ALLOC_LOG) & _
    GetTruncated ("USED_LOG", strUSED_LOG, SZ_USED_LOG) & _
    GetTruncated ("DB_PART", strDB_PART, SZ_DB_PART) & _
    GetTruncated ("TABLE_PART", strTABLE_PART, SZ_TABLE_PART) & _
    GetTruncated ("INDEX_PART", strINDEX_PART, SZ_INDEX_PART) & _
    GetTruncated ("SERVER_TYPE", strSERVER_TYPE, SZ_SERVER_TYPE) & _
    GetTruncated ("DB_TYPE", strDB_TYPE, SZ_DB_TYPE) & _
    GetTruncated ("DBMS_TYPE", strDBMS_TYPE, SZ_DBMS_TYPE) & _
    GetTruncated ("SDC", strSDC, SZ_SDC) & _
    GetTruncated ("DB_USAGE", strDB_USAGE, SZ_DB_USAGE) & _
    GetTruncated ("SVC_OFFERED", strSVC_OFFERED, SZ_SVC_OFFERED) & _
    GetTruncated ("HC_REQUIRED", strHC_REQUIRED, SZ_HC_REQUIRED) & _
    GetTruncated ("MW_INST_ID", strMW_INST_ID, SZ_MW_INST_ID) & _
    GetTruncated ("MW_MODULE", strMW_MODULE, SZ_MW_MODULE) & _
    GetTruncated ("MW_NB_EAR", strMW_NB_EAR, SZ_MW_NB_EAR) & _
    GetTruncated ("MW_NB_USERS", strMW_NB_USERS, SZ_MW_NB_USERS) & _
    GetTruncated ("MW_NB_MNDTS", strMW_NB_MNDTS, SZ_MW_NB_MNDTS) & _
    GetTruncated ("SW_BUNDLE", strSW_BUNDLE, SZ_SW_BUNDLE) & _
    GetTruncated ("SCANNER_VERSION", strSCANNER_VERSION, SZ_SCANNER_VERSION)
End Function

'***********************************************************************************************
'* Template function for mif-file format
'***********************************************************************************************

Function WriteValues2Mif
    
    Dim BRACKET, ENDBRACKET, SEP, DELIM
    
    BRACKET = "{"
    ENDBRACKET = "}"
    SEP = ","
    DELIM = """"
    
    WriteValues2Mif = BRACKET & _
    DELIM & strCUST_ID & DELIM & _
    SEP & DELIM & strSYST_ID & DELIM & _
    SEP & DELIM & strHOSTNAME & DELIM & _
    SEP & DELIM & strSUBSYSTEM_INSTANCE & DELIM & _
    SEP & DELIM & strSUBSYSTEM_TYPE & DELIM & _
    SEP & DELIM & strMW_VERSION & DELIM & _
    SEP & DELIM & strMW_EDITION & DELIM & _
    SEP & DELIM & strFIXPACK & DELIM & _
    SEP & DELIM & strINSTANCE_PATH & DELIM & _
    SEP & DELIM & strDB_NAME & DELIM & _
    SEP & DELIM & strSAP_INSTALLED & DELIM & _
    SEP & DELIM & strSAP_CVERS & DELIM & _
    SEP & DELIM & strOS_VERSION & DELIM & _
    SEP & DELIM & strINSTANCE_PORT & DELIM & _
    SEP & DELIM & strNB_TABLES & DELIM & _
    SEP & DELIM & strNB_INDEXES & DELIM & _
    SEP & DELIM & strALLOC_DB & DELIM & _
    SEP & DELIM & strUSED_DB & DELIM & _
    SEP & DELIM & strALLOC_LOG & DELIM & _
    SEP & DELIM & strUSED_LOG & DELIM & _
    SEP & DELIM & strDB_PART & DELIM & _
    SEP & DELIM & strTABLE_PART & DELIM & _
    SEP & DELIM & strINDEX_PART & DELIM & _
    SEP & DELIM & strSERVER_TYPE & DELIM & _
    SEP & DELIM & strDB_TYPE & DELIM & _
    SEP & DELIM & strDBMS_TYPE & DELIM & _
    SEP & DELIM & strSDC & DELIM & _
    SEP & DELIM & strDB_USAGE & DELIM & _
    SEP & DELIM & strSVC_OFFERED & DELIM & _
    SEP & DELIM & strHC_REQUIRED & DELIM & _
    SEP & DELIM & strMW_INST_ID & DELIM & _
    SEP & DELIM & strMW_MODULE & DELIM & _
    SEP & DELIM & strMW_NB_EAR & DELIM & _
    SEP & DELIM & strMW_NB_USERS & DELIM & _
    SEP & DELIM & strMW_NB_MNDTS & DELIM & _
    SEP & DELIM & strSW_BUNDLE & DELIM & _
    SEP & DELIM & strSCANNER_VERSION & DELIM & _
    ENDBRACKET
    
    Trace("WriteValues2Mif = " & WriteValues2Mif)
    
End Function

'***********************************************************************************************
'* Create empty log if one is not exist
'***********************************************************************************************

Sub CreateEmptyLogIfNotExist(ByRef strLogName, ByRef strScriptType, strNotSupp)
    
    On Error Resume Next
    
    ' format empty Log file
    'COMPUTER_SYS_ID=;CUST_ID=;SYST_ID=;HOSTNAME=AFS;SUBSYSTEM_INSTANCE=NO;SUBSYSTEM_TYPE=AFS;MW_VERSION=;MW_EDITION=;
    'FIXPACK=;INSTANCE_PATH=;DB_NAME=;SCAN_TIME=AFS;SAP_INSTALLED=;SAP_CVERS=;OS_VERSION=AFS;INSTANCE_PORT=;NB_TABLES=;
    'NB_INDEXES=;ALLOC_DB=;USED_DB=;ALLOC_LOG=;USED_LOG=;DB_PART=;TABLE_PART=;INDEX_PART=;SERVER_TYPE=AFS;DB_TYPE=;DBMS_TYPE=;
    'SDC=;DB_USAGE=;SVC_OFFERED=;HC_REQUIRED=;MW_INST_ID=;MW_MODULE=;MW_NB_EAR=;MW_NB_USERS=;MW_NB_MNDTS=;SW_BUNDLE=;SCANNER_VERSION=;
    
    Dim fdesc
    
    If fso.FileExists(strLogName) Then
        Trace(strLogName & " is exist")
    Else
        Trace(strLogName & " is not exist")
        
        SetBlankValues
        
        strSUBSYSTEM_INSTANCE = "NO"
        strSUBSYSTEM_TYPE = strScriptType
        strSERVER_TYPE = "WINDOWS"
        strMW_EDITION = strNotSupp
        If strNewSys_id <> "Sys_id not found" Then strSYST_ID = strNewSys_id 
        If strNewCompSys_id <> "Computer_Sys_id not found" Then strCOMPUTER_SYS_ID = strNewCompSys_id
        
        Set fdesc = fso.OpenTextFile(strLogName, 2, True)
        If Err.number <> 0 Then
            Trace("CreateEmptyLogIfNotExist" & strLogName & ". Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
        End If
        fdesc.WriteLine(WriteEntryToLog)
        fdesc.Close()
        
    End If
    
    Set fdesc = Nothing
    
End Sub

'***********************************************************************************************
'* Create an attribute record in the mif file
'***********************************************************************************************

Sub WriteMifAtrtribute(fdescMIF, strName, strID, size)
    With fdescMIF 
        .WriteLine "                START ATTRIBUTE"
        .WriteLine "                        NAME = """ & strName & """"
        .WriteLine "                        ID = " & strID
        .WriteLine "                        ACCESS = READ-ONLY"
        .WriteLine "                        TYPE = STRING(" & size & ")"
        .WriteLine "                        VALUE = """""
        .WriteLine "                END ATTRIBUTE"
    End With
End Sub

'***********************************************************************************************
'* Create a mif file
'***********************************************************************************************

Sub CreateMIFfile(ByRef strMifName, ByRef strDESCRIPTION, ByRef strScriptType, ByRef strLogName)
    
    On Error Resume Next
    
    Trace("*********CreateMIFfile *********")
    
    Dim fdescMIF, fdescLog, str, AL
    
    Set fdescMIF = fso.OpenTextFile(strMifName, 2, True)
    If Err.number <> 0 Then
        Trace("CreateMIFfile" & strMifName & ". Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
        Err.Clear
    End If
    
    Set fdescLog = fso.OpenTextFile(strLogName, 1, True)
    If Err.number <> 0 Then
        Trace("CreateMIFfile" & strLogName & ". Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
    End If	
    
    
    With fdescMIF 				
        .WriteLine "START COMPONENT"
        .WriteLine "NAME = """ & strScriptType & " MIF FILE"""
        .WriteLine strDESCRIPTION
        .WriteLine ""
        .WriteLine "        START GROUP"
        .WriteLine "                NAME = ""SUBS_" & strScriptType & "_INV"""
        .WriteLine "                CLASS = ""DMTF|SUBS_" & strScriptType & "_INV|1.0"""
        WriteMifAtrtribute fdescMIF, "CUST_ID", "1", SZ_CUST_ID
        WriteMifAtrtribute fdescMIF, "SYST_ID", "2", SZ_SYST_ID
        WriteMifAtrtribute fdescMIF, "HOSTNAME", "3", SZ_HOSTNAME
        WriteMifAtrtribute fdescMIF, "SUBSYSTEM_INSTANCE", "4", SZ_SUBSYSTEM_INSTANCE
        WriteMifAtrtribute fdescMIF, "SUBSYSTEM_TYPE", "5", SZ_SUBSYSTEM_TYPE
        WriteMifAtrtribute fdescMIF, "MW_VERSION", "6", SZ_MW_VERSION
        WriteMifAtrtribute fdescMIF, "MW_EDITION", "7", SZ_MW_EDITION
        WriteMifAtrtribute fdescMIF, "FIXPACK", "8", SZ_FIXPACK
        WriteMifAtrtribute fdescMIF, "INSTANCE_PATH", "9", SZ_INSTANCE_PATH
        WriteMifAtrtribute fdescMIF, "DB_NAME", "10", SZ_DB_NAME
        WriteMifAtrtribute fdescMIF, "SAP_INSTALLED", "11", SZ_SAP_INSTALLED
        WriteMifAtrtribute fdescMIF, "SAP_CVERS", "12", SZ_SAP_CVERS
        WriteMifAtrtribute fdescMIF, "OS_VERSION", "13", SZ_OS_VERSION
        WriteMifAtrtribute fdescMIF, "INSTANCE_PORT", "14", SZ_INSTANCE_PORT
        WriteMifAtrtribute fdescMIF, "NB_TABLES", "15", SZ_NB_TABLES
        WriteMifAtrtribute fdescMIF, "NB_INDEXES", "16", SZ_NB_INDEXES
        WriteMifAtrtribute fdescMIF, "ALLOC_DB", "17", SZ_ALLOC_DB
        WriteMifAtrtribute fdescMIF, "USED_DB", "18", SZ_USED_DB
        WriteMifAtrtribute fdescMIF, "ALLOC_LOG", "19", SZ_ALLOC_LOG
        WriteMifAtrtribute fdescMIF, "USED_LOG", "20", SZ_USED_LOG
        WriteMifAtrtribute fdescMIF, "DB_PART", "21", SZ_DB_PART
        WriteMifAtrtribute fdescMIF, "TABLE_PART", "22", SZ_TABLE_PART
        WriteMifAtrtribute fdescMIF, "INDEX_PART", "23", SZ_INDEX_PART
        WriteMifAtrtribute fdescMIF, "SERVER_TYPE", "24", SZ_SERVER_TYPE
        WriteMifAtrtribute fdescMIF, "DB_TYPE", "25", SZ_DB_TYPE
        WriteMifAtrtribute fdescMIF, "DBMS_TYPE", "26", SZ_DBMS_TYPE
        WriteMifAtrtribute fdescMIF, "SDC", "27", SZ_SDC
        WriteMifAtrtribute fdescMIF, "DB_USAGE", "28", SZ_DB_USAGE
        WriteMifAtrtribute fdescMIF, "SVC_OFFERED", "29", SZ_SVC_OFFERED
        WriteMifAtrtribute fdescMIF, "HC_REQUIRED", "30", SZ_HC_REQUIRED
        WriteMifAtrtribute fdescMIF, "MW_INST_ID", "31", SZ_MW_INST_ID
        WriteMifAtrtribute fdescMIF, "MW_MODULE", "32", SZ_MW_MODULE
        WriteMifAtrtribute fdescMIF, "MW_NB_EAR", "33", SZ_MW_NB_EAR
        WriteMifAtrtribute fdescMIF, "MW_NB_USERS", "34", SZ_MW_NB_USERS
        WriteMifAtrtribute fdescMIF, "MW_NB_MNDTS", "35", SZ_MW_NB_MNDTS
        WriteMifAtrtribute fdescMIF, "SW_BUNDLE", "36", SZ_SW_BUNDLE
        WriteMifAtrtribute fdescMIF, "SCANNER_VERSION", "37", SZ_SCANNER_VERSION
        .WriteLine "                KEY = 1"
        .WriteLine "        END GROUP"
        .WriteLine  ""
        .WriteLine  "        START TABLE"
        .WriteLine  "        NAME = ""SUBS_" & strScriptType & "_INV"""
        .WriteLine  "        ID = 1"
        .WriteLine  "        CLASS = ""DMTF|SUBS_" & strScriptType & "_INV|1.0"""
        .WriteLine  ""
        
        
        ' Extract data from global log and put them to mif
        
        ' format of empty Log file
        'COMPUTER_SYS_ID=;CUST_ID=;SYST_ID=;HOSTNAME=XXX;SUBSYSTEM_INSTANCE=NO;SUBSYSTEM_TYPE=XXX;MW_VERSION=;MW_EDITION=;
        'FIXPACK=;INSTANCE_PATH=;DB_NAME=;SCAN_TIME=XXX;SAP_INSTALLED=;SAP_CVERS=;OS_VERSION=XXX;INSTANCE_PORT=;NB_TABLES=;
        'NB_INDEXES=;ALLOC_DB=;USED_DB=;ALLOC_LOG=;USED_LOG=;DB_PART=;TABLE_PART=;INDEX_PART=;SERVER_TYPE=XXX;DB_TYPE=;DBMS_TYPE=;
        'SDC=;DB_USAGE=;SVC_OFFERED=;HC_REQUIRED=;MW_INST_ID=;MW_MODULE=;MW_NB_EAR=;MW_NB_USERS=;MW_NB_MNDTS=;SW_BUNDLE=;SCANNER_VERSION=;
        
        ' format of mif file
        'CUST_ID,SYST_ID,HOSTNAME,SUBSYSTEM_INSTANCE,SUBSYSTEM_TYPE,MW_VERSION,MW_EDITION,FIXPACK,INSTANCE_PATH,DB_NAME,
        'SAP_INSTALLED,SAP_CVERS,OS_VERSION,INSTANCE_PORT,NB_TABLES,NB_INDEXES,ALLOC_DB,USED_DB,ALLOC_LOG,USED_LOG,DB_PART,
        'TABLE_PAR,INDEX_PART,SERVER_TYPE,DB_TYPE,DBMS_TYPE,SDC,DB_USAGE ,SVC_OFFERED,HC_REQUIRED,MW_INST_ID,MW_MODULE,MW_NB_EAR,
        'MW_NB_USERS,MW_NB_MNDTS,SW_BUNDLE,SCANNER_VERSION
        
        Do While fdescLog.AtEndOfStream <> True
            str = fdescLog.ReadLine
            
            'prevents endless loop
            If Err.number <> 0 Then 
                Trace("Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                Exit Do 
            End If
            
            Trace("!String from log    " & str)
            str = Replace(str, "=", ";")
            Trace(str)
            AL = Split(str, ";")
            
            strCOMPUTER_SYS_ID = AL(1)
            strCUST_ID = AL(3)
            strSYST_ID = AL(5)
            strHOSTNAME = AL(7)
            strSUBSYSTEM_INSTANCE = AL(9)
            strSUBSYSTEM_TYPE = AL(11)
            strMW_VERSION = AL(13)
            strMW_EDITION = AL(15)
            strFIXPACK = AL(17)
            strINSTANCE_PATH = Replace(AL(19), "\", "\\")
            strDB_NAME = AL(21)
            strSCAN_TIME = AL(23)
            strSAP_INSTALLED = AL(25)
            strSAP_CVERS = AL(27)
            strOS_VERSION = AL(29)
            strINSTANCE_PORT = AL(31)
            strNB_TABLES = AL(33)
            strNB_INDEXES = AL(35)
            strALLOC_DB = AL(37)
            strUSED_DB = AL(39)
            strALLOC_LOG = AL(41)
            strUSED_LOG = AL(43)
            strDB_PART = AL(45)
            strTABLE_PART = AL(47)
            strINDEX_PART = AL(49)
            strSERVER_TYPE = AL(51)
            strDB_TYPE = AL(53)
            strDBMS_TYPE = AL(55)
            strSDC = AL(57)
            strDB_USAGE = AL(59)
            strSVC_OFFERED = AL(61)
            strHC_REQUIRED = AL(63)
            strMW_INST_ID = AL(65)
            strMW_MODULE = AL(67)
            strMW_NB_EAR = AL(69)
            strMW_NB_USERS = AL(71)
            strMW_NB_MNDTS = AL(73)
            strSW_BUNDLE = AL(75)
            strSCANNER_VERSION = AL(77)
            
            .WriteLine(WriteValues2Mif)
            
        Loop
        
        .WriteLine ""
        .WriteLine "     END TABLE"
        .WriteLine "END COMPONENT"
        
    End With
    
    fdescLog.Close()
    fdescMIF.Close()
    
    Set fdescMIF = Nothing
    Set fdescLog = Nothing
    
    Trace("*********The end of CreateMIFfile*********")
    
End Sub

'***********************************************************************************************
'* Retrieve Global Parameters and Global parameters
'***********************************************************************************************

Sub GetHostAndGlobalParameters
    Dim strTCPHostname
    strOS_VERSION = GetOSVersion()
    strWindowsVersion = GetWindowsVersion()
    strSCAN_TIME = GetScanDate()
    'strHOSTNAME = GetHostName()
    strHOSTNAME = GetHostNameWMI()
    strTCPHostname = GetHostNameTCP()
    If InStr(1, strTCPHostname, strHOSTNAME,1 ) = 1 Then
        If Len(strTCPHostname) > 15 Then strHOSTNAME = strTCPHostname
    End If
    strNewSys_id = GetNewSys_id()
    strNewCompSys_id = GetNewCompSys_id()
End Sub

'***********************************************************************************************
'* Retrieve Windows version
'***********************************************************************************************

Function GetWindowsVersion()
    On Error Resume Next
    Dim WshShell
    Set WshShell = WScript.CreateObject("WScript.Shell")
    GetWindowsVersion = WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName")
    Set WshShell = Nothing		
End Function

'***********************************************************************************************
'* Retrieve Windows build number
'***********************************************************************************************

Function GetOSVersion()
    On Error Resume Next
    Dim g_WshShell
    Set g_WshShell = WScript.CreateObject("wscript.Shell")
	
	    GetOSVersion = g_WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentMajorVersionNumber") & _
	    "." & g_WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentMinorVersionNumber") & _
	    "." & g_WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentBuildNumber")
        
        If GetOSVersion = ""  Then
            GetOSVersion = g_WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentVersion") & _
	        "." & g_WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentBuildNumber")
        End If
    
    Trace("GetOSVersion = " & GetOSVersion)
    Set g_WshShell = Nothing
End Function

'***********************************************************************************************
'* Retrieve scan date
'***********************************************************************************************

Function GetScanDate()
    Dim dtDate, d, m, y
    dtDate = Date
    d = Day(dtDate)
    m = Month(dtDate)
    y = Year(dtDate)
    If Len(d) < 2 Then d = "0" & d
    If Len(m) < 2 Then m = "0" & m
    GetScanDate = "" & y & m & d
End Function

'***********************************************************************************************
'* Retrieve System info
'***********************************************************************************************

Function GetHostName()
    On Error Resume Next
    Dim WshShell
    Set WshShell = WScript.CreateObject("WScript.Shell")
    GetHostName = WshShell.Environment("PROCESS")("COMPUTERNAME")
    Trace "%COMPUTERNAME%=" &  GetHostName 
    Set WshShell = Nothing
End Function

Function GetHostNameWMI()
    On Error Resume Next
    Err.Clear
    Dim objWMIService, colItems, objItem
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Set colItems = objWMIService.ExecQuery ("Select * from Win32_OperatingSystem")
    For Each objItem In colItems
        Trace "Hostname: " &  objItem.CSName 
        GetHostNameWMI = objItem.CSName
    Next
    If Err.Number<>0 Then
        GetHostNameWMI = ""
        Trace "GetHostNameWMI. Error #" & Err.Number & " " & Err.Description
        Err.Clear
    End If
End Function

Function GetHostNameTCP()
    On Error Resume Next
    Dim WshShell
    Set WshShell = WScript.CreateObject("WScript.Shell")
    GetHostNameTCP = WshShell.RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\hostname")
    If Err.Number<>0 Then
        GetHostNameTCP = ""
        Trace "GetHostNameTCP. Error #" & Err.Number & " " & Err.Description
        Err.Clear
    End If
End Function 

'***********************************************************************************************
'* Retrieve new Sys_id from tlmagent.ini
'***********************************************************************************************

Function GetNewSys_id()
    On Error Resume Next
    Dim WshShell, strCmd, StrPathTlmAgent, fdescTlm, str, strAgent_version, strUSERDATA1, strUSERDATA3
    GetNewSys_id = "Sys_id not found"
    Set WshShell = CreateObject("Wscript.Shell")
    StrPathTlmAgent = WshShell.ExpandEnvironmentStrings("%WINDIR%\itlm\tlmagent.ini")
    Trace("StrPathTlmAgent = " & StrPathTlmAgent)
    
    strAgent_version = ""
    strUSERDATA1     = ""
    strUSERDATA3     = ""
    
    If fso.FileExists(StrPathTlmAgent) Then                                               
        Set fdescTlm = fso.OpenTextFile(StrPathTlmAgent, 1, True)
        Do While fdescTlm.AtEndOfStream <> True
            
            str = fdescTlm.ReadLine
            'prevents endless loop
            If Err.number <> 0 Then 
                Trace("GetNewSys_id. Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                Exit Do 
            End If
            
            If strAgent_version = "" Then strAgent_version = ExtractData(str, "agent_version")
            If strUSERDATA1 = "" Then strUSERDATA1 = ExtractData(str, "USERDATA1")
            If strUSERDATA3 = "" Then strUSERDATA3 = ExtractData(str, "USERDATA3")
            
            GetNewSys_id = strUSERDATA1
            If InStr(strAgent_version, ".") > 0 Then
                If IsNumeric(Mid(strAgent_version, 1, InStr(strAgent_version, ".") -1)) Then
                    If CInt(Mid(strAgent_version, 1, InStr(strAgent_version, ".") -1)) > 6 Then
                        GetNewSys_id = strUSERDATA3
                    End If
                End If
            End If
        Loop
        fdescTlm.Close
        Set fdescTlm = Nothing
    End If
    Trace("GetNewSys_id = " & GetNewSys_id)
    Set WshShell = Nothing
End Function

'***********************************************************************************************
'* Get data from file
'***********************************************************************************************
Function ExtractData(strLine, strParam)
    Dim WshShell, strFullFileName, fileTXT, str, arrLine
    
    On Error Resume Next
    Err.Clear
    str = ""
    
    If InStr(1, Trim(strLine), strParam, 1) = 1 And InStr(Trim(strLine), "#") <> 1 Then
        Trace "strLine = " & strLine
        arrLine = Split(Trim(Replace(strLine, Chr(9), " ")), "=")
        Trace "arrLine(0) = " & arrLine(0)
        Trace "arrLine(1) = " & arrLine(1)
        Trace "Ubound(arrLine) = " & UBound(arrLine)
        If LCase(Trim(arrLine(0))) = LCase(strParam) Then
            str = Trim(arrLine(1))
        End If
        Trace "Extract " & strParam & " -------------> str = " & str
    End If
    
    ExtractData = str
End Function

'***********************************************************************************************
'* Retrieve new CompSys_id from sdist.nfo
'***********************************************************************************************

Function GetNewCompSys_id()
    On Error Resume Next
    Dim strPath, WshShell, str, fdescSdist
    GetNewCompSys_id = "Computer_Sys_id not found"
    Set WshShell = CreateObject("Wscript.Shell")
    strPath = WshShell.ExpandEnvironmentStrings("%LCFROOT%\inv\SCAN\sdist.nfo")
    Set WshShell = Nothing						
    If Mid(strPath, 1, 1) <> "%" Then
        Trace("path to sdist.nfo = " & strPath)	
        If fso.FileExists(strPath) Then                                               
            Set fdescSdist = fso.OpenTextFile(strPath, 1, True)
            Do While fdescSdist.AtEndOfStream <> True And GetNewCompSys_id = "Computer_Sys_id not found"
                str = fdescSdist.ReadLine
                'prevents endless loop				
                If Err.number <> 0 Then 
                    Trace("GetNewCompSys_id. Error # " & CStr(Err.Number) & " " & Err.Description & "  Source: " & Err.Source)
                    Exit Do 
                End If
                If InStr(UCase(str), "COMPUTER.COMPUTER_SYS_ID") > 0 Then GetNewCompSys_id = Trim(Mid(str, InStr(str, "=") + 1))
            Loop
            fdescSdist.Close
            Set fdescSdist = Nothing
        End If
    Else
        Trace("path to sdist.nfo = parametr LCFROOT not found")
    End If
    Trace("GetNewCompSys_id = " & GetNewCompSys_id)
End Function

'***********************************************************************************************
'* Add row to trace-file
'***********************************************************************************************

Sub Trace(ByVal msg)
    If DEBUG_MODE = True Then
        Dim trc, re, Matches
        Set re = New RegExp
        re.Pattern = "([^\r\n]{800})"
        re.Global = True
        msg = "" & msg
        msg = re.Replace(msg,"$1" + vbCrLf)
        
        Set trc = fso.OpenTextFile("script_trace.txt", 8, True)
        trc.WriteLine(msg)
        trc.Close()
        Set trc = Nothing
    End If
End Sub

'***********************************************************************************************
'* Retrieve Service State
'***********************************************************************************************

Function isStatusRunning(strTestedServiceStatus)
    
    Dim myVar
    
    myVar = LCase(Trim(strTestedServiceStatus))
    
    Select Case MyVar
        Case "running" isStatusRunning = True
        Case "dTmarrT" isStatusRunning = True
        Case "gestartet" isStatusRunning = True
        Case Else isStatusRunning = False
    End Select
    
End Function

'***********************************************************************************************
'* Check conditions(WScript.Version and Windows version)
'***********************************************************************************************

Sub CheckConditions
    
    Dim WSV, WshShell, strFile, arrNumbers, isNotWin2000
    Trace vbCrLf & "Checking requirements:"
    
    NotSupported = OS_NotSupported	
    If strHOSTNAME = "" Then
        strHOSTNAME = GetHostname()
        Trace("WMI Error!")
        strMW_EDITION = NotSupported
    End If
    
    Trace("OS version: " & strOS_VERSION)
    arrNumbers = Split(strOS_VERSION, ".")
    If UBound(arrNumbers) > 1 Then
        If CInt(arrNumbers(0)) < 5 Then
            Trace("is not supported(should be Windows2000 or later)")
            strMW_EDITION = NotSupported
        End If
        isNotWin2000 = (arrNumbers(0) > 5)
    Else
        Trace("incorrect version number, should be Windows2000 or later")
        strMW_EDITION = NotSupported
    End If
    If strMW_EDITION <> NotSupported Then
        Trace(" - passed")
    Else
        Exit Sub
    End If
    
    NotSupported = VB_NotSupported	
    Set WshShell = CreateObject("WScript.Shell")
    strFile = WshShell.ExpandEnvironmentStrings("%windir%\system32\vbscript.dll")
    WSV = fso.GetFileVersion(strFile)
    
    Trace("VBScript.dll version: " & WSV)
    arrNumbers = Split(WSV, ".")
    If UBound(arrNumbers) > 1 Then
        If Not ((CInt(arrNumbers(0)) = 5 And CInt(arrNumbers(1)) >= 6) Or CInt(arrNumbers(0)) > 5) Then
            Trace("is not supported, should be 5.6 or later")
            strMW_EDITION = NotSupported
        End If
    Else
        Trace("incorrect version number, should be 5.6 or later")
        strMW_EDITION = NotSupported
    End If
    If strMW_EDITION <> NotSupported Then
        Trace(" - passed")
    Else
        Exit Sub
    End If
    
    NotSupported = WMI_NotSupported	
    Trace("WMI check")
    Err.Clear
    If GetHostNameWMI() = "" Then
        Trace "MW_EDITION = NotSupported"
        strMW_EDITION = NotSupported
    End If
    
    If strMW_EDITION <> NotSupported Then
        Trace " - passed"
        Trace "All tests have been passed."
    End If
    Err.Clear
    
End Sub


'***********************************************************************************************
'* Set global variables
'***********************************************************************************************

Sub SetGlobalVariables
    On Error Resume Next
    DEBUG_MODE = False
    Dim WshShell
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set WshShell = CreateObject("WScript.Shell")
    If UCase(WshShell.Environment("PROCESS")("DEBUG_MODE")) = "TRUE" Then DEBUG_MODE = True
    strSCANNER_VERSION = "v" & Version
    strSDC = WshShell.Environment("PROCESS")("SSS_TOOL")
End Sub

'_______________________________________________________________________________________________
'                  Library of additional functions and classes. You can delete it
'_______________________________________________________________________________________________

'***********************************************************************************************
'* Delete temporary folder
'***********************************************************************************************

Sub DeleteTemporaryFolder(ByRef strFolderName)
    
    Dim Folder
    
    If fso.FolderExists(strFolderName) Then
        Set Folder = fso.GetFolder(strFolderName)
        Folder.Delete
    End If
    
End Sub

'***********************************************************************************************
'* Create Directories
'***********************************************************************************************

Sub CreateDirectories(ByRef strCreateDir)
    Dim WshShell, RunVal, strCreateDir1
    Set WshShell = CreateObject("WScript.Shell")
    strCreateDir1 = QuotedPath(WshShell.ExpandEnvironmentStrings(strCreateDir))
    RunVal = WshShell.Run("cmd /c md " & strCreateDir1, 0, True)
    Set WshShell = Nothing
End Sub

'***********************************************************************************************
'* Extract Properties of exe file
'***********************************************************************************************

Function GetFileProperties(strPath, strPropertyType)
    'Software:
    'ApplicationName (Program Name) {F29F85E0-4FF9-1068-AB91-08002B27B3D9}, 18
    'Comment {F29F85E0-4FF9-1068-AB91-08002B27B3D9}, 6
    'Company {D5CDD502-2E9C-101B-9397-08002B2CF9AE}, 15
    'File Description {0CEF7D53-FA64-11D1-A203-0000F81FEDEE}, 3
    'File Version {0CEF7D53-FA64-11D1-A203-0000F81FEDEE}, 4                       3
    'Date Last Used {841E4F90-FF59-4D16-8947-E81BBFFAB36D}, 16
    'Product Name {0CEF7D53-FA64-11D1-A203-0000F81FEDEE}, 7                       1
    'Product Version {0CEF7D53-FA64-11D1-A203-0000F81FEDEE}, 8                    2
    'Version {D5CDD502-2E9C-101B-9397-08002B2CF9AE}, 29
    'Copyright {64440492-4C8B-11D1-8B70-080036B11A03}, 11
    
    On Error Resume Next
    
    Dim objShell, objFolder, objFolderItem, File
    
    Set objShell  = CreateObject("shell.application")
    Set objFolder = objShell.NameSpace(FSO.GetParentFolderName(strPath))
    Set File = FSO.GetFile(strPath)
    
    Trace "ParentFolder = " & fso.GetParentFolderName(strPath) & "   " & "FileName = " & File.ShortName
    
    If (Not objFolder Is Nothing) Then
        Set objFolderItem = objFolder.ParseName(File.ShortName)
        
        Select Case strPropertyType
            Case "Product Name"
            GetFileProperties = objFolderItem.ExtendedProperty("{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 7")
            Case "Product Version"
            GetFileProperties = objFolderItem.ExtendedProperty("{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 8")
            Case "File Version"
            GetFileProperties = objFolderItem.ExtendedProperty("{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 4")
            Case "Version"
            GetFileProperties = objFolderItem.ExtendedProperty("{d5cdd502-2e9c-101b-9397-08002b2cf9ae} 29")
            Case "ApplicationName"
            GetFileProperties = objFolderItem.ExtendedProperty("{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 18")
        End Select
        
        Set objFolderItem = Nothing
    End If
    
    Trace strPropertyType & " = " & GetFileProperties
    
    Set objFolder = Nothing
    Set objShell  = Nothing
End Function

Function QuotedPath(str)
    Const strQuoteMark = """"
    If InStr(str, " ") > 0 Then 
        QuotedPath = strQuoteMark & str & strQuoteMark
    Else
        QuotedPath = str
    End If
End Function

'***********************************************************************************************
'* Read file
'***********************************************************************************************
Function readFile(strFileName)
    Dim WshShell, strFullFileName, fileTXT, str
    
    On Error Resume Next
    Err.Clear
    str = ""
    
    Set WshShell = CreateObject("WScript.Shell")
    strFullFileName = WshShell.ExpandEnvironmentStrings(strFileName)
    Set  WshShell = Nothing
    Trace "Read from file: " &  strFullFileName & "  (" & strFileName& ")"
    
    If fso.FileExists(strFullFileName) Then
        Set fileTXT = fso.OpenTextFile(strFullFileName)
        If Err.Number <> 0 Then
            Trace "readFile: Error #" & Err.Number & " "  & Err.Description
        Else
            If Not fileTXT.AtEndOfStream Then str = fileTXT.ReadAll
            fileTXT.Close()
        End If
        Set fileTXT = Nothing
    Else
        Trace "The file does not exist!" 
    End If
    
    Trace(str)
    readFile = str
    
End Function

Function RunShellCommand(strCommand)
    
    On Error Resume Next
    
    Dim strTempFile, fFile, str, WshShell, strStarterName
    
    Set WshShell = CreateObject("WScript.Shell")
    strTempFile = WshShell.ExpandEnvironmentStrings("%TEMP%\" & FSO.GetTempName)
    
    strCommand = strCommand & "> " & QuotedPath(strTempFile)
    
    Trace strCommand
    
    WshShell.Run strCommand, 0, True
    
    If Err.Number <> 0 Then 
        Trace "RunShellCommand.Run: " & Err.Number & " " & Err.Description
    End If
    
    Set fFile = FSO.OpenTextFile(strTempFile)
    If Err.Number <> 0 Then 
        Trace "RunShellCommand.OpenFile: " & Err.Number & " " & Err.Description
    End If
    
    If Not fFile.AtEndOfStream Then str = fFile.ReadAll
    RunShellCommand = str
    If Err.Number <> 0 Then 
        Trace "RunShellCommand.ReadFile: " & Err.Number & " " & Err.Description
    End If
    fFile.Close
    
    Set fFile = Nothing
    Set WshShell = Nothing
    
    DeleteTemporaryFile(strTempFile)
    
    If Err.Number <> 0 Then 
        Trace "RunShellCommand.DeleteTemporaryFile(" & strTempFile  &"): " & Err.Number & " " & Err.Description
    End If
    
    Trace str
    
    Trace "Check please if this file exists: " & strTempFile 
    Trace "Delete please this file."
End Function

'****The end of the script**
