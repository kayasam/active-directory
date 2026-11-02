"""Import the declared training only; never modify the Obsidian vault."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, unicodedata
from urllib.parse import quote, unquote, urlsplit
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('vault', nargs='?', default=r'C:\Users\kayaw\Nextcloud\Obsidian\CoffreSam\Formations\active-directory')
args = parser.parse_args()
vault = Path(args.vault).resolve()
dest = ROOT/'sources'
documents = [p for p in (vault/'cours').rglob('*.md') if 'excalidraw' not in p.name]
all_files = documents + list((vault/'Ressources/images').glob('*')) + list((vault/'cours/08-tp-final/scripts').glob('*'))
def find(target, origin):
    raw = unquote(target)
    direct = (origin.parent/raw).resolve()
    for p in (direct, Path(str(direct)+'.md'), direct/(direct.name+'.md')):
        if p in all_files: return p
    matches = [p for p in all_files if p.name.casefold()==Path(raw).name.casefold() or p.stem.casefold()==Path(raw).name.casefold()]
    if len(matches)==1: return matches[0]
    raise ValueError(f'Lien ambigu ou absent : {origin.relative_to(vault)} → {target}')
def relative(target, origin):
    import os
    return quote(os.path.relpath(target, origin.parent).replace('\\','/'), safe='/.-')
external = ROOT/'assets/supports/external'
external.mkdir(parents=True, exist_ok=True)
for source in documents:
    text = source.read_text(encoding='utf-8-sig')
    def wiki(m):
        spec = m[2].replace('\\|','|')
        target, _, label = spec.partition('|')
        target, sep, anchor = target.partition('#')
        path = find(target, source)
        return ('!' if m[1] else '')+'['+(label or path.stem)+']('+relative(path,source)+('#'+quote(anchor) if sep else '')+')'
    text = re.sub(r'(!?)\[\[([^\]]+)\]\]',wiki,text)
    def remote_image(m):
        url=m[2]; ext=Path(urlsplit(url).path).suffix.lower()
        assert ext in ('.png','.jpg','.jpeg','.gif','.svg','.webp'), url
        name=hashlib.sha256(url.encode()).hexdigest()[:20]+ext
        output=external/name
        if not output.exists():
            with urlopen(url,timeout=30) as response: output.write_bytes(response.read())
        return m[1]+'asset:external/'+name+m[3]
    text=re.sub(r'(!\[[^\]]*\]\()(https?://[^\s)]+)(\))',remote_image,text)
    output=dest/source.relative_to(vault)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(text,encoding='utf-8',newline='\n')
for source in all_files:
    if source.suffix=='.md': continue
    output=dest/source.relative_to(vault); output.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(source,output)

chapters=[]
for folder in sorted((vault/'cours').iterdir()):
    if folder.name.startswith('08-'):continue
    course=folder/(folder.name+'.md')
    tp=next(p for p in (folder/'tp').glob('*.md') if not p.name.endswith('-correction.md'))
    correction=tp.with_name(tp.stem+'-correction.md')
    chapters.append(dict(slug=folder.name,course=course.relative_to(vault).as_posix(),tp=tp.relative_to(vault).as_posix(),correction=correction.relative_to(vault).as_posix()))
final=vault/'cours/08-tp-final/procedures'
def slug(p):
    text=p.relative_to(final).with_suffix('').as_posix()
    text=unicodedata.normalize('NFKD',text).encode('ascii','ignore').decode().lower()
    return re.sub('[^a-z0-9]+','-',text).strip('-')
chapters.append(dict(slug='08-tp-final',course=(final/'Guide-déploiement-fournil.md').relative_to(vault).as_posix(),tps=[dict(file=p.relative_to(vault).as_posix(),slug=slug(p)) for p in sorted((final/'TP').glob('*.md')) if 'excalidraw' not in p.name]))
annexes=[dict(slug=slug(p),file=p.relative_to(vault).as_posix()) for p in sorted(final.rglob('*.md')) if p.parent.name!='TP' and p.name!='Guide-déploiement-fournil.md']
scripts=list(sorted((vault/'cours/08-tp-final/scripts').glob('*')))
script_index=dest/'cours/08-tp-final/scripts.md'
script_index.write_text('# Scripts et données du projet Fournil\n\nLes scripts et CSV sont regroupés dans `assets/supports/scripts/` du ZIP. Conserver tous les fichiers dans le même dossier avant de les utiliser.\n\n'+'\n'.join('- ['+p.name+'](scripts/'+p.name+')' for p in scripts)+'\n',encoding='utf-8')
annexes.append(dict(slug='scripts-fournil',file='cours/08-tp-final/scripts.md'))
site=dict(title='Active Directory',shortTitle='Active Directory',description='Installer, administrer et dépanner une infrastructure Active Directory, puis réaliser le projet Fournil.',baseUrl='https://cours.kaya.ovh/active-directory',sourceRoot='sources',tracks=[dict(id='ad',title='Active Directory',description='Sept chapitres avec travaux pratiques et un projet final guidé : AD, DFS et GPO.',chapters=chapters,annexe=annexes,hideAnnexe=True)])
(ROOT/'site.json').write_text(json.dumps(site,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'{len(documents)} documents importés ; coffre inchangé.')
