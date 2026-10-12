<#
Install (or update) the "Mars - Send to Unreal" Blender add-on as its own COPY.

    .\install.ps1                      # every Blender version that already has the add-on, else the newest one
    .\install.ps1 -BlenderVersion 5.2

The add-on used to be a junction into this repo, which made the tool change with the checked-out branch. A copy does
not: Blender runs what was installed, and the add-on hands the Unreal editor its own helper scripts, so neither the
branch nor the project matters. An existing junction is removed (the link only, never what it points at) and replaced
by the copy. Re-run this after editing the source here, then restart Blender or reload its scripts.
#>
param([string]$BlenderVersion = "")

$ErrorActionPreference = "Stop"
$name = "mars_send_to_unreal"
$src = $PSScriptRoot
$root = Join-Path $env:APPDATA "Blender Foundation\Blender"
if (-not (Test-Path $root)) { throw "No Blender user folder at $root" }

if ($BlenderVersion) {
    $versions = @($BlenderVersion)
} else {
    $versions = @(Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "scripts\addons\$name") } |
        ForEach-Object { $_.Name })
    if (-not $versions) {
        $versions = @(Get-ChildItem $root -Directory | Where-Object { $_.Name -match '^\d+\.\d+$' } |
            Sort-Object { [version]$_.Name } | Select-Object -Last 1 | ForEach-Object { $_.Name })
    }
}
if (-not $versions) { throw "No Blender version folder under $root" }

foreach ($v in $versions) {
    $addons = Join-Path $root "$v\scripts\addons"
    $dest = Join-Path $addons $name
    New-Item -ItemType Directory -Force $addons | Out-Null
    if (Test-Path $dest) {
        $item = Get-Item $dest -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # rmdir without /s removes a junction or directory symlink itself and leaves its target alone
            cmd /c rmdir "$dest"
            if (Test-Path $dest) { throw "Could not remove the link $dest" }
            Write-Host "Blender $v : removed the old link (its target was left alone)"
        }
    }
    robocopy $src $dest /MIR /XD __pycache__ /XF install.ps1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $dest (exit $LASTEXITCODE)" }
    $version = (Select-String -Path (Join-Path $dest "__init__.py") -Pattern '"version":\s*\(([^)]*)\)').Matches[0].Groups[1].Value
    Write-Host "Blender $v : installed $name ($($version -replace ',\s*', '.')) as a copy in $dest"
}
Write-Host "Restart Blender (or reload scripts) to load it."
exit 0
