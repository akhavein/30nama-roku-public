import base64, importlib.util, json, pathlib, subprocess, threading, time, unittest, urllib.request, urllib.error
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('preview', pathlib.Path(__file__).with_name('server.py'))
s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
HOST = 'media.example.test'; URL = 'https://' + HOST + '/master.m3u8?private=signed'
MASTER = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=426x240\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080\nhigh.m3u8\n'
PLAYLIST = '#EXTM3U\n#EXTINF:4,\na.ts\n#EXTINF:4,\nb.ts\n#EXT-X-ENDLIST\n'
class Tests(unittest.TestCase):
    def setUp(self):
        s.ALLOWED = {HOST}; s.CACHE.clear(); s.PLAYLISTS.clear()
    def test_url_rejects_private_targets(self):
        for url in ['http://'+HOST+'/', 'https://127.0.0.1/', 'https://'+HOST+'@127.0.0.1/', 'https://'+HOST+':444/', 'https://'+HOST+'/#x', 'https://'+HOST+'/\r\nX:a', 'file:///etc/passwd', 'https://'+HOST+'.evil.test/']:
            with self.subTest(url=url), self.assertRaises(s.Unavailable): s.checked_url(url, s.ALLOWED)
    def test_dns_rejects_mixed_private_answers(self):
        with patch.object(s.socket, 'getaddrinfo', return_value=[(None,None,None,None,('8.8.8.8',443)),(None,None,None,None,('127.0.0.1',443))]):
            with self.assertRaises(s.Unavailable): s.public_addresses(HOST)
    def test_redirect_not_followed(self):
        class Conn:
            def __init__(self,*args):pass
            def request(self,*args,**kw):pass
            def getresponse(self):return type('Response',(),{'status':302})()
            def close(self):pass
        with patch.object(s,'public_addresses',return_value=['8.8.8.8']),patch.object(s,'PinnedHTTPS',Conn):
            with self.assertRaises(s.Unavailable):s.fetch(URL,100,time.monotonic()+3)
    def test_low_bandwidth_variant_only(self):
        self.assertEqual(s.variants(MASTER,URL),[(400000,'https://'+HOST+'/low.m3u8')])
        self.assertEqual(s.variants(MASTER.replace('400000','900000'),URL),[])
    def test_playlist_timeline(self):
        rows=s.segments(PLAYLIST,URL);self.assertEqual([(x[0],x[1]) for x in rows],[(0,4),(4,4)])
    def test_unsupported_playlist_fails_closed(self):
        for tag in ['#EXT-X-KEY:METHOD=AES-128','#EXT-X-MAP:URI="init"','#EXT-X-BYTERANGE:200','#EXT-X-DISCONTINUITY','#EXT-X-GAP']:
            with self.subTest(tag=tag),self.assertRaises(s.Unavailable):s.segments(PLAYLIST+tag,URL)
        for text in [PLAYLIST.replace('#EXT-X-ENDLIST',''),PLAYLIST.replace('4,','nan,'),PLAYLIST.replace('a.ts','https://127.0.0.1/x'),PLAYLIST.replace('4,','999,'),'#EXTM3U\n#EXT-X-ENDLIST']:
            with self.assertRaises(s.Unavailable):s.segments(text,URL)
    def test_invalid_targets_never_fetch(self):
        with patch.object(s,'fetch') as fetch:
            for target in [True,-1,21601,float('nan'),float('inf'),'5']:
                with self.assertRaises(s.Unavailable):s.make_preview(URL,target)
            fetch.assert_not_called()
    def test_expiry_and_cache_limits(self):
        for i in range(30):s.cached_put(s.CACHE,i,{'jpeg':'x'},120,24)
        self.assertEqual(len(s.CACHE),24);self.assertIsNone(s.cached_get(s.CACHE,0))
        s.cached_put(s.CACHE,'expired',{},-1,24);self.assertIsNone(s.cached_get(s.CACHE,'expired'))
    def test_real_decoder_and_cache(self):
        clip=subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-f','lavfi','-i','color=c=blue:s=426x240:r=10','-t','4','-c:v','libx264','-threads','1','-f','mpegts','pipe:1'],capture_output=True,check=True).stdout
        calls=[]
        def fetch(url,*args):
            calls.append(url)
            if 'master' in url:return MASTER.encode()
            if url.endswith('.m3u8'):return PLAYLIST.encode()
            return clip
        with patch.object(s,'fetch',side_effect=fetch):
            result=s.make_preview(URL,2);self.assertTrue(result['success']);self.assertEqual(result['seconds'],2)
            image=base64.b64decode(result['jpeg']);self.assertTrue(image.startswith(b'\xff\xd8'));self.assertTrue(image.endswith(b'\xff\xd9'))
            self.assertEqual(s.make_preview(URL,2),result);self.assertEqual(len(calls),3)
    def test_decoder_failure_never_cached(self):
        with patch.object(s,'fetch',side_effect=[MASTER.encode(),PLAYLIST.encode(),b'corrupt video']):
            with self.assertRaises(s.Unavailable):s.make_preview(URL,1)
        self.assertEqual(len(s.CACHE),0)
    def test_endpoint_auth_validation_and_busy(self):
        s.TOKEN='test-token-not-a-real-secret-0123456789';server=s.Server(('127.0.0.1',0),s.Handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        def request(body,token=s.TOKEN):
            req=urllib.request.Request('http://127.0.0.1:'+str(server.server_port)+'/preview',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+token})
            try:
                with urllib.request.urlopen(req,timeout=3) as r:return r.status,json.load(r)
            except urllib.error.HTTPError as e:
                with e:return e.code,json.load(e)
        try:
            self.assertEqual(request({},'wrong')[0],401)
            self.assertEqual(request({'url':URL,'seconds':1,'extra':True})[0],422)
            s.BUSY.acquire()
            try:self.assertEqual(request({'url':URL,'seconds':1})[0],429)
            finally:s.BUSY.release()
            with patch.object(s,'make_preview',return_value={'success':True,'seconds':1,'jpeg':'test'}):self.assertEqual(request({'url':URL,'seconds':1})[0],200)
        finally:server.shutdown();server.server_close();thread.join()
if __name__=='__main__':unittest.main()
