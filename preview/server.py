"""Private, on-demand HLS scene previews. No account tokens or URL logging."""
import base64, hashlib, hmac, http.client, ipaddress, json, math, os, re
import socket, ssl, subprocess, threading, time, urllib.parse
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Unavailable(Exception):
    pass

ALLOWED = set(filter(None, os.environ.get('PREVIEW_HOSTS', '').split(',')))
TOKEN = os.environ.get('HELPER_BEARER_TOKEN', '')
LIMIT = 3 * 1024 * 1024
BUSY = threading.BoundedSemaphore(1)
CACHE = OrderedDict()
PLAYLISTS = OrderedDict()

def checked_url(url, hosts):
    if not isinstance(url, str) or len(url) > 4096 or any(ord(x) < 33 or ord(x) > 126 for x in url):
        raise Unavailable()
    try:
        p = urllib.parse.urlsplit(url)
        if p.scheme != 'https' or p.hostname not in hosts or p.username or p.password or p.port not in (None, 443) or p.fragment:
            raise Unavailable()
    except ValueError:
        raise Unavailable()
    return p

def public_addresses(host):
    addresses = list(dict.fromkeys(x[4][0] for x in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)))
    if not addresses or any(not ipaddress.ip_address(x).is_global for x in addresses):
        raise Unavailable()
    return addresses

class PinnedHTTPS(http.client.HTTPSConnection):
    def __init__(self, host, address, timeout):
        super().__init__(host, timeout=timeout, context=ssl.create_default_context())
        self.address = address
    def connect(self):
        raw = socket.create_connection((self.address, 443), self.timeout)
        try:
            self.sock = self._context.wrap_socket(raw, server_hostname=self.host)
        except Exception:
            raw.close()
            raise

def fetch(url, limit, deadline):
    p = checked_url(url, ALLOWED)
    addresses = public_addresses(p.hostname)
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise Unavailable()
    connection = PinnedHTTPS(p.hostname, addresses[0], min(3, remaining))
    try:
        connection.request('GET', urllib.parse.urlunsplit(('', '', p.path or '/', p.query, '')), headers={'Accept-Encoding': 'identity'})
        response = connection.getresponse()
        if response.status != 200 or int(response.getheader('Content-Length', '0')) > limit:
            raise Unavailable()
        body = bytearray()
        while True:
            if time.monotonic() >= deadline:
                raise Unavailable()
            if connection.sock is not None:
                connection.sock.settimeout(min(3, max(0.1, deadline - time.monotonic())))
            chunk = response.read1(min(65536, limit + 1 - len(body)))
            if not chunk:
                return bytes(body)
            body.extend(chunk)
            if len(body) > limit:
                raise Unavailable()
    finally:
        connection.close()

def variants(text, base):
    rows = []; info = None
    for line in text.splitlines():
        if line.startswith('#EXT-X-STREAM-INF:'):
            info = dict(re.findall(r'([A-Z-]+)=("[^"]*"|[^,]+)', line))
        elif line and not line.startswith('#') and info:
            try:
                bandwidth = int(info['BANDWIDTH']); width, height = map(int, info['RESOLUTION'].split('x'))
                if 0 < bandwidth <= 800000 and 0 < width <= 640 and 0 < height <= 480:
                    rows.append((bandwidth, urllib.parse.urljoin(base, line)))
            except (KeyError, ValueError):
                pass
            info = None
    return sorted(rows)

def segments(text, base):
    if not text.startswith('#EXTM3U') or '#EXT-X-ENDLIST' not in text:
        raise Unavailable()
    if any(x in text for x in ['#EXT-X-KEY', '#EXT-X-MAP', '#EXT-X-BYTERANGE', '#EXT-X-DISCONTINUITY', '#EXT-X-GAP']):
        raise Unavailable()
    rows = []; duration = 0.0; length = None
    for line in text.splitlines():
        if line.startswith('#EXTINF:'):
            try:
                length = float(line.split(':', 1)[1].split(',')[0])
                if not math.isfinite(length) or not 0 < length <= 15:
                    raise Unavailable()
            except ValueError:
                raise Unavailable()
        elif line and not line.startswith('#'):
            if length is None:
                raise Unavailable()
            url = urllib.parse.urljoin(base, line)
            checked_url(url, ALLOWED)
            rows.append((duration, length, url)); duration += length; length = None
            if len(rows) > 10000 or duration > 21600:
                raise Unavailable()
    if not rows:
        raise Unavailable()
    return rows

