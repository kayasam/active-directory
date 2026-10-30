$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  if (-not (Test-Path -LiteralPath sources)) { Copy-Item -LiteralPath examples -Destination sources -Recurse }
  & npm ci --no-audit --no-fund
  if ($LASTEXITCODE) { throw 'Installation Node échouée.' }
  & python -m pip install --no-cache-dir --target .pdf-tools -r scripts/requirements-pdf.txt
  if ($LASTEXITCODE) { throw 'Installation PDF échouée.' }
} finally { Pop-Location }
