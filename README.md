# Rexa releases

Signed, notarized macOS builds of [Rexa](https://rexa.sh), the native desktop
workspace for coding agents, and experimental Windows builds. Source lives in a
separate, currently private repository; this one holds only release artifacts,
the auto-update manifests and the Windows install script.

## Install

```sh
curl -fsSL https://rexa.sh/install.sh | sh                 # app + rexa CLI
curl -fsSL https://rexa.sh/install.sh | sh -s -- --cli-only
```

Or download a `.dmg` from [rexa.sh/releases](https://rexa.sh/releases) and
drag `Rexa.app` to `/Applications`. The app updates itself from the stable
channel.

## Windows (experimental)

Windows support is experimental, so expect bugs. Please report what breaks in
[this repo's issues](https://github.com/deltaqdev/rexa-releases/issues).

Windows 10 or 11 on x64. In PowerShell:

```powershell
irm https://raw.githubusercontent.com/deltaqdev/rexa-releases/main/install.ps1 | iex
```

Options go after the script in this form: `-Version 0.8.0` for a specific
version, `-Force` as below.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/deltaqdev/rexa-releases/main/install.ps1))) -Version 0.8.0
```

The script takes the newest release with a Windows build, checks the
installer's SHA-256 against the digest GitHub lists for it, and runs it
silently. It needs no admin rights and sends nothing anywhere but GitHub.

- The app goes to `%LOCALAPPDATA%\Rexa`, with Start menu and desktop shortcuts.
- `%LOCALAPPDATA%\Rexa\bin` joins your user PATH, so `rexa` works in new
  terminals and in the window you ran the script from.
- The app updates itself from the stable channel. If Rexa is running, the
  script stops: update from inside Rexa, or rerun it in the form above with
  `-Force` to let the installer close Rexa, which ends its terminal sessions.

Windows builds are not code-signed yet. Running a downloaded
`Rexa-<version>-x86_64-pc-windows-msvc-setup.exe` by hand brings up SmartScreen's
"Windows protected your PC": choose **More info**, then **Run anyway**. With
Smart App Control on, Windows may block Rexa until builds are signed.

To uninstall, remove Rexa in **Settings > Apps**, or run:

```powershell
& "$env:LOCALAPPDATA\Rexa\uninstall.exe" /S
```

This removes the app, its shortcuts and its PATH entry. It keeps your
settings (`%APPDATA%\rexa`), app state (`%LOCALAPPDATA%\Rexa`, the same folder
as the app's) and logs (`%LOCALAPPDATA%\rexa_logs`); delete those to remove
everything.

## Licensing

Binaries are distributed under the [Apache License 2.0](LICENSE). Each release
attaches `THIRD-PARTY-LICENSES-<version>.md`, the notices for every
open-source component bundled in the app and CLI; the same file ships inside
`Rexa.app/Contents/Resources/`. The Windows build's notices are
`THIRD-PARTY-LICENSES-<version>-x86_64-pc-windows-msvc.md`, and the install
carries them as `app-<version>\Resources\THIRD-PARTY-LICENSES.md`.