def cached_get(cache, key):
    value = cache.get(key)
    if value and time.monotonic() < value[0]:
        cache.move_to_end(key)
        return value[1]
    cache.pop(key, None)
    return None

def cached_put(cache, key, value, ttl, maximum):
    cache[key] = (time.monotonic() + ttl, value); cache.move_to_end(key)
    while len(cache) > maximum:
        cache.popitem(last=False)

def make_preview(url, target):
    checked_url(url, ALLOWED)
    if isinstance(target, bool) or not isinstance(target, (int, float)) or not math.isfinite(target) or not 0 <= target <= 21600:
        raise Unavailable()
    target = int(target)
    key = hashlib.sha256((url + '\n' + str(target)).encode()).digest()
    cached = cached_get(CACHE, key)
    if cached:
        return cached
    deadline = time.monotonic() + 8
    playlist_key = hashlib.sha256(url.encode()).digest()
    rows = cached_get(PLAYLISTS, playlist_key)
    if rows is None:
        master = fetch(url, 262144, deadline).decode('utf8')
        options = variants(master, url)
        if not options:
            raise Unavailable()  # Never download a high-bandwidth direct rendition.
        variant = options[0][1]
        rows = segments(fetch(variant, 1048576, deadline).decode('utf8'), variant)
        cached_put(PLAYLISTS, playlist_key, rows, 60, 2)
    row = next((x for x in rows if x[0] <= target < x[0] + x[1]), None)
    if row is None:
        raise Unavailable()
    media = fetch(row[2], LIMIT, deadline)
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise Unavailable()
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-threads', '1', '-filter_threads', '1',
           '-protocol_whitelist', 'pipe', '-f', 'mpegts', '-i', 'pipe:0', '-ss', str(target - row[0]),
           '-frames:v', '1', '-an', '-sn', '-vf', 'scale=320:180:force_original_aspect_ratio=decrease,pad=320:180:(ow-iw)/2:(oh-ih)/2',
           '-threads', '1', '-f', 'image2pipe', '-c:v', 'mjpeg', '-q:v', '5', 'pipe:1']
    result = subprocess.run(cmd, input=media, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=min(3, remaining), check=False, env={'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'LANG': 'C'})
    image = result.stdout
    if result.returncode or not image.startswith(b'\xff\xd8') or not image.endswith(b'\xff\xd9') or not 0 < len(image) <= 100000:
        raise Unavailable()
    payload = {'success': True, 'seconds': target, 'jpeg': base64.b64encode(image).decode()}
    cached_put(CACHE, key, payload, 120, 24)
    return payload

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass
    def setup(self):
        super().setup(); self.connection.settimeout(4)
    def answer(self, status, body):
        data = json.dumps(body, separators=(',', ':')).encode()
        self.send_response(status); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data))); self.send_header('Cache-Control', 'no-store')
        self.send_header('Connection', 'close'); self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass
    def do_POST(self):
        if not TOKEN or not hmac.compare_digest(self.headers.get('Authorization', '').encode('utf8'), ('Bearer ' + TOKEN).encode('utf8')):
            self.answer(401, {'success': False}); return
        if self.path != '/preview':
            self.answer(404, {'success': False}); return
        try:
            size = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            size = 0
        if not 0 < size <= 6144 or self.headers.get('Transfer-Encoding'):
            self.answer(400, {'success': False}); return
        if not BUSY.acquire(blocking=False):
            self.answer(429, {'success': False}); return
        try:
            raw = self.rfile.read(size)
            if len(raw) != size:
                raise Unavailable()
            body = json.loads(raw)
            if not isinstance(body, dict) or set(body) != {'url', 'seconds'}:
                raise Unavailable()
            self.answer(200, make_preview(body['url'], body['seconds']))
        except Exception:
            self.answer(422, {'success': False})
        finally:
            BUSY.release()
    def do_GET(self):
        self.answer(404, {'success': False})

# Bound idle/unauthorized request threads too, not just FFmpeg work.
class Server(ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, *args):
        super().__init__(*args); self.slots = threading.BoundedSemaphore(8)
    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request); return
        try:
            super().process_request(request, address)
        except Exception:
            self.slots.release(); raise
    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()

if __name__ == '__main__':
    if len(TOKEN) < 24 or not ALLOWED:
        raise SystemExit('Preview configuration missing')
    Server((os.environ.get('PREVIEW_BIND', '127.0.0.1'), int(os.environ.get('PREVIEW_PORT', '8790'))), Handler).serve_forever()
