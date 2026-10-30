"""Prepare a configured formation without reading or changing the original vault."""
from pathlib import Path
import hashlib, html, importlib.util, io, json, re, shutil, zipfile, posixpath
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, bytes): path.write_bytes(data)
    else: path.write_text(data, encoding='utf-8', newline='\n')
def digest(data): return hashlib.sha256(data).hexdigest()
def body(text): return re.sub(r'^---\s*\n.*?\n---\s*\n', '', text, count=1, flags=re.S)
def title(text):
    match = re.search(r'^# (.+)$', body(text), re.M)
    if not match: raise ValueError('Chaque cours, TP et annexe doit avoir un titre # Markdown.')
    return match[1]
def published(text):
    front = re.match(r'^---\s*\n(.*?)\n---(?:\n|$)', text, re.S)
    return bool(front and re.search(r'^publier:\s*true\s*$', front[1], re.M | re.I))
def page(label, text): return '---\ntitle: ' + json.dumps(label, ensure_ascii=False) + '\n---\n\n' + text
def clean(path):
    assert path.resolve().parent == ROOT.resolve(), 'Suppression hors du projet interdite'
    if path.exists(): shutil.rmtree(path)
def archive(files):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as z:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2020,1,1,0,0,0)); info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    return stream.getvalue()
def make_pdf(stage, entries, site):
    spec = importlib.util.spec_from_file_location('pdf_renderer', ROOT/'scripts/pdf-renderer.py')
    pdf = importlib.util.module_from_spec(spec); spec.loader.exec_module(pdf)
    pdf.CONTENT = stage; pdf.BASE = site['baseUrl']; pdf.setup_fonts()
    style = pdf.styles(); parts = []
    for entry in entries:
        source = stage / entry['download']
        parsed = pdf.BeautifulSoup(pdf.markdown_html(source.read_text(encoding='utf-8')), 'html.parser')
        stream = io.BytesIO()
        pdf.SimpleDocTemplate(stream, pagesize=pdf.A4, title=entry['title'], author=site['title'], invariant=1).build(pdf.flowables(parsed.children, style, entry['href']))
        parts.append(stream.getvalue())
    intro_pages = 1
    for attempt in range(5):
        story = [pdf.Paragraph(html.escape(site['title']), style['h1']), pdf.Paragraph('Tous les cours — Sommaire', style['h2'])]
        cursor = intro_pages
        for entry, part in zip(entries, parts):
            entry['startPage'] = cursor + 1
            story.append(pdf.Paragraph(html.escape(entry['title']) + ' — p. ' + str(cursor+1), style['p']))
            cursor += len(pdf.PdfReader(io.BytesIO(part)).pages)
        stream = io.BytesIO(); pdf.SimpleDocTemplate(stream, pagesize=pdf.A4, invariant=1).build(story)
        new_pages = len(pdf.PdfReader(io.BytesIO(stream.getvalue())).pages)
        if new_pages == intro_pages: break
        intro_pages = new_pages
    else: raise ValueError('Sommaire PDF non stabilisé')
    writer = pdf.PdfWriter(); writer.append(io.BytesIO(stream.getvalue()))
    for entry, part in zip(entries, parts):
        writer.append(io.BytesIO(part)); writer.add_outline_item(entry['title'], entry['startPage']-1)
    stream = io.BytesIO(); writer.add_metadata({'/Title':site['title']}); writer.write(stream)
    data = stream.getvalue(); write(stage/'telechargements/cours-complets.pdf', data)
    write(stage/'assets/course-pdfs.json', json.dumps({'pdf':'telechargements/cours-complets.pdf','pdfSha256':digest(data),'chapters':entries}, ensure_ascii=False, indent=2))
    return data

def prepare():
    site = json.loads((ROOT/'site.json').read_text(encoding='utf-8-sig'))
    base = site['baseUrl'].rstrip('/'); site['baseUrl'] = base
    url = urlsplit(base)
    assert url.scheme in ('https','http') and url.netloc and not url.query and not url.fragment
    assert site['title'].strip() and site['tracks']
    source_root = (ROOT/site.get('sourceRoot','sources')).resolve()
    def source(name):
        path = (source_root/name).resolve()
        assert path.is_relative_to(source_root) and path.is_file(), f'Source invalide : {name}'
        return path
    chapters = []; annexes = []; routes = {}; keys = set(); tracks = set()
    for track in site['tracks']:
        tid = track['id']; assert re.fullmatch('[a-z0-9]+(?:-[a-z0-9]+)*',tid) and tid not in tracks
        tracks.add(tid); assert track['chapters'], 'Chaque parcours doit contenir un chapitre'
        for chapter in track['chapters']:
            slug = chapter['slug']; assert re.fullmatch(r'\d{2}-[a-z0-9-]+',slug)
            key = tid+'/'+slug; assert key not in keys; keys.add(key)
            item = dict(chapter, key=key, track=tid, href=base+'/'+key+'/', path=source(chapter['course']))
            item['title'] = title(item['path'].read_text(encoding='utf-8-sig'))
            chapters.append(item); routes[item['path']] = item['href']
            for kind in ('html','quiz','tp','correction'):
                if kind in item:
                    path = source(item[kind]); item[kind+'Path'] = path
                    if kind == 'correction' and not published(path.read_text(encoding='utf-8-sig')): continue
                    routes[path] = base+'/'+key+('/tp-corrigev2' if kind=='correction' else '/'+kind)
            assert not ('tp' in chapter and 'tps' in chapter), 'Choisir tp ou tps, pas les deux'
            assert 'correction' not in chapter or 'tp' in chapter, 'Un corrigé nécessite un TP'
            definitions=chapter.get('tps',([{'file':chapter['tp'],'correction':chapter.get('correction')}] if 'tp' in chapter else []))
            item['exercises']=[]
            for definition in definitions:
                tp_path=source(definition['file']); stem=definition.get('slug',tp_path.stem)
                assert re.fullmatch('[a-z0-9-]+',stem)
                exercise_key=key+'/tp'+('/'+stem if len(definitions)>1 else '')
                assert exercise_key not in keys; keys.add(exercise_key)
                corrected=source(definition['correction']) if definition.get('correction') else None
                visible=bool(corrected and published(corrected.read_text(encoding='utf-8-sig')))
                correction_key=key+'/tp/'+stem+'-corrigev2' if len(definitions)>1 else key+'/tp-corrigev2'
                download_stem=chapter['slug']+('-'+stem if len(definitions)>1 else '')
                exercise=dict(key=exercise_key,path=tp_path,correctionPath=corrected,visible=visible,correctionKey=correction_key,downloadStem=download_stem)
                item['exercises'].append(exercise); routes[tp_path]=base+'/'+exercise_key
                if visible: routes[corrected]=base+'/'+correction_key
            if definitions: item['tp']='index'
        for annex in track.get('annexe',[]):
            key=tid+'/annexe/'+annex['slug']; assert re.fullmatch(r'[a-z0-9-]+',annex['slug']) and key not in keys; keys.add(key)
            item=dict(annex,key=key,track=tid,path=source(annex['file']),href=base+'/'+key)
            item['title']=title(item['path'].read_text(encoding='utf-8-sig')); annexes.append(item); routes[item['path']]=item['href']
    offline_names={}
    for item in chapters:
        offline_names[item['path']]=(item['track'],'cours/'+item['slug']+'.md')
        for exercise in item['exercises']:
            offline_names[exercise['path']]=(item['track'],'tp/'+exercise['downloadStem']+'.md')
            corrected=exercise['correctionPath']
            if corrected and corrected in routes: offline_names[corrected]=(item['track'],'tp/'+exercise['downloadStem']+'-corrigev2.md')
    for item in annexes: offline_names[item['path']]=(item['track'],'annexe/'+item['slug']+'.md')
    def attachment(raw, origin):
        parsed = urlsplit(raw)
        if parsed.scheme == 'asset':
            target = (ROOT/'assets/supports'/parsed.path).resolve()
            assert target.is_relative_to((ROOT/'assets/supports').resolve()) and target.is_file(), raw
            return 'assets/supports/'+target.relative_to(ROOT/'assets/supports').as_posix()
        if parsed.scheme or parsed.netloc or not parsed.path: return None
        target = (origin.parent/unquote(parsed.path)).resolve()
        if target in routes: return None
        if target.is_relative_to(source_root) and target.is_file() and target.suffix.lower() in ('.svg','.png','.jpg','.jpeg','.gif','.webp','.ps1','.csv'):
            name = 'scripts/'+target.name if target.suffix.lower() in ('.ps1','.csv') else digest(target.read_bytes())[:20]+target.suffix.lower()
            write(ROOT/'assets/supports'/name,target.read_bytes())
            return 'assets/supports/'+name
        return None
    # Collect attachments before staging, including the TP and published corrections.
    for origin in routes:
        if origin.suffix == '.md':
            for raw in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)\)',origin.read_text(encoding='utf-8-sig')):
                attachment(raw,origin)
    def offline(text,origin):
        track,name=offline_names[origin]
        def link(m):
            parsed=urlsplit(m[2])
            asset=attachment(m[2],origin)
            if asset: return m[1]+posixpath.relpath(asset,posixpath.dirname(name))+m[3]
            if parsed.scheme or parsed.netloc or not parsed.path: return m[0]
            target=(origin.parent/unquote(parsed.path)).resolve()
            if target in offline_names and offline_names[target][0]==track:
                url=posixpath.relpath(offline_names[target][1],posixpath.dirname(name))
                return m[1]+url+('#'+parsed.fragment if parsed.fragment else '')+m[3]
            if target in routes: return m[1]+routes[target]+m[3]
            raise ValueError('Lien hors ligne non déclaré : '+m[2])
        return re.sub(r'(!?\[[^\]]*\]\()([^\s)]+)(\))',link,text)
    # Resolve only declared, publishable documents. Private correction links are rejected.
    def resolve(text, origin):
        def link(m):
            parsed=urlsplit(m[2])
            asset=attachment(m[2],origin)
            if asset: return m[1]+base+'/'+asset+m[3]
            if parsed.scheme or parsed.netloc or not parsed.path: return m[0]
            target=(origin.parent/unquote(parsed.path)).resolve()
            if target in routes: return m[1]+routes[target]+('#'+parsed.fragment if parsed.fragment else '')+m[3]
            raise ValueError(f'Lien local non déclaré : {origin.name} → {m[2]}')
        return re.sub(r'(!?\[[^\]]*\]\()([^\s)]+)(\))',link,text)
    for item in chapters+annexes:
        resolve(body(item['path'].read_text(encoding='utf-8-sig')),item['path'])
    stage=ROOT/'.template-stage'; clean(stage); stage.mkdir()
    shutil.copytree(ROOT/'assets',stage/'assets')
    write(stage/'assets/workshops.json','[]\n'); write(stage/'assets/site.json',json.dumps({'title':site['title'],'shortTitle':site.get('shortTitle',site['title'])}))
    registry={}; quizzes={}; manifest={'chapters':[],'exercises':[],'corrections':[],'tracks':[],'templateVersion':1}
    downloads=[]; pdf_entries=[]
    def without_heading(text): return re.sub(r'^# .+\n*','',body(text),count=1,flags=re.M)
    def download_button(href,label): return '<a class="resource-download" download href="'+html.escape(href,quote=True)+'">↓ '+label+' (.md)</a>'
    for track in site['tracks']:
        files={}; links=[]; tid=track['id']
        for item in [c for c in chapters if c['track']==tid]:
            key=item['key']; label=item['title']; slug=item['slug']; entries=[]
            for kind in ('markdown','html','quiz','tp'):
                if kind!='markdown' and kind not in item: continue
                href=item['href'] if kind=='markdown' else base+'/'+key+'/'+kind+('/' if kind in ('html','quiz') else '')
                captions={'markdown':'Cours','html':'HTML','quiz':'Quiz','tp':'TP'}
                symbol=(ROOT/'assets/resource-icons'/f'{kind}.svg').read_text(encoding='utf-8').replace('<svg ','<svg class="resource-symbol" aria-hidden="true" ',1)
                entries.append(dict(kind=kind,href=href,label=captions[kind],chapterTitle=label,track=tid,symbol=symbol))
            registry[key]=entries
            buttons=''.join('<a class="resource-button" data-resource-kind="'+r['kind']+'" href="'+r['href']+'"><span class="resource-icon">'+r['symbol']+'</span><span class="resource-label">'+r['label']+'</span></a>' for r in entries)
            def bar(download=None): return '<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="'+key+'"><div class="resource-buttons">'+buttons+'</div><div class="resource-actions">'+(download or '')+'<button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>'
            course_text=body(item['path'].read_text(encoding='utf-8-sig'))
            public_text=resolve(course_text,item['path']); relative='telechargements/'+tid+'/cours/'+slug+'.md'
            write(stage/relative,public_text); files['cours/'+slug+'.md']=offline(course_text,item['path'])
            pdf_entries.append(dict(key=key,title=label,href=item['href'],download=relative,sourceSha256=digest(public_text.encode())))
            write(stage/key/'index.md',page(label,bar(download_button(base+'/'+relative,'Télécharger le cours'))+'\n\n'+without_heading(public_text)))
            for kind in ('html','quiz'):
                if kind not in item: continue
                support='cours/'+key+('-interactif.html' if kind=='html' else '-quiz.html')
                if kind=='html':
                    raw=item['htmlPath'].read_text(encoding='utf-8-sig').replace('{{BASE_URL}}',base)
                    offline_html=raw.replace(base+'/assets/','../assets/'); files['cours/'+slug+'.html']=offline_html
                else:
                    bank=json.loads(item['quizPath'].read_text(encoding='utf-8-sig')); questions=bank['questions']; assert len(questions)==20
                    for q in questions: assert len(q['choices'])==4 and 0<=q['answer']<4 and q['explanation']
                    bank.update(id=key,title=label,chapter=label,chapterLink=item['href']); quizzes[key]=bank
                    raw=(ROOT/'quiz-template.html').read_text(encoding='utf-8').replace('__CHAPTER__',key).replace('../../assets/',base+'/assets/').replace('../'+key,item['href']).replace('Linux — Initiation',site['title'])
                    offline_html=raw.replace(base+'/assets/','../assets/').replace(item['href'],slug+'.md'); files['cours/'+slug+'-quiz.html']=offline_html
                write(stage/support,raw)
                frame='<section class="support-viewer" data-course-key="'+key+'" data-support-kind="'+kind+'"><iframe class="support-frame" src="'+base+'/'+support+'" data-support-src="../../../'+support+'" title="'+html.escape(label,quote=True)+'"></iframe></section>'
                write(stage/key/kind/'index.md',page(label+' — '+('HTML interactif' if kind=='html' else 'Quiz'),bar(download_button(base+'/'+relative,'Télécharger le cours'))+'\n'+frame))
            for exercise in item['exercises']:
                tp=exercise['path']; raw=body(tp.read_text(encoding='utf-8-sig')); tp_label=title(raw); tp_url=base+'/'+exercise['key']; download_stem=exercise['downloadStem']
                corrected=exercise['correctionPath']; visible=exercise['visible']
                correction_url=base+'/'+exercise['correctionKey']; nav=''
                if visible:
                    nav='<nav class="exercise-resources" aria-label="Ressources du TP"><a href="'+tp_url+'" aria-current="page">Énoncé</a><a class="exercise-correction" href="'+correction_url+'">Afficher les corrections</a></nav>'
                    correction_text=body(corrected.read_text(encoding='utf-8-sig')); corrected_download='telechargements/'+tid+'/tp/'+download_stem+'-corrigev2.md'
                    correction_public=resolve(correction_text,corrected); write(stage/corrected_download,correction_public)
                    files['tp/'+download_stem+'-corrigev2.md']=offline(correction_text,corrected)
                    raw+='\n\n[Afficher les corrections]('+slug+'-corrigev2.md)\n'
                    correction_nav='<nav class="exercise-resources" aria-label="Ressources du TP"><a href="'+tp_url+'">Énoncé</a><a class="exercise-correction" href="'+correction_url+'" aria-current="page">Corrigé</a></nav>'
                    write(stage/(exercise['correctionKey']+'.md'),page(title(correction_text),bar(download_button(base+'/'+corrected_download,'Télécharger le corrigé'))+'\n'+correction_nav+'\n\n'+without_heading(correction_public)))
                    manifest['corrections'].append(exercise['key'])
                files['tp/'+download_stem+'.md']=offline(body(tp.read_text(encoding='utf-8-sig')),tp)+ ('\n\n[Afficher les corrections]('+download_stem+'-corrigev2.md)\n' if visible else '')
                tp_download='telechargements/'+tid+'/tp/'+download_stem+'.md'
                tp_public=resolve(body(tp.read_text(encoding='utf-8-sig')),tp)
                write(stage/tp_download,tp_public+ ('\n\n[Afficher les corrections]('+correction_url+')\n' if visible else ''))
                write(stage/(exercise['key']+'.md'),page(tp_label,bar(download_button(base+'/'+tp_download,'Télécharger le TP'))+'\n'+nav+'\n\n'+without_heading(tp_public)))
                manifest['exercises'].append(dict(key=exercise['key'],correctionKey=exercise['correctionKey'],downloadStem=download_stem,track=tid,correction=visible))
            if len(item['exercises'])>1:
                listing='\n\n'.join('- ['+title(e['path'].read_text(encoding='utf-8-sig'))+']('+base+'/'+e['key']+')' for e in item['exercises'])
                write(stage/key/'tp.md',page('Travaux pratiques — '+label,bar()+'\n\n'+listing))
            links.append('<a class="home-chapter" href="'+item['href']+'"><span class="home-chapter__number">'+slug[:2]+'</span><strong>'+html.escape(label)+'</strong><span aria-hidden="true">→</span></a>')
            manifest['chapters'].append(dict(key=key,title=label,tp='tp' in item,correction=any(e['visible'] for e in item['exercises'])))
        annex_links=[]
        for item in [a for a in annexes if a['track']==tid]:
            raw=body(item['path'].read_text(encoding='utf-8-sig')); write(stage/(item['key']+'.md'),page(item['title'],without_heading(resolve(raw,item['path'])))); files['annexe/'+item['slug']+'.md']=offline(raw,item['path'])
            annex_links.append('- ['+item['title']+']('+item['href']+')')
        if annex_links: write(stage/tid/'annexe/index.md',page('Annexe','\n\n'.join(annex_links)))
        track_page='<div class="home-chapter-grid">'+''.join(links)+'</div>'+ ('\n\n[Annexe]('+base+'/'+tid+'/annexe/)\n' if annex_links else '')
        write(stage/tid/'index.md',page(track['title'],track_page))
        # Include only published documents and the runtime assets needed offline.
        for asset in (ROOT/'assets').rglob('*'):
            if asset.is_file(): files['assets/'+asset.relative_to(ROOT/'assets').as_posix()]=asset.read_bytes()
        offline_quizzes={key:{**bank,'chapterLink':key.split('/')[-1]+'.md'} for key,bank in quizzes.items() if key.startswith(tid+'/')}
        files['assets/quiz/quiz-banks.js']='window.linuxQuizBanks = '+json.dumps(offline_quizzes,ensure_ascii=False)
        data=archive(files); write(stage/(tid+'-obsidian.zip'),data)
        downloads.append('<a href="'+base+'/'+tid+'-obsidian.zip?v='+digest(data)[:12]+'" download><strong>'+html.escape(track['title'])+'</strong><span>Télécharger le ZIP →</span></a>')
        manifest['tracks'].append(dict(id=tid,title=track['title'],href=base+'/'+tid+'/'))
    write(stage/'assets/course-resources.json',json.dumps(registry,ensure_ascii=False,indent=2)); write(stage/'assets/quiz/quiz-banks.js','window.linuxQuizBanks = '+json.dumps(quizzes,ensure_ascii=False))
    pdf_data=make_pdf(stage,pdf_entries,site)
    downloads.append('<a class="home-pdf-download" href="'+base+'/telechargements/cours-complets.pdf?v='+digest(pdf_data)[:12]+'" download><strong>Tous les cours en PDF</strong><span>Télécharger le PDF →</span></a>')
    home='<header class="home-header"><h1>'+html.escape(site['title'])+'</h1><p>'+html.escape(site.get('description',''))+'</p></header>'
    for track in site['tracks']:
        home+='<section class="home-track"><div class="home-track__head"><div class="home-track__logo"><img src="'+base+'/assets/brands/formation.svg" alt="" /></div><div class="home-track__heading"><h2>'+html.escape(track['title'])+'</h2><p>'+html.escape(track.get('description',''))+'</p></div><a class="home-track__start" href="'+base+'/'+track['id']+'/'+track['chapters'][0]['slug']+'/">Commencer au chapitre 01 →</a></div><div class="home-chapter-grid">'+''.join('<a class="home-chapter" href="'+c['href']+'"><strong>'+html.escape(c['title'])+'</strong><span aria-hidden="true">→</span></a>' for c in chapters if c['track']==track['id'])+'</div></section>'
    home+='<section class="home-downloads"><h2>Supports hors ligne</h2><div class="home-downloads__grid">'+''.join(downloads)+'</div></section>'
    write(stage/'index.md',page(site['title'],home)); write(stage/'assets/publication-manifest.json',json.dumps(manifest,ensure_ascii=False,indent=2)); write(stage/'.generated-template','1\n')
    target=ROOT/'content'
    if target.exists():
        assert (target/'.generated-template').is_file(), 'content contient des fichiers non générés : déplacer les sources avant de préparer.'
        clean(target)
    stage.rename(target)
    config=(ROOT/'quartz.config.yaml').read_text(encoding='utf-8')
    config=re.sub(r'(?m)^  pageTitle:.*$',lambda _:'  pageTitle: '+json.dumps(site['title'],ensure_ascii=False),config)
    config=re.sub(r'(?m)^  baseUrl:.*$',lambda _:'  baseUrl: '+url.netloc+url.path,config)
    config=re.sub(r'      mapFn: >-\n.*?(?=      sortFn:)', '      mapFn: >-\n        function(node) {}\n', config, flags=re.S)
    order={t['id']+'/index':i for i,t in enumerate(site['tracks'])}
    order.update({c['key']+'/index':i for i,c in enumerate(chapters)})
    sort='      sortFn: >-\n        function(a,b) { const rank = '+json.dumps(order)+'; return (rank[a.slug] ?? 999) - (rank[b.slug] ?? 999) || a.displayName.localeCompare(b.displayName, "fr", {numeric:true}); }\n'
    config=re.sub(r'      sortFn: >-\n.*?(?=    layout:)',lambda _:sort,config,flags=re.S)
    write(ROOT/'quartz.config.yaml',config)
    print(f"Préparation : {len(chapters)} chapitres, {len(manifest['corrections'])} corrigés publiés, {len(site['tracks'])} ZIP et un PDF complet.")
if __name__=='__main__': prepare()
