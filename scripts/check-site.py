"""Check output links, publication boundaries, downloads and frozen visual assets."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import hashlib, json, re, shutil, zipfile, posixpath, sys
ROOT=Path(__file__).resolve().parents[1]
site=json.loads((ROOT/'site.json').read_text(encoding='utf-8')); base=site['baseUrl'].rstrip('/'); configured=urlsplit(base)
content=ROOT/'content'; public=ROOT/'public'
for source in content.rglob('*'):
    if source.is_file() and (source.suffix!='.md' or 'telechargements' in source.parts) and not source.name.startswith('.'):
        target=public/source.relative_to(content);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[]
    def handle_starttag(self,tag,attrs):
        self.links.extend(value for key,value in attrs if key in ('href','src','data-support-src') and value)
errors=[]; checked=0
for page in public.rglob('*.html'):
    parser=Links();parser.feed(page.read_text(encoding='utf-8'))
    for link in parser.links:
        url=urlsplit(link)
        if url.scheme and url.scheme not in ('http','https'):continue
        if url.netloc and url.netloc!=configured.netloc:continue
        if not url.path:continue
        path=unquote(url.path)
        if path.startswith(configured.path+'/'):path=path[len(configured.path)+1:]
        elif path==configured.path:path=''
        elif path.startswith('/'):errors.append((str(page),link));continue
        else:path=posixpath.normpath((page.relative_to(public).parent/path).as_posix())
        target=public/path
        if not any(p.is_file() for p in [target,target/'index.html',Path(str(target)+'.html')]):errors.append((str(page.relative_to(public)),link))
        checked+=1
assert not errors, '\n'.join(map(str,errors[:20]))
manifest=json.loads((content/'assets/publication-manifest.json').read_text(encoding='utf-8'))
for entry in manifest['exercises']:
    page=(content/(entry['key']+'.md')).read_text(encoding='utf-8')
    assert ('Afficher les corrections</a>' in page)==entry['correction'],entry['key']
    assert '/tp/' in re.search(r'class="resource-download"[^>]*href="([^"]+)"',page)[1]
    prose=re.sub(r'^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$', '', page, flags=re.M|re.S)
    label=json.loads(re.search(r'^title: (.+)$',page,re.M)[1])
    assert '# '+label not in prose.splitlines(), entry['key']
    correction=content/(entry['correctionKey']+'.md')
    assert correction.exists()==entry['correction'],entry['key']
    if correction.exists():
        assert '> [!success]-' in correction.read_text(encoding='utf-8'), 'Corrigé v2 sans réponse repliée'
for track in manifest['tracks']:
    with zipfile.ZipFile(content/(track['id']+'-obsidian.zip')) as z:
        names=z.namelist()
        for entry in [e for e in manifest['exercises'] if e['track']==track['id']]:
            slug=entry['downloadStem']
            assert ('tp/'+slug+'-corrigev2.md' in names)==entry['correction']
        for name in names:
            if not name.endswith('.md'):continue
            for link in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',z.read(name).decode('utf-8')):
                url=urlsplit(link)
                if url.scheme or url.netloc or not url.path:continue
                assert posixpath.normpath(posixpath.join(posixpath.dirname(name),unquote(url.path))) in names,(name,link)
pdfs=list(public.rglob('*.pdf'));assert pdfs==[public/'telechargements/cours-complets.pdf']
pdf_manifest=json.loads((content/'assets/course-pdfs.json').read_text(encoding='utf-8'))
assert hashlib.sha256(pdfs[0].read_bytes()).hexdigest()==pdf_manifest['pdfSha256']
sys.path.insert(0,str(ROOT/'.pdf-tools'));from pypdf import PdfReader
assert len(PdfReader(pdfs[0]).outline)==len(manifest['chapters'])
home=(content/'index.md').read_text(encoding='utf-8')
for file in [*content.glob('*.zip'),content/'telechargements/cours-complets.pdf']:
    assert '?v='+hashlib.sha256(file.read_bytes()).hexdigest()[:12] in home
print(f'{checked} liens valides ; corrigés privés exclus ; boutons conditionnels ; ZIP, PDF unique et cache conformes.')
