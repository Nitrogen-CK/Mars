param([switch]$ValidateOnly,[string]$Blender='C:\Program Files\Blender Foundation\Blender 5.2\blender.exe')
$ErrorActionPreference='Stop'
if (-not $ValidateOnly) {
    & $Blender --background --python-exit-code 1 --python "$PSScriptRoot\build_service.py"
    if ($LASTEXITCODE -ne 0) {throw "Steward art build failed: $LASTEXITCODE"}
}
& $Blender --background --python-exit-code 1 --python "$PSScriptRoot\validate_exports.py"
if ($LASTEXITCODE -ne 0) {throw "Steward art export validation failed: $LASTEXITCODE"}
