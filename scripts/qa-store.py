#!/usr/bin/env python3
"""Native Store deep-link acceptance, using only the isolated synthetic app."""
import importlib.util
import json
import os
import pathlib
import time
import urllib.parse
import urllib.request
import uuid

spec = importlib.util.spec_from_file_location('acceptance', pathlib.Path(__file__).with_name('qa-acceptance.py'))
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
origin = 'http://' + os.environ['ROKU_QA_DEVICE'] + ':8060'

def post(path, params=None):
    url = origin + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    urllib.request.urlopen(urllib.request.Request(url, data=b''), timeout=10).read()

def cold(content, kind, signedout=False):
    post('/keypress/Home')
    time.sleep(.7)
    q.run_id = uuid.uuid4().hex
    q.mark()
    post('/launch/dev', {'scenario': 'store-signedout' if signedout else 'store-ready',
                        'qaRun': q.run_id, 'contentId': content, 'mediaType': kind})

def warm(content, kind):
    q.mark()
    post('/input', {'contentId': content, 'mediaType': kind})

def playing(title, episode=None):
    return lambda s: s.get('player') == 'playing' and s.get('titleid') == title and (episode is None or s.get('episode') == episode)

try:
    cold('101', 'movie')
    q.expect('cold movie launches directly into native playback', playing(101), 15)
    q.expect('launch completion beacon reported after player ready', lambda s: s.get('storereported'), 5)
    warm('201:12', 'episode')
    q.expect('warm exact episode replaces movie', playing(201, 12), 15)
    warm('201:21', 'season')
    q.expect('season link opens episodes without autoplay', lambda s: s.get('page') == 'episodes' and s.get('episode') == 21, 10)
    warm('201:99', 'episode')
    q.expect('missing episode falls back safely', lambda s: s.get('page') == 'home' and "isn't available" in s.get('status', ''), 10)
    warm('https://example.invalid', 'movie')
    q.expect('URL is rejected as content ID', lambda s: s.get('page') == 'home' and not s.get('storepending'), 5)
    cold('201:12', 'episode')
    q.expect('cold exact episode bypasses title chooser', playing(201, 12), 15)
    cold('201:22', 'series')
    q.expect('unwatched series starts first regular episode', playing(201, 11), 15)
    warm('118', 'movie')
    time.sleep(.25)
    warm('201:21', 'episode')
    q.expect('latest rapid link wins over slow old request', playing(201, 21), 15)
    time.sleep(4.5)
    q.expect('late old reply cannot replace current episode', playing(201, 21), 3)
    cold('101', 'movie', signedout=True)
    q.expect('signed-out link waits for login', lambda s: s.get('storepending') and s.get('page') == 'account' and bool(s.get('message')), 10)
    q.mark()
    q.keys('Back')
    q.expect('cancel sign-in clears pending link', lambda s: not s.get('storepending') and s.get('page') == 'account', 8)
    q.keys('Back')
    q.expect('Back from account returns Home', lambda s: s.get('page') == 'home', 8)
    q.keys('Back')
    active = urllib.request.urlopen(origin + '/query/active-app', timeout=5).read().decode()
    deadline = time.monotonic() + 5
    while 'id="dev"' in active and time.monotonic() < deadline:
        time.sleep(.2)
        active = urllib.request.urlopen(origin + '/query/active-app', timeout=5).read().decode()
    assert 'id="dev"' not in active, 'Home Back did not exit to Roku'
    q.results.append({'test': 'Home Back exits app', 'passed': True})
    print('STORE DEVICE PASS', len(q.results), flush=True)
finally:
    (q.ROOT / 'build/qa-store-results.json').write_text(json.dumps(q.results, indent=2))
