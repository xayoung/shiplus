; ShiPlus Windows Installer Script with Modern UI
!include "MUI2.nsh"

; Basic Settings
Name "ShiPlus"
OutFile "..\build\windows\installer\ShiPlus_Setup.exe"
InstallDir "$PROGRAMFILES64\ShiPlus"

; Request admin rights
RequestExecutionLevel admin

; Define application information
!define PRODUCT_NAME "ShiPlus"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "ShiPlus Team"
!define PRODUCT_WEB_SITE "https://shiplus.com"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\shiplus.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

; Modern UI settings
!define MUI_ABORTWARNING
!define MUI_ICON "..\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME

; License page
!define MUI_LICENSEPAGE_CHECKBOX
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.txt"

; Components page
!insertmacro MUI_PAGE_COMPONENTS

; Directory page
!insertmacro MUI_PAGE_DIRECTORY

; Instfiles page
!insertmacro MUI_PAGE_INSTFILES

; Finish page
!define MUI_FINISHPAGE_RUN "$INSTDIR\shiplus.exe"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.txt"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Language settings
!insertmacro MUI_LANGUAGE "SimpChinese"

; Main program installation
Section "Main Program" SecMain
    SectionIn RO  ; Required component
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
    
    ; Create README file
    FileOpen $0 "$INSTDIR\README.txt" w
    FileWrite $0 "Thank you for installing ShiPlus software!$\r$\n$\r$\n"
    FileWrite $0 "If you have any questions, please visit our website: ${PRODUCT_WEB_SITE}"
    FileClose $0
SectionEnd

; Optional components
Section "Desktop Shortcut" SecDesktop
    CreateShortcut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\shiplus.exe"
SectionEnd

Section "Start Menu Group" SecStartMenu
    CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
    CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\shiplus.exe"
    CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall ${PRODUCT_NAME}.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

; Component descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "ShiPlus main program files"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Create desktop shortcut"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} "Create start menu program group"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; Uninstall section
Section "Uninstall"
    ; Delete installed files
    Delete "$INSTDIR\README.txt"
    Delete "$INSTDIR\shiplus.exe"
    Delete "$INSTDIR\uninstall.exe"
    Delete "$INSTDIR\*.*"
    RMDir /r "$INSTDIR"
    
    ; Delete start menu shortcuts
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall ${PRODUCT_NAME}.lnk"
    RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
    
    ; Delete desktop shortcut
    Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
    
    ; Delete registry keys
    DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
    DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
SectionEnd