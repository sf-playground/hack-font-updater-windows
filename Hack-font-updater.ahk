/*
 * * * Compile_AHK SETTINGS BEGIN * * *

[AHK2EXE]
Exe_File=%In_Dir%\Hack-font-updater.exe
Execution_Level=4
[VERSION]
Set_Version_Info=1
Company_Name=Source Foundry
File_Description=Install and update the Hack font on Windows systems
File_Version=1.0.0.0
Inc_File_Version=0
Internal_Name=hack-font-updater
Legal_Copyright=© 2015 Source Foundry. Licensed under MIT, see LICENSE.
Original_Filename=hack-font-updater
Product_Name=Hack font updater
Product_Version=1.0.0.0

* * * Compile_AHK SETTINGS END * * *
*/

/*
hack-font-updater
=================
*Install and update the Hack font on Windows systems.*
Version 1.0.0

Copyright (C) 2015 Source Foundry

This program is free software: Please read LICENSE.
*/

GetFontVersionFeed() {
  whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
  whr.Open("GET", "https://github.com/chrissimpkins/Hack/releases.atom", true)
  whr.Send()
  Try
    whr.WaitForResponse()
  ; No result? Then we're probably offline
  Catch
    return false
  return whr.ResponseText
}

GetFontVersionFromFeed(feed) {
  where := RegExMatch(feed, "<title>Hack v([\d.]+)</title>", version)
  If where = 0
    return false

  ; matching subpattern
  return version1
}

GetLocalFontFilePath() {
  ; Find out locally installed version
  RegRead, file_path, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts, Hack Regular (TrueType)
  If !file_path
	return false
  return A_Windir "\Fonts\" file_path
}

GetFontVersionFromLocalFile(file_path) {
  IfNotExist, %file_path%
    return false

  ; extract strings from binary font file
  ; using SysInternals strings, see strings-LICENSE.txt
  temp_file := A_Temp "\hack-font-dump.txt"
  cmd := "cmd /c " A_ScriptDir "\strings.exe /accepteula " file_path " > " temp_file
  RunWait, %cmd%, , Hide
  
  ; read strings dump
  FileRead, data, %temp_file%
  FileDelete, %temp_file%
  
  ; find Version string
  where := RegExMatch(data, "Version ([\d.]+);", version)
  If where = 0
    return false

  return version1
}

DownloadFont(version, variant) {
  download := "https://github.com/chrissimpkins/Hack/blob/v" version "/build/ttf/Hack-" variant ".ttf?raw=true"
  target_file := "Hack-" variant "-v" version ".ttf"
  target_path := A_Temp "\" target_file
  UrlDownloadToFile, %download%, %target_path%
}

InstallFont(version, variant, variant_human) {
  ; Install by moving and writing to registry
  font_file := "Hack-" variant "-v" version ".ttf"
  file_path := A_Temp "\" font_file

  target_folder := A_Windir "\Fonts"
  target_path := target_folder "\" font_file
  
  ; FileMove, %file_path%, %target_folder%, 1 ; overwrite
  ; RegWrite, REG_SZ, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts, Hack %variant_human% (TrueType), %font_file%
  ; DllCall("GDI32.DLL\AddFontResource", str, target_path)
  ; msgbox, %errorlevel%

  ; delete old font resource
  RegDelete, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts, Hack %variant_human% (TrueType)

  objShell := ComObjCreate("Shell.Application")
  objFolder := objShell.Namespace(A_Temp)
  objFolderItem := objFolder.ParseName(font_file)
  objFolderItem.InvokeVerb("Install")

  ; send WM_FONTCHANGE to all windows:
  SendMessage,  0x1D,,,, ahk_id 0xFFFF
}

AddConsoleFontZeroKey(zeros) {
  RegRead, font, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont, %zeros%
  If (!font) {
    RegWrite, REG_SZ, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont, %zeros%, Hack
    return true
  }
  If (font = "Hack") {
    return true
  }
  return false
}

AddConsoleFont() {
  If !AddConsoleFontZeroKey("0")
    If !AddConsoleFontZeroKey("00")
      If !AddConsoleFontZeroKey("000")
        If !AddConsoleFontZeroKey("0000")
          If !AddConsoleFontZeroKey("00000")
            AddConsoleFontZeroKey("000000")
}

; MAIN

; Get current version
feed := GetFontVersionFeed()
If feed = false
  Exit
version_current := GetFontVersionFromFeed(feed)
If version_current = false
  Exit

; Get local version
file_path := GetLocalFontFilePath()
If (file_path <> false) {
  ; font is already installed, check its version
  version_local := GetFontVersionFromLocalFile(file_path)

  ; don't update unknown font versions
  If (version_local = false) {
    MsgBox, 0x30, Hack font updater, An existing version of the Hack font is installed, but we couldn't find out which version it is, so we won't overwrite it.
    Exit
  }
  
  If (version_local > version_current) {
    MsgBox, 0x30, Hack font updater, Hack font version %version_local% (newer than online) is installed, so we won't overwrite it.
    Exit
  }
  
  If (version_local = version_current) {
    ; Hack is up-to-date
    Exit
  }
}

DownloadFont(version_current, "Regular")
DownloadFont(version_current, "Italic")
DownloadFont(version_current, "Bold")
DownloadFont(version_current, "BoldItalic")

InstallFont(version_current, "Regular", "Regular")
InstallFont(version_current, "Italic", "Italic")
InstallFont(version_current, "Bold", "Bold")
InstallFont(version_current, "BoldItalic", "Bold Italic")

AddConsoleFont()
