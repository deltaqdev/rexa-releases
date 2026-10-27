# Rexa installer for Windows (experimental). Finds the newest release with a
# Windows build, verifies its SHA-256 against the release asset's digest, and
# runs the per-user installer silently. See docs/updates.md, Windows install script.
#
#   irm https://raw.githubusercontent.com/deltaqdev/rexa-releases/main/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/deltaqdev/rexa-releases/main/install.ps1))) -Version 0.8.0
#
# -Repo reads another repo's releases and -Path installs a local setup.exe,
# both for testing. GITHUB_TOKEN, when set, raises the GitHub API rate limit.
# ASCII only: Windows PowerShell 5.1 reads a BOM-less script file as ANSI.
# Prefixed names: under `irm | iex` these land in the user's session.
param(
    # A release version such as 0.8.0; empty takes the newest with a Windows build.
    [Alias('Version')] [string]$RexaVersion = '',
    [Alias('Repo')] [string]$RexaRepo = 'deltaqdev/rexa-releases',
    # A Rexa-<version>-x86_64-pc-windows-msvc-setup.exe on disk, installed as is.
    [Alias('Path')] [string]$RexaPath = '',
    # Let the installer close a running Rexa, ending every terminal it holds.
    [Alias('Force')] [switch]$RexaForce
)

function Write-RexaStage([string]$Message) {
    Write-Host "==> $Message"
}

function Invoke-RexaApi([string]$Uri) {
    $headers = @{ Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
    if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
    try {
        Invoke-RestMethod -Uri $Uri -Headers $headers -UseBasicParsing
    } catch {
        $status = [int]$_.Exception.Response.StatusCode
        if ($status -eq 404) { return $null }
        if (-not $status) { throw "Could not reach GitHub's API at ${Uri}: $($_.Exception.Message)" }
        $detail = "$($_.ErrorDetails.Message)"
        if ($status -eq 429 -or $detail -match 'rate limit') {
            throw "GitHub's API rate limit is used up for now ($Uri). Try again within the hour, or set GITHUB_TOKEN."
        }
        if ($status -eq 401 -and $env:GITHUB_TOKEN) {
            throw "GitHub rejected the GITHUB_TOKEN in your environment ($Uri, 401). Unset or replace it."
        }
        throw "GitHub's API refused $Uri ($status): $detail"
    }
}

# The release's Windows installer, or $null when it ships none.
function Select-RexaPackage($Release) {
    $version = $Release.tag_name -replace '^v', ''
    $name = "Rexa-$version-x86_64-pc-windows-msvc-setup.exe"
    $asset = @($Release.assets) | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $asset) { return $null }
    if ("$($asset.digest)" -notmatch '^sha256:([0-9a-f]{64})$') {
        throw "$RexaRepo lists no SHA-256 digest for $name, so it cannot be verified. Nothing was installed."
    }
    [pscustomobject]@{
        Version = $version
        Name    = $name
        Url     = $asset.browser_download_url
        Size    = $asset.size
        Sha256  = $Matches[1]
        Source  = $Release.html_url
        File    = $null
    }
}

function Get-RexaReleasePackage {
    $api = "https://api.github.com/repos/$RexaRepo/releases"
    if ($RexaVersion) {
        $tag = 'v' + ($RexaVersion -replace '^v', '')
        Write-RexaStage "Fetching Rexa $tag from $RexaRepo..."
        $release = Invoke-RexaApi "$api/tags/$tag"
        if (-not $release) { throw "$RexaRepo has no release $tag." }
        $package = Select-RexaPackage $release
        if (-not $package) { throw "Rexa $tag has no Windows build." }
        return $package
    }
    Write-RexaStage "Finding the newest Rexa release with a Windows build in $RexaRepo..."
    $releases = Invoke-RexaApi "${api}?per_page=100"
    foreach ($release in @($releases)) {
        if ($release.draft -or $release.prerelease) { continue }
        $package = Select-RexaPackage $release
        if ($package) { return $package }
    }
    throw "No release in $RexaRepo ships a Windows build yet."
}

function Get-RexaLocalPackage {
    $item = Get-Item -LiteralPath $RexaPath -ErrorAction SilentlyContinue
    if (-not $item) { throw "No file at $RexaPath." }
    if ($item.Name -notmatch '^Rexa-(.+)-x86_64-pc-windows-msvc-setup\.exe$') {
        throw "$($item.Name) is not named like a Rexa installer (Rexa-<version>-x86_64-pc-windows-msvc-setup.exe)."
    }
    [pscustomobject]@{
        Version = $Matches[1]
        Name    = $item.Name
        Url     = $null
        Size    = $item.Length
        Sha256  = $null
        Source  = $item.FullName
        File    = $item.FullName
    }
}

# The per-user install the NSIS installer registered, or $null.
function Get-RexaInstall {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Rexa'
    $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
    if (-not $entry) { return $null }
    [pscustomobject]@{
        Version     = "$($entry.DisplayVersion)"
        Root        = "$($entry.InstallLocation)".Trim('"')
        Uninstaller = "$($entry.UninstallString)".Trim('"')
    }
}

