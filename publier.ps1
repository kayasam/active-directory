param([switch]$Push,[string]$Message='Mettre à jour la formation')
$ErrorActionPreference='Stop'
& "$PSScriptRoot/construire.ps1"
if (-not $Push) { Write-Host 'Version locale prête. Pour publier sur votre dépôt : ./publier.ps1 -Push'; return }
Push-Location $PSScriptRoot
try {
  & git remote get-url origin
  if ($LASTEXITCODE) { throw 'Définir origin sur le dépôt de cette formation avant publication.' }
  # sources/ is ignored: private corrections never enter the published Git repository.
  & git add -- .
  if ($LASTEXITCODE) { throw 'git add échoué.' }
  if (git diff --cached --name-only) {
    & git commit -m $Message
    if ($LASTEXITCODE) { throw 'Commit échoué.' }
  }
  & git push -u origin main
  if ($LASTEXITCODE) { throw 'Push échoué.' }
} finally { Pop-Location }
