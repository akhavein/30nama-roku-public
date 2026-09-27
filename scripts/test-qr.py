#!/usr/bin/env python3
"""Compare actual BrightScript QR matrices with independently generated golden data.
Fixtures were cross-checked with Python qrcode 8.2 (byte mode, medium ECC, mask 0).
No provider session or external QR service is used.
"""
import json,pathlib,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
lib='\n'.join(p.read_text() for p in sorted((root/'components/qr').glob('*.brs')))
fixtures=json.loads((root/'tests/qr-fixtures.json').read_text())
for fixture in fixtures:
    with tempfile.TemporaryDirectory(prefix='roku-qr-') as directory:
        script=pathlib.Path(directory)/'qr.brs'
        script.write_text(lib+'\nsub Main()\nq=QrCode()\nq.encodeSegments(q.QrSegment.makeSegments('+json.dumps(fixture['url'])+'),q.Ecc[1],1,6,0,false)\nprint FormatJson(q.modules)\nend sub\n')
        result=subprocess.run([str(root/'node_modules/.bin/brs'),str(script)],cwd=directory,capture_output=True,text=True,timeout=60)
        assert result.returncode==0 and not result.stderr,result.stderr
        matrix=json.loads(result.stdout.strip())
        assert matrix==fixture['matrix'],'QR matrix differs from independent reference'
print(f'REGRESSION PASS: {len(fixtures)} independent QR matrix fixtures')
