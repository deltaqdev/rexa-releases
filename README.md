# Rexa releases

Signed, notarized macOS builds of [Rexa](https://rexa.sh), the native desktop
workspace for coding agents. Source lives in a separate, currently private
repository; this one holds only release artifacts and the auto-update
manifests.

## Install

```sh
curl -fsSL https://rexa.sh/install.sh | sh                 # app + rexa CLI
curl -fsSL https://rexa.sh/install.sh | sh -s -- --cli-only
```

Or download a `.dmg` from [rexa.sh/releases](https://rexa.sh/releases) and
drag `Rexa.app` to `/Applications`. The app updates itself from the stable
channel.

## Licensing

Binaries are distributed under the [Apache License 2.0](LICENSE). Each release
attaches `THIRD-PARTY-LICENSES-<version>.md`, the notices for every
open-source component bundled in the app and CLI; the same file ships inside
`Rexa.app/Contents/Resources/`.
