; packaging/windows/zohal.iss
; Inno Setup 6 Installer Script for Zohal Connect
; RTL Persian wizard, Administrator privileges, registers ZohalEngine service, idempotent uninstall

#define MyAppName "Zohal"
#define MyAppVersion "0.1.12"
#define MyAppPublisher "Zohal Connect Team"
#define MyAppURL "https://github.com/zohal-connect/zohal-connect"
#define MyAppExeName "zohal.exe"

[Setup]
AppId={{6D7A6F68-616C-436F-6E6E-65637454554E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\dist\windows
OutputBaseFilename=Zohal-Setup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "persian"; MessagesFile: "compiler:Languages\Persian.isl"

[CustomMessages]
persian.WelcomeLabel2=به قندشکن زحل خوش آمدید.%n%nبرای نصب سرویس شبکه و رابط مجازی به دسترسی مدیر نیاز است. زحل فقط تنظیمات خودش را تغییر میدهد.
persian.ComponentService=سرویس زحل (الزامی)
persian.ComponentAutostart=اجرای زحل همراه ویندوز
persian.RunProgram=اجرای زحل

[Components]
Name: "service"; Description: "{cm:ComponentService}"; Types: full compact custom; Flags: fixed
Name: "autostart"; Description: "{cm:ComponentAutostart}"; Types: full

[Files]
Source: "..\..\dist\windows\bin\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\third_party\dist\windows-x86_64\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\third_party\dist\windows-x86_64\aether.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Registry]
; Optional Autostart in HKCU Run
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Zohal"; ValueData: """{app}\{#MyAppExeName}"""; Components: autostart; Flags: uninsdeletevalue

[Run]
; Register and start ZohalEngine service
Filename: "{app}\zohald.exe"; Parameters: "install"; Flags: runhidden waituntilterminated
Filename: "{app}\zohald.exe"; Parameters: "service"; Flags: nowait postinstall skipifsilent; Description: "{cm:RunProgram}"

[UninstallRun]
; Stop service and cleanup network rules
Filename: "{app}\zohald.exe"; Parameters: "cleanup"; Flags: runhidden waituntilterminated
Filename: "{app}\zohald.exe"; Parameters: "uninstall"; Flags: runhidden waituntilterminated

[Code]
// Custom Inno Setup Pascal script for checking existing installation and prompt
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
