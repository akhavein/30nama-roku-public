#!/usr/bin/env python3
"""Execute the real recorder against a fake ECP device and accelerated clock."""
import contextlib,io,json,pathlib,runpy,sys,tempfile,unittest.mock as mock
ROOT=pathlib.Path(__file__).resolve().parents[1]

def run(state):
    with tempfile.TemporaryDirectory(prefix='roku-soak-test-') as folder:
        base=pathlib.Path(folder);root=base/'repo'
        (root/'scripts').mkdir(parents=True);(root/'build').mkdir()
        (base/'secrets').mkdir();(base/'secrets/roku-dev.json').write_text('{"host":"fixture.invalid"}')
        script=root/'scripts/soak.py';script.write_text((ROOT/'scripts/soak.py').read_text())
        clock=[0]
        def sleep(seconds):clock[0]+=seconds
        def fetch(url,**kwargs):
            if url.endswith('/active-app'):return io.BytesIO(b'<active-app><app id="dev" /></active-app>')
            position=clock[0]*1000 if state=='play' else 0
            return io.BytesIO(f'<player state="{state}" error="false"><position>{position} ms</position><duration>300000 ms</duration></player>'.encode())
        with mock.patch.object(sys,'argv',[str(script),'--minutes','2','--transitions','0']),mock.patch('urllib.request.urlopen',side_effect=fetch),mock.patch('subprocess.Popen'),mock.patch('signal.signal'),mock.patch('time.monotonic',side_effect=lambda:clock[0]),mock.patch('time.sleep',side_effect=sleep),contextlib.redirect_stdout(io.StringIO()):
            try:runpy.run_path(str(script),run_name='__main__')
            except SystemExit:pass
        return json.loads((root/'build/soak-results.json').read_text())

healthy=run('play');assert healthy['status']=='passed' and healthy['elapsedSeconds']>=120
stalled=run('buffer');assert stalled['status']=='failed' and 'advance' in stalled['failure']
paused=run('pause');assert paused['status']=='failed'
assert healthy['startedAt'] and healthy['updatedAt'] and healthy['expectedEndAt']
print('RECORDER PASS: advancing playback, prolonged buffering, pause, timestamped atomic results')