function Test-RexaNewer([string]$Installed, [string]$Target) {
    $left = $null
    $right = $null
    if (-not [version]::TryParse(($Installed -replace '-.*$', ''), [ref]$left)) { return $false }
    if (-not [version]::TryParse(($Target -replace '-.*$', ''), [ref]$right)) { return $false }
    $left -gt $right
}

function Assert-RexaCanInstall($Package, $Installed) {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Rexa needs 64-bit Windows.' }
    if ($Installed -and (Test-RexaNewer $Installed.Version $Package.Version)) {
        throw "Rexa $($Installed.Version) is installed, newer than $($Package.Version). Uninstall it first to go back."
    }
    Assert-RexaNotRunning
}

# The installer closes every Rexa.exe it finds, the terminal host too, which
# outlives the window so terminals survive a quit.
function Assert-RexaNotRunning {
    $running = @(Get-Process -Name Rexa -ErrorAction SilentlyContinue)
    if ($running.Count -eq 0 -or $RexaForce) { return }
    throw ("Rexa is running: $($running.Count) Rexa.exe, counting the terminal host that stays after its window closes. " +
        'Update from inside Rexa, which keeps your terminals, or pass -Force to let the installer close it and end every terminal session: ' +
        '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/deltaqdev/rexa-releases/main/install.ps1))) -Force')
}

function Save-RexaInstaller($Package, [string]$Directory) {
    if ($Package.File) { return $Package.File }
    $file = Join-Path $Directory $Package.Name
    Write-RexaStage ("Downloading {0} ({1:N0} MB)..." -f $Package.Name, ($Package.Size / 1MB))
    try {
        Invoke-WebRequest -Uri $Package.Url -OutFile $file -UseBasicParsing
    } catch {
        throw "Could not download $($Package.Url): $($_.Exception.Message)"
    }
    Write-RexaStage 'Verifying SHA-256...'
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Package.Sha256) {
        throw "SHA-256 mismatch for $($Package.Name): got $actual, the release lists $($Package.Sha256). Nothing was installed."
    }
    $file
}

function Invoke-RexaInstaller([string]$File, $Package, $Installed) {
    if (-not $Installed) { Write-RexaStage "Installing Rexa $($Package.Version)..." }
    elseif ($Installed.Version -eq $Package.Version) { Write-RexaStage "Reinstalling Rexa $($Package.Version)..." }
    else { Write-RexaStage "Updating Rexa $($Installed.Version) to $($Package.Version)..." }
    # Again: Rexa may have started during the download.
    Assert-RexaNotRunning
    $process = Start-Process -FilePath $File -ArgumentList '/S' -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "The installer exited with code $($process.ExitCode)." }
}

function Assert-RexaInstalled($Package) {
    $installed = Get-RexaInstall
    if (-not $installed) { throw 'The installer finished, but Settings > Apps lists no Rexa.' }
    if ($installed.Version -ne $Package.Version) {
        throw "The installer finished, but Settings > Apps lists Rexa $($installed.Version), not $($Package.Version)."
    }
    $cli = Join-Path $installed.Root 'bin\rexa.exe'
    if (-not (Test-Path -LiteralPath $cli)) { throw "The installer finished, but $cli is missing." }
    $installed
}

# The installer puts bin\ on the user PATH; this window still has the old one.
function Update-RexaSessionPath([string]$Bin) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (($userPath -split ';') -contains $Bin)) {
        Write-Host "Warning: $Bin is not on your user PATH; add it to run rexa from a terminal." -ForegroundColor Yellow
        return
    }
    if (-not (($env:Path -split ';') -contains $Bin)) { $env:Path = "$env:Path;$Bin" }
    Write-Host "rexa is on your user PATH ($Bin); this window and new terminals have it."
}

function Install-Rexa {
    $ErrorActionPreference = 'Stop'
    # Windows PowerShell's progress bar slows Invoke-WebRequest several times over.
    $ProgressPreference = 'SilentlyContinue'
    if ($RexaPath) { $package = Get-RexaLocalPackage } else { $package = Get-RexaReleasePackage }
    $before = Get-RexaInstall
    Assert-RexaCanInstall $package $before
    $directory = Join-Path ([IO.Path]::GetTempPath()) ('rexa-install-' + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $directory | Out-Null
    try {
        $file = Save-RexaInstaller $package $directory
        Invoke-RexaInstaller $file $package $before
    } finally {
        Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
    }
    $installed = Assert-RexaInstalled $package
    Write-Host "Installed Rexa $($package.Version) to $($installed.Root)"
    Write-Host "  from $($package.Source)"
    if ($package.Sha256) { Write-Host "  SHA-256 $($package.Sha256), as the release lists" }
    Update-RexaSessionPath (Join-Path $installed.Root 'bin')
    Write-Host 'Start Rexa from the Start menu or the desktop shortcut.'
    Write-Host "Uninstall from Settings > Apps, or run: & `"$($installed.Uninstaller)`" /S"
    Write-Host 'Done.'
}

try {
    Install-Rexa
} catch {
    Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
    $global:LASTEXITCODE = 1
    # A script run exits non-zero; `irm | iex` must leave the user's window open.
    if ($PSCommandPath) { exit 1 }
}
