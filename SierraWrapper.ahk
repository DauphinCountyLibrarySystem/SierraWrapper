/* 	
	Name:		SierraWrapper
	Version:	1.4
	Author:		Lucas Bodnyk (lbodnyk@dcls.org)

	Changelog:

		1.4
		Changed 'remote start' dialogue to be silent so as not to confuse staff, and added zSetToOneToKillAllSierraWrappers so wrapper itself can be managed remotely.
		
		1.3
		Added VxE's 89-character ascii rotation-map encryption algorithm, added comments to configuration file.
		
		1.2
		Fixed some bugs, rewrote logging to be more effective.
	
		1.1
		Added Hammer Mode, to repeatedly connect to the server without logging in.
	
		1.0
		First official release (testing only)


	Notes:
	
		This script draws code from 
			The WinWait framework by berban at http://www.autohotkey.com/board/topic/84397-winwait-framework-do-something-to-a-window-when-it-appears/
			A logging function by atnbueno at http://ahkscript.org/boards/viewtopic.php?t=1264
			libcrypt.ahk by the community at https://github.com/ahkscript/libcrypt.ahk
			And some assorted generic examples from various AHK help sites.
			
			Only libcrypt seems to have been released under license (MIT License 2014)
			
		All variables "should" be prefixed with 'z', for no particularly good reason
		I should have thought it obvious, but you had better be running this on 64-bit. I don't support 32.
		All User Startup is '\\<Machine_Name>\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup', but if you're cool you'll start this by task scheduler.

		[VxE]-89 is a text-friendly encryption method. However, it does not encrypt ascii values that do not occur in the encryption map, i.e.		"',/\`

*/

; ALL THAT MESSY STUFF THAT DOES CRAZY THINGS. HALF OF THIS IS PROBABLY UNNECCESSARY.
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#Persistent ; Keeps a script permanently running (that is, until the user closes it or ExitApp is encountered).
#include libcrypt.ahk
zLocation := RegExReplace(A_ComputerName, "-[\s\S]*$") ; returns everything before (by replacing everything after) the first dash in the machine name
StringLower, zLocation, zLocation
zNumber := RegExReplace(A_ComputerName, "[\s\S]*-") ; returns everything after (by replacing everything before) the last dash in the machine name
zNameWithSpaces := A_ComputerName . "                "
StringLeft, zNameWithSpaces, zNameWithSpaces, 15 ; adds whitespace so the jar log will be justified.
SplitPath, A_ScriptName, , , , ScriptBasename
StringReplace, AppTitle, ScriptBasename, _, %A_SPACE%, All
SysGet, zScreenHeight, 62
OnExit("ExitFunc") ; Register a function to be called on exit

;
;	BEGIN INITIALIZATION SECTION
;

