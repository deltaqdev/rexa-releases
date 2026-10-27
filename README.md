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

On Windows 10 or 11 (x64), in PowerShell:

```powershell
irm https://raw.githubusercontent.com/deltaqdev/rexa-releases/main/install.ps1 | iex
```

It installs the newest Windows build for your user and puts `rexa` on your
PATH; the app updates itself after that. Builds aren't code-signed yet, so
Windows may warn before running them. Uninstall from **Settings > Apps**.

## Licensing

Binaries are distributed under the [Apache License 2.0](LICENSE). Each release
attaches `THIRD-PARTY-LICENSES-<version>.md`, the notices for every
open-source component bundled in the app and CLI; the same file ships inside
`Rexa.app/Contents/Resources/`. The Windows build's notices are
`THIRD-PARTY-LICENSES-<version>-x86_64-pc-windows-msvc.md`, and the install
carries them as `app-<version>\Resources\THIRD-PARTY-LICENSES.md`.
