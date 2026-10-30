from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'template-manifest.json').read_text(encoding='utf-8'))
for name,sha in manifest['visualFiles'].items():
    assert hashlib.sha256((ROOT/name).read_text(encoding='utf-8').encode('utf-8')).hexdigest()==sha,'Composant visuel modifié : '+name
output=ROOT/'skill/site-formation-quartz/assets';output.mkdir(parents=True,exist_ok=True)
archive=output/'modele-site-formation.zip'
excluded={'.git','node_modules','.pdf-tools','public','output','reference','skill','sources','__pycache__','.template-stage'}
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for path in sorted(ROOT.rglob('*')):
        relative=path.relative_to(ROOT)
        if not path.is_file() or any(part in excluded for part in relative.parts) or path.name.endswith('.tsbuildinfo'):continue
        info=zipfile.ZipInfo(relative.as_posix(),(2026,10,16,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,path.read_bytes())
(output/'modele-site-formation.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'\n')
print(archive,archive.stat().st_size,'octets')