Try {
	Log("")
	Log("   SierraWrapper initializing for machine: " A_ComputerName)
} Catch	{
	MsgBox Testing SierraWrapper.log failed! You probably need to check file permissions. I won't run without my log! Dying now.
	ExitApp
}
If !FileExist("SierraWrapper.ini") {
	Try {
	FileAppend, `n`;	SierraWrapper configuration file `n`; `n`;	Explanation of values: `n`; `n`;	[General]				Most stuff is under this tag. `n`;	zRemoteManagePath=		There should be a RemoteManage.ini at this location. Paths should be enclosed in quotes (""). The wrapper won't start without it - but it can be in a local path`, if you really want... `n`;	zJarLogPath=			If supplied`, the wrapper will log jar errors here. If omitted`, it will use the working directory. `n`;	zLogin=					Our computers are named <loc>-<role>-<num>`, and we log them into Sierra as <loc><num>`, so if you omit this`, it will parse the beginning and end of the machine's name`, stopping at hyphens. `n`;	zHammerMode=			If this is non-zero`, the wrapper will attempt to start Sierra this many times. It won't log in`, though. This is intended to cause jar errors for troubleshooting `n`;	zWindowTitle=			This is the title of the Sierra window once it starts`, and is how the wrapper decides when to login - it's actually possible to fool the wrapper by creating any window with this name. Don't do this. `n`;	zSecret=				This is encrypted with VxE's 89-character ascii rotation-map algorithm. Its integrity is unproven`, and it's using a hardcoded key. I cannot stress enough how inherently insecure this is`, but you're using a program designed to automatically login for you (in fact`, creating a similarly named window like mentioned above could cause it to just type the password into notepad...)`, so I can't imagine you're requiring particularly strong security. Nonetheless`, please make sure the login you're using here is not an admin login. If you put your own value here`, the wrapper will try to login with gibberish. `n`;	zNewPassword=			If you set this`, it will convert the plaintext to an encrypted string under zSecret and delete this line the next time it runs. `n`;	[Test]					There shouldn't be anything under this section. If there is`, the wrapper was interrupted during its startup routine. This should never happen. `n`;	[Log]					This section currently exists only for the following line. `n`;	zClosedClean=			This is set to 0 when the wrapper starts`, and back to 1 when it closes gracefully. It will log anytime it starts with a value of 0 - this usually means that the wrapper task was killed via task manager. `n`; `n`;	Obviously`, if these values aren't set`, you need to set them. `n`;`n`n, SierraWrapper.ini
	MsgBox SierraWrapper.ini did not already exist, so I've made a new one in the working directory. It has some instructions for values you will need to fill out to properly use this program. Please go fill them out and then run the program again.
	Log("!! Configuration file did not exist, warning user and exiting.")
	ExitApp
	} Catch {
	Log("!! Creating SierraWrapper.ini failed! You probably need to check file permissions! I won't run without my ini! Dying now.")
	MsgBox Creating SierraWrapper.ini failed! You probably need to check file permissions! I won't run without my ini! Dying now.
	Exitapp
	}
	}
Try {
	IniWrite, 1, SierraWrapper.ini, Test, zTest
	IniRead, zTest, SierraWrapper.ini, Test, 0
	IniDelete, SierraWrapper.ini, Test, zTest
} Catch {
	Log("!! Testing SierraWrapper.ini failed! You probably need to check file permissions! I won't run without my ini! Dying now.")
	MsgBox Testing SierraWrapper.ini failed! You probably need to check file permissions! I won't run without my ini! Dying now.
	ExitApp
}


IniRead, zClosedClean, SierraWrapper.ini, Log, zClosedClean, 0
IniRead, zRemoteManagePath, SierraWrapper.ini, General, zRemoteManagePath, %A_Space%
IniRead, zJarLogPath, SierraWrapper.ini, General, zJarLogPath, %A_Space%
IniRead, zHammerMode, SierraWrapper.ini, General, zHammerMode, %A_Space%
IniRead, zLogin, SierraWrapper.ini, General, zLogin, %A_Space%
IniRead, zNewPassword, SierraWrapper.ini, General, zNewPassword, %A_Space%
IniRead, zSecret, SierraWrapper.ini, General, zSecret, %A_Space%
IniRead, zWindowTitle, SierraWrapper.ini, General, zWindowTitle, %A_Space%
Log("## zClosedClean="zClosedClean)
Log("## zRemoteManagePath="zRemoteManagePath)
Log("## zJarLogPath="zJarLogPath)
Log("## zHammerMode="zHammerMode)
Log("## zLogin="zLogin)
Log("## zNewPassword="StrLen(zNewPassword) . " characters long!")
Log("## zSecret="zSecret)
Log("## zWindowTitle="zWindowTitle)
If (zClosedClean = 0) {
	Log("!! It is likely that SierraWrapper was terminated without warning.")
	}
If (zRemoteManagePath = "") {
	MsgBox, 4, zRemoteManagePath = "", There is no zRemoteManagePath defined!`nI will run autonomously.`nThis could be dangerous.`n`n Are you sure you want to continue?
        IfMsgBox, No
			Gosub, RemoteManageNo
		IfMsgBox, Yes
			Gosub, RemoteManageYes
	}
If (zJarLogPath = "") {
	zJarLogPath := A_WorkingDir
	Log("-- I will be logging jar errors locally`, to " zJarLogPath)
	}
If (zHammerMode > 0) {
	Log("-- It's Hammer Time! I will attempt to start Sierra " zHammerMode " times.")
	Sleep 100
	FileAppend, %A_YYYY%/%A_MM%/%A_DD% %A_Hour%:%A_Min%:%A_Sec%    %zNameWithSpaces%    Hammer test initializing.`n, %zJarLogPath%%zLocation%-jarlog.txt
	zHammerTimes := zHammerMode
	}	
If (zLogin = "") {
	zLogin := zLocation . zNumber
	Log("-- I will be parsing the machine name`, " zLogin)
	}
If !(zNewPassword = "") {
	Log("-- New password is being encrypted...")
	zNewPassword := Format("{1:64s}", zNewPassword)
	Encrypted89 := LC_VxE_Encrypt89( "22d341f969f910cf1551bd206ebbd3bbcc2d2e7599504aa3e91cca3716d24c04", zSecret:=zNewPassword)
	IniWrite, %zSecret%, SierraWrapper.ini, General, zSecret
	IniDelete, SierraWrapper.ini, General, zNewPassword
	Log("-- Encrypted password written to ini: " zSecret)
	}
If !(zSecret = "") {
	Decrypted89 := LC_VxE_Decrypt89( "22d341f969f910cf1551bd206ebbd3bbcc2d2e7599504aa3e91cca3716d24c04", zDecrypted:=zSecret)
	zDecrypted := RegExReplace(zDecrypted, "^\s*")
	}
If (zSecret = "") {
	Log("-- No password supplied. Well I guess I can try 'password'...")
	zSecret := "password"
	}
If (zWindowTitle = "") {
	zWindowTitle := "Sierra - "
	Log("-- No window title specified`, defaulting to " zWindowTitle)
	}

IniWrite, 0, SierraWrapper.ini, Log, zClosedClean
	
;
;	STARTUP SECTION
;

Log("== Starting Main...")

;Gosub, TryToStart
;Log("-- Got the go-ahead from RemoteManagePath`, starting...")

WinMinimizeAll
CoordMode, Mouse, Screen
Click (A_ScreenWidth // 2), (A_ScreenHeight // 2) ; this might not be necessary, but it seems to help WinWait.

SetTimer, CheckForExe, 5000 ; 5 seconds
SetTimer, CheckForKill, 300000 ; 5 minutes

; This is the WinWait framework. It does things when windows appear. It's pretty awesome.
;==================================================Configuration==================================================

WA_CheckNewTitles = %True% ; Will check each window again if its title changes. False will only check again once a window (as identified by ahk_id) loses focus.
WA_TitleMatchMode = 2 ; Title match mode for the first and second column of WA_Definitions.

; A = Continue action until window goes away
; B = Once each time window becomes active
; C = Once for each window only

WA_Definitions = ; A tab-delimited table with four columns. The 2nd column (wintext) may be omitted for any entries
(
;WinTitle1	WinText1	A	Action1
;Notepad					C	LogNote
Jar Error				C	LogJar
%zWindowTitle%				C	SierraIsOpen
Login Failed			C				LoginFailed
)

;====================================================================================================

SetWinDelay, -1                                                               ; Removes the normal delay which occurs after the script waits for a window to become active
WA_Definitions := RegExReplace(WA_Definitions, "\t\K\t+")                     ; Turns the plain text table into an array of single-tab-delimited lists
DetectHiddenWindows, On                                                       ; Necessary to detect all C windows that already exist
SetTitleMatchMode, %WA_TitleMatchMode%
WA_Excluded := ",", WA_Count := 0
Loop, Parse, WA_Definitions, `n, `r                                           ; Parses the table
{
    WA_Count += 1
    StringSplit, WA_%WA_Count%_, A_LoopField, %A_Tab%                         ; Splits each item, creating a two-dimensional pseudoarray
    If (WA_%WA_Count%_4 = "")                                                 ; If the WinText parameter has been omitted then the variables are adjusted accordingly
        WA_%WA_Count%_4 := WA_%WA_Count%_3, WA_%WA_Count%_3 := WA_%WA_Count%_2, WA_%WA_Count%_2 := ""
    If WA_%WA_Count%_3 Not In A,B,C                                           ; If the third column isn't A, B, or C, then that row is ignored
        WA_%WA_Count%_4 := "", WA_Count -= 1
    Else If (WA_%WA_Count%_3 = "C") {                                         ; If the third column is C (only once per window), then find all windows that currently match the criteria and add them to the excluded list
        WinGet, @, List, % WA_%WA_Count%_1, % WA_%WA_Count%_2
        Loop, %@%
            WA_Excluded .= WA_Count @%A_Index% ","
    }
}
WA_Definitions := WA_Title := ""                                              ; Clear the definitions variable
DetectHiddenWindows, Off
SetTimer, WA_Loop, -500                                                       ; Sets a timer so that changing TitleMatchMode won't be considered in the auto-execute portion of the script and consequently won't affect your subroutines
Return

WA_Loop:
Loop {                                                                        ; Infinite loop to check for new active windows
    FoundA := False
    Sleep 40                                                                  ; Wait a small amount of time for the next window to become active. Not sure if this is really necessary or not. At the very least it keeps a buggy category A definition from using 100% of the CPU
    WinGet, WA_ID, ID, A                                                      ; Stores the HWND of the active window for later use
    If WA_CheckNewTitles {
        WinGetTitle, WA_Title, ahk_id %WA_ID%
        SetTitleMatchMode, %WA_TitleMatchMode%                                ; Turn off type 3 title match mode
    }
    Loop %WA_Count%                                                           ; Loop through each row of the table and see if the active window is one that you are searching for.
    {
        IfWinActive, % WA_%A_Index%_1 " ahk_id " WA_ID, % WA_%A_Index%_2      ; If WinActive() for this criteria evaluates true, then take action
        {
            If WA_%A_Index%_3 = A                                             ; If a window of category A has been found, remember this. This will allow the function to repeat the action once it tests for other criteria.
                FoundA := True
            Else If WA_%A_Index%_3 = C                                        ; If the category of this window is C and it's been seen before, then ignore it
            {
                If InStr(WA_Excluded, "," A_Index WA_ID ",")
                    Continue
                WA_Excluded .= A_Index WA_ID ","                              ; Otherwise add its HWND to the list of excluded windows and then take the specified action
            }
            Else If Holds =                                                   ; If it is not A or C it is B
                Holds := WA_ID "," A_Index ","                                ; %Holds% remembers which B actions have triggered for this instance of the specific window
            Else If (InStr(Holds, WA_ID) = 1) and InStr(Holds, "," A_Index ",")
                Continue
            Else
                Holds .= A_Index ","
            Do(WA_%A_Index%_4)                                                ; Carry out the action
            Sleep 50                                                          
        }
    }
    If FoundA                                                                 ; If there was an A action that matched, return to the top so it can be repeated
        Continue
    If WA_CheckNewTitles                                                      ; If title changes are being monitored, set the title match mode to be EXACT
        SetTitleMatchMode, 3
    WinWaitNotActive, %WA_Title% ahk_id %WA_ID%                               ; Wait for the title to change, or for a different window to become active.
    Holds =                                                                   ; Reset holds when the window changes
}                                                                             ; Start over

;==================================================Required function==================================================

Do(Action)
{
    Loop, Parse, Action, CSV
    {
        Transform, Cmd, Deref, %A_LoopField%
        Func := False, RegExMatch(Cmd, "s)^(?P<Name>\w*)(?:\((?P<Func>.*?)\)|,? ?(?P<Input>.*))$", Cmd)
        If CmdFunc and IsFunc(CmdName)
        { ; Will attempt to use a function if you used function notation, i.e. Command(Input1,Input2,Input3)
            Loop, Parse, CmdFunc, CSV
                CmdFunc%A_Index% := A_LoopField, n := A_Index
            Func := True, FuncReturn := !n ? %CmdName%() : n = 1 ? %CmdName%(CmdFunc1) : n = 2 ? %CmdName%(CmdFunc1, CmdFunc2) : n = 3 ? %CmdName%(CmdFunc1, CmdFunc2, CmdFunc3) : n = 4 ? %CmdName%(CmdFunc1, CmdFunc2, CmdFunc3, CmdFunc4) : n = 5 ? %CmdName%(CmdFunc1, CmdFunc2, CmdFunc3, CmdFunc4, CmdFunc5) : n = 6 ? %CmdName%(CmdFunc1, CmdFunc2, CmdFunc3, CmdFunc4, CmdFunc5, CmdFunc6) : n = 7 ? %CmdName%(CmdFunc1, CmdFunc2, CmdFunc3, CmdFunc4, CmdFunc5, CmdFunc6, CmdFunc7) : IsFunc(@ := "Error") ? %@%("Too many parameters (" n ") passed to function " A_ThisFunc "()!") : ""
        }
        Else If CmdName = Run
        {
            Run, %CmdInput%, , UseErrorLevel
            If ErrorLevel
                ToolTip, %A_ScriptName%, Could not run "%CmdInput%"
        }
        Else If CmdName = Send
        {
            Send, %CmdInput%
        }
        Else If CmdName = SendInput
        {
            SendInput, %CmdInput%
        }
        Else If CmdName = Goto
        {
            SetTimer, %CmdInput%, -1
        }
        Else If CmdName = Gosub
        {
            Gosub, %CmdInput%
        }
        Else If CmdName = Sleep
        {
            Sleep, %CmdInput%
        }
        Else If IsLabel(RegExReplace(Cmd, "\s"))
        {
            SetTimer, % RegExReplace(Cmd, "\s"), -1
        }
        Else If IsFunc(CmdName)
        {
            %CmdName%(CmdInput)
        }
        Else
        {
            Send %Cmd%
        }
    }
    If Func
        Return FuncReturn
}
; End of WinWait

LogJar:
	;WinGetText, jarError, ahk_id %WA_ID% ; This isn't working, probably because Java.
	FileAppend, %A_YYYY%/%A_MM%/%A_DD% %A_Hour%:%A_Min%:%A_Sec%    %zNameWithSpaces%    Jar Error Detected.`n, %zJarLogPath%%zLocation%-jarlog.txt
	Sleep 100
	Log("jj Jar Error Detected.")
	Progress, W600 zh0 fm20 fs16 y200, Hold on a moment, I'm going to restart Sierra, Jar error detected.
	Sleep 1000
	Progress, Off
	Process, Close, iiirunner.exe
	Process, Close, javaw.exe
	return

LoginFailed:
	If ProcessExist("iiirunner.exe") {
		FileAppend, %A_YYYY%/%A_MM%/%A_DD% %A_Hour%:%A_Min%:%A_Sec%    %zNameWithSpaces%    Login Failed. Please contact Innovative.`n, %zJarLogPath%%zLocation%-jarlog.txt
		Sleep 100
		Log("ll Login Failed. Please contact Innovative.")
		Progress, W600 zh0 fm20 fs16 y200, Hold on a moment, I'm going to restart Sierra, Login failed.
		Sleep 1000
		Progress, Off
		Process, Close, iiirunner.exe
		Process, Close, javaw.exe
	}
return

ProgressOff:
Progress, Off
Return

CheckForExe:
    If !ProcessExist("iiirunner.exe") {
		GoSub, TryToStart
		Log("-- I don't think Sierra is running - I will try to start it.")
		Progress, W600 zh0 fm20 fs16 y200, I don't think Sierra is running - I will try to start it.`nThe application may take several minutes to start.`nPlease be patient., Please do not touch anything.
		SetTimer, ProgressOff, 300000
		Run, C:\Sierra Desktop App\iiirunner.exe, C:\Sierra Desktop App
	}
	return
	
CheckForKill:
	IniRead, zSetToOneToKillAllSierraWrappers, %zRemoteManagePath%RemoteManage.ini, Die, zSetToOneToKillAllSierraWrappers
	If (zSetToOneToKillAllSierraWrappers = "1") {
	Log("!! zSetToOneToKillAllSierraWrappers was set to 1, dying now.")
	ExitApp
	}
	return

SierraIsOpen:
	If (zHammerMode > 0) {
		If (--zHammerTimes > 0) {
			Log("HH Sierra seems to have started, but I'd rather keep hammerin'. Killing Sierra now.")
			Process, Close, iiirunner.exe
			Process, Close, javaw.exe
			Return
			}
		Else {
			FileAppend, %A_YYYY%/%A_MM%/%A_DD% %A_Hour%:%A_Min%:%A_Sec%    %zNameWithSpaces%    Hammer test finished.`n, %zJarLogPath%%zLocation%-jarlog.txt
			Sleep 100
			Log("HH Sierra seems to have started, but I'm out of steam! Exiting now...")
			Process, Close, iiirunner.exe
			Process, Close, javaw.exe
			ExitApp
		}
		}
	Else {
		Gosub, LoginToSierra
	}
	Return

TryToStart:
	IniRead, zAllowedToStart, %zRemoteManagePath%RemoteManage.ini, Start, zAllowedToStart
	If (zAllowedToStart != "1")	{
		Log("** zAllowedToStart=0`, retry in 300 seconds...")
		Sleep, 300000
		Goto, TryToStart
	}
	Else {
	Return
	}
	
MsgBox This Should Never Happen
	
LoginToSierra:
	Blockinput On
	Log("-- Sierra seems to have started. Trying to log in...")
	Progress, W600 zh0 fm20 fs16 y200, Sierra seems to have started.`nTrying to Log in..., Please do not touch anything.
	SetTimer, ProgressOff, 5000
	ifWinExist, %zWindowTitle%
	{
		WinActivate, %zWindowTitle%
		Sleep 1000
		IfWinActive, %zWindowTitle%
		{
			Send %zLogin%
			Sleep 250
			Send {Tab}
			Sleep 250
			SendRaw %zDecrypted%
			Sleep 250
			Send {Enter}
		}
	}
	Blockinput Off
	return

ProcessExist(Name){
	Process,Exist,%Name%
	return Errorlevel
}

; functions to log and notify what's happening, courtesy of atnbueno
Log(Message, Type="1") ; Type=1 shows an info icon, Type=2 a warning one, and Type=3 an error one ; I'm not implementing this right now, since I already have custom markers everywhere.
{
	global ScriptBasename, AppTitle
	IfEqual, Type, 2
		Message = WW: %Message%
	IfEqual, Type, 3
		Message = EE: %Message%
	IfEqual, Message, 
		FileAppend, `n, %ScriptBasename%.log
	Else
		FileAppend, %A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%%A_Tab%%Message%`n, %ScriptBasename%.log
	Sleep 50 ; Hopefully gives the filesystem time to write the file before logging again
	Type += 16
	;TrayTip, %AppTitle%, %Message%, , %Type% ; Useful for testing, but in production this will confuse my users.
	;SetTimer, HideTrayTip, 1000
	Return
	HideTrayTip:
	SetTimer, HideTrayTip, Off
	TrayTip
	Return
}
LogAndExit(message, Type=1)
{
	global ScriptBasename
	Log(message, Type)
	FileAppend, `n, %ScriptBasename%.log
	Sleep 1000
	ExitApp
}

RemoteManageNo:
	Log("!! no zRemoteManagePath defined`, dying now.")
	ExitApp

RemoteManageYes:
	Log("!! User forced startup despite no zRemoteManagePath")
	return

ExitFunc(ExitReason, ExitCode)
{
    if ExitReason in Exit
	{
		IniWrite, 1, SierraWrapper.ini, Log, zClosedClean
	}
	if ExitReason in Menu
    {
        MsgBox, 4, , This will kill Sierra.`nAre you sure you want to exit?
        IfMsgBox, No
            return 1  ; OnExit functions must return non-zero to prevent exit.
		Process, Close, iiirunner.exe
		Process, Close, javaw.exe
		IniWrite, 1, SierraWrapper.ini, Log, zClosedClean
		Log("-- User is exiting SierraWrapper`, dying now.")
    }
	if ExitReason in Logoff,Shutdown
	{
		Process, Close, iiirunner.exe
		Process, Close, javaw.exe
		IniWrite, 1, SierraWrapper.ini, Log, zClosedClean
		Log("-- System logoff or shutdown in process`, dying now.")
	}
		if ExitReason in Close
	{
		Process, Close, iiirunner.exe
		Process, Close, javaw.exe
		IniWrite, 1, SierraWrapper.ini, Log, zClosedClean
		Log("!! The system issued a WM_CLOSE or WM_QUIT`, or some other unusual termination is taking place`, dying now.")
	}
		if ExitReason not in Close,Exit,Logoff,Menu,Shutdown
	{
		Process, Close, iiirunner.exe
		Process, Close, javaw.exe
		IniWrite, 1, SierraWrapper.ini, Log, zClosedClean
		Log("!! I am closing unusually`, with ExitReason: " ExitReason ", dying now.")
	}
    ; Do not call ExitApp -- that would prevent other OnExit functions from being called.
}