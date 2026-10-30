"""Copy this frozen template into a new, empty project, without a Git remote."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('destination');parser.add_argument('--title',required=True);parser.add_argument('--base-url',required=True);args=parser.parse_args()
target=Path(args.destination).resolve()
if target.exists():raise SystemExit('Destination déjà existante : aucune donnée écrasée.')
baseline=json.loads((ROOT/'template-manifest.json').read_text(encoding='utf-8'))
for name,expected in baseline['visualFiles'].items():
    if hashlib.sha256((ROOT/name).read_text(encoding='utf-8').encode('utf-8')).hexdigest()!=expected:raise SystemExit('Modèle visuel modifié : '+name)
shutil.copytree(ROOT,target,ignore=shutil.ignore_patterns('.git','node_modules','.pdf-tools','public','output','reference','sources','__pycache__','.template-stage','*.tsbuildinfo'))
shutil.copytree(ROOT/'examples',target/'sources')
site=json.loads((target/'site.json').read_text(encoding='utf-8'));site.update(title=args.title,shortTitle=args.title,baseUrl=args.base_url.rstrip('/'))
(target/'site.json').write_text(json.dumps(site,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
subprocess.run(['git','init','-b','main'],cwd=target,check=True)
print(target);print('Aucun origin ajouté. Adapter site.json et sources, puis lancer installer.ps1 et construire.ps1.')
