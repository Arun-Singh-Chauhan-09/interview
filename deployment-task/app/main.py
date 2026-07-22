import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = os.getenv("APP_VERSION", "dev")
request_count = 0




class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        global request_count

        if self.path == "/healthz":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok\n")
            return

        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.end_headers()
            metrics = (
                "# HELP app_requests_total Total HTTP requests served.\n"
                "# TYPE app_requests_total counter\n"
                f"app_requests_total {request_count}\n"
                "# HELP app_info Application version info.\n"
                "# TYPE app_info gauge\n"
                f'app_info{{version="{VERSION}"}} 1\n'
            )
            self.wfile.write(metrics.encode())
            return

        request_count += 1
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        body = f"cardmarket demo app\nversion: {VERSION}\npod: {socket.gethostname()}\n"
        self.wfile.write(body.encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"starting version={VERSION} on :8080", flush=True)
    HTTPServer(("", 8080), Handler).serve_forever()
