; ShiPlus Windows Installer Script
Name "ShiPlus"
OutFile "..\build\windows\installer\ShiPlus_Setup.exe"
InstallDir "$PROGRAMFILES64\ShiPlus"

; Request admin rights
RequestExecutionLevel admin

; Default section
Section
    ; Set output path
    SetOutPath $INSTDIR
    
    ; Copy main program files
    File /r "..\build\windows\x64\runner\Release\*.*"
    
    ; Create start menu shortcuts
    CreateDirectory "$SMPROGRAMS\ShiPlus"
    CreateShortcut "$SMPROGRAMS\ShiPlus\ShiPlus.lnk" "$INSTDIR\shiplus.exe"
    CreateShortcut "$SMPROGRAMS\ShiPlus\Uninstall.lnk" "$INSTDIR\uninstall.exe"
    
    ; Create desktop shortcut
    CreateShortcut "$DESKTOP\ShiPlus.lnk" "$INSTDIR\shiplus.exe"
    
    ; Write uninstall information
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "DisplayName" "ShiPlus"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "InstallLocation" "$\"$INSTDIR$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "DisplayIcon" "$\"$INSTDIR\shiplus.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "Publisher" "ShiPlus"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "DisplayVersion" "1.0.0"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus" "NoRepair" 1
    
    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

; Uninstall section
Section "Uninstall"
    ; Delete installed files
    RMDir /r "$INSTDIR"
    
    ; Delete start menu shortcuts
    Delete "$SMPROGRAMS\ShiPlus\ShiPlus.lnk"
    Delete "$SMPROGRAMS\ShiPlus\Uninstall.lnk"
    RMDir "$SMPROGRAMS\ShiPlus"
    
    ; Delete desktop shortcut
    Delete "$DESKTOP\ShiPlus.lnk"
    
    ; Delete registry keys
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShiPlus"
SectionEnd