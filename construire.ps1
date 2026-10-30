$ErrorActionPreference = 'Stop'
$previousUtf8 = $env:PYTHONUTF8
$env:PYTHONUTF8 = '1'
Push-Location $PSScriptRoot
try {
  & python scripts/prepare-site.py
  if ($LASTEXITCODE) { throw 'Préparation échouée.' }
  & node quartz/bootstrap-cli.mjs build
  if ($LASTEXITCODE) { throw 'Construction Quartz échouée.' }
  & python scripts/check-site.py
  if ($LASTEXITCODE) { throw 'Vérifications échouées.' }
} finally { Pop-Location; $env:PYTHONUTF8 = $previousUtf8 }
