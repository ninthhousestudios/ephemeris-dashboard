; Inno Setup script for Ephemeris Dashboard (swe_dashboard)
; SPDX-License-Identifier: AGPL-3.0-or-later
; Copyright (C) 2026 Ninth House Studios LLC
;
; Build the app first, then compile this script:
;   1) flutter build windows --release
;   2) Open this file in the Inno Setup Compiler (ISCC) and press Build,
;      or from a shell:  iscc installer\ephemeris-dashboard.iss
;
; Output: installer\Output\EphemerisDashboard-<version>-Setup.exe
;
; Requires Inno Setup 6 (https://jrsoftware.org/isdl.php).
; Paths below are relative to THIS .iss file (the installer\ directory), so the
; repository root is "..".

#define MyAppName "Ephemeris Dashboard"
#define MyAppVersion "2.1.0"
#define MyAppPublisher "Ninth House Studios LLC"
#define MyAppURL "https://ninthhouse.studio"
#define MyAppExeName "ephemeris_dashboard.exe"
; Where `flutter build windows --release` drops the bundle:
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; A stable, unique GUID identifies this application for upgrades and uninstall.
; Never reuse it for a different product.
AppId={{42f2a32a-668d-4a83-ba31-5e1d882e52a7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
VersionInfoVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Flutter Windows builds are 64-bit only.
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
LicenseFile=..\LICENSE
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputDir=Output
OutputBaseFilename=EphemerisDashboard-{#MyAppVersion}-Setup
; Per-machine install (Program Files) needs admin; use lowest for per-user.
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The Flutter release bundle: the exe, flutter_windows.dll, every plugin DLL,
; and the data\ folder (assets, icudtl.dat). recursesubdirs pulls in data\.
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*"; DestDir: "{app}"; Excludes: "{#MyAppExeName}"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- Visual C++ runtime -----------------------------------------------------
; Flutter release apps need the MSVC runtime (vcruntime140*.dll, msvcp140.dll).
; Most Windows machines already have it via the Visual C++ Redistributable, but
; a clean machine may not. To bundle it, drop vc_redist.x64.exe next to this
; script and uncomment the two lines below (and the [Run] entry).
; Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Silent VC++ redist install, if bundled above.
; Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ runtime..."; Check: VCRedistNeeded
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Returns True when the MSVC runtime is not already registered, so the bundled
// redist only runs when it is actually missing. Used by the commented [Run].
function VCRedistNeeded(): Boolean;
var
  Installed: Cardinal;
begin
  Result := not (
    RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed)
    and (Installed = 1));
end;
