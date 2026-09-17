from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('directory')
parser.add_argument('--port', type=int, default=8765)
args = parser.parse_args()

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=args.directory, **kw)

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()

ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
