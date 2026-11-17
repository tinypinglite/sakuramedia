; SakuraMedia Windows 安装脚本（Inno Setup 6）。
; CI 调用方式（版本号从 git tag 注入，路径由 workflow 解析为绝对路径）：
;   ISCC.exe /DMyAppVersion=0.7.5 /DReleaseDir=... /DSetupIcon=... /DOutputDir=... packaging\windows\sakuramedia.iss
; 打包内容为 build\windows\x64\runner\Release 下的全部文件；VC++ 运行时 DLL 由 workflow 在编译前补入该目录。

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef ReleaseDir
  #define ReleaseDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef SetupIcon
  #define SetupIcon "..\..\windows\runner\resources\app_icon.ico"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

#define MyAppName "SakuraMedia"
#define MyAppExeName "sakuramedia.exe"

[Setup]
AppId={{58615EC5-DC04-40C2-B206-A9BD91979B2E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\SakuraMedia
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=sakuramedia-windows-v{#MyAppVersion}-setup-unsigned
SetupIconFile={#SetupIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent
