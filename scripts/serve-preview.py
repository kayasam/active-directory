from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit
import json,argparse,mimetypes
root=Path(__file__).resolve().parents[1];site=json.loads((root/'site.json').read_text(encoding='utf-8'))
parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8780);args=parser.parse_args()
base=site['baseUrl'].rstrip('/');prefix=urlsplit(base).path.rstrip('/')
class Preview(SimpleHTTPRequestHandler):
    def translate_path(self,path):
        self.directory=str(root/'public')
        if prefix and (path==prefix or path.startswith(prefix+'/')):path=path[len(prefix):] or '/'
        target=super().translate_path(path)
        if not Path(target).exists() and Path(target+'.html').is_file():return target+'.html'
        return target
    def do_GET(self):
        if self.path=='/' and prefix:
            self.send_response(302);self.send_header('Location',prefix+'/');self.end_headers();return
        path=Path(self.translate_path(self.path.split('?',1)[0]))
        if path.is_dir():path=path/'index.html'
        if path.is_file() and path.suffix in ('.html','.js','.css','.json','.svg'):
            data=path.read_text(encoding='utf-8').replace(base,f'http://127.0.0.1:{args.port}{prefix}').encode()
            self.send_response(200);self.send_header('Content-Type',(mimetypes.guess_type(path.name)[0] or 'text/plain')+'; charset=utf-8');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        else:super().do_GET()
    def log_message(self,*args):pass
print(f'Aperçu : http://127.0.0.1:{args.port}{prefix}/',flush=True)
ThreadingHTTPServer(('127.0.0.1',args.port),Preview).serve_forever()
