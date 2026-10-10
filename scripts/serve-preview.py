"""Serve local Blazor output on loopback only, with SPA route fallback."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8765)
parser.add_argument('--root', type=Path, required=True)
args = parser.parse_args()
root = args.root.resolve()

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *handler_args, **kwargs):
        super().__init__(*handler_args, directory=str(root), **kwargs)

    def log_request(self, code='-', size='-'):
        # Keep asset requests from filling the terminal pipe during previews.
        # Errors still use the normal HTTP server logging.
        if isinstance(code, int) and code >= 400:
            super().log_request(code, size)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        requested = self.path.split('?', 1)[0]
        if not Path(requested).suffix and not Path(self.translate_path(self.path)).exists():
            self.path = '/index.html'
        super().do_GET()

print(f'Local preview: http://127.0.0.1:{args.port}/', flush=True)
class PreviewServer(ThreadingHTTPServer):
    # Blazor loads many WASM files in parallel, including across preview tabs.
    request_queue_size = 128

PreviewServer(('127.0.0.1', args.port), Handler).serve_forever()
