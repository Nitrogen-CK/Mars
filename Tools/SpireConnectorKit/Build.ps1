param([switch]$Render,[switch]$ValidateOnly,[string]$Blender)
$ErrorActionPreference='Stop'
$kitRoot=$PSScriptRoot
if (-not $Blender) {
    $foundBlender=Get-Command blender -ErrorAction SilentlyContinue
    if ($foundBlender) {$Blender=$foundBlender.Source}
    else {$Blender=Get-ChildItem -LiteralPath "$env:ProgramFiles\Blender Foundation" -Filter blender.exe -Recurse | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName}
}
if (-not $Blender -or -not (Test-Path -LiteralPath $Blender)) {throw 'Blender executable not found; pass -Blender <absolute path>'}
function Invoke-SpireBlender([string[]]$Arguments) {
    & $Blender @Arguments
    if ($LASTEXITCODE -ne 0) {throw "Blender failed with exit code $LASTEXITCODE"}
}
if (-not $ValidateOnly) {
    $buildArgs=@('--background','--python-exit-code','1','--python',"$kitRoot\build_blender.py",'--')
    if (-not $Render) {$buildArgs+='--no-render'}
    Invoke-SpireBlender $buildArgs
}
$savedBlend="$kitRoot\Output\Blender\Spire_Diorama.blend"
foreach ($audit in @('validate_blender.py','validate_clearance.py','catalog.py')) {
    Invoke-SpireBlender @('--background',$savedBlend,'--python-exit-code','1','--python',"$kitRoot\$audit")
}
