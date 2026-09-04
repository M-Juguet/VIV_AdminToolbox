#define MyAppName "VIV Admin Toolbox"
#define MyAppVersion "0.1.6"
#define MyAppPublisher "M-Juguet"
#define MyAppExeName "opsis_app.exe"
#define AppId "{{8E9E40B7-7A2D-4B81-9A32-9F1F350711B8}"

[Setup]
; Identifiant unique pour cette application (ne le modifiez plus jamais)
AppId={#AppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; 'lowest' installe dans %LocalAppData%\Programs au lieu de Program Files. 
; C'est CRUCIAL pour pouvoir mettre à jour sans demander les droits administrateur (UAC) à chaque fois !
PrivilegesRequired=lowest
DefaultDirName={userpf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=.\installers
OutputBaseFilename=opsis_app_v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Ferme automatiquement l'application avant d'écraser les fichiers lors d'une mise à jour
CloseApplications=force
SetupIconFile=windows\runner\resources\app_icon.ico

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
