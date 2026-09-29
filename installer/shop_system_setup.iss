; =====================================================================
; Inno Setup Script for Shop System POS (Flutter Desktop Application)
; =====================================================================

#define MyAppName "Shop System"
#define MyAppArabicName "نظام إدارة ونقاط بيع الملابس"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "Shop System Inc."
#define MyAppExeName "shop_system.exe"
#define MyAppIcon "..\windows\runner\resources\app_icon.ico"
#define SourceBuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{9B850231-5E36-4F1A-B829-923DB44A2059}
AppName={#MyAppName} ({#MyAppArabicName})
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ShopSystem
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\build\installer
OutputBaseFilename=ShopSystem_v{#MyAppVersion}_Setup_x64
SetupIconFile={#MyAppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "تشغيل البرنامج تلقائياً مع بدء تشغيل الويندوز"; GroupDescription: "خيارات إضافية:"; Flags: unchecked

[Files]
; All Flutter Release Output Files & Subdirectories
Source: "{#SourceBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Extra Essential Redistributables
Source: "redist\d3dcompiler_47.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\إلغاء التثبيت ({#MyAppName})"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName} - {#MyAppArabicName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Flags: waituntilterminated skipifdoesntexist runascurrentuser; StatusMsg: "جاري تثبيت مكتبات Microsoft Visual C++ Runtime..."
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\flutter_assets"
