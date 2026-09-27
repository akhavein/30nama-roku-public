#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('account-prefs');s=q.expect('autoplay setting available',lambda s:s.get('page')=='account' and len(s.get('items',[]))>=5)
original=s['autoplay'];q.keys('Down','Down','Down','Select');q.expect('autoplay setting changes',lambda s:s.get('autoplay')!=original)
q.launch('account-prefs');q.expect('autoplay setting persists after relaunch',lambda s:s.get('page')=='account' and s.get('autoplay')!=original)
q.keys('Down','Down','Down','Select');q.expect('autoplay setting restored',lambda s:s.get('autoplay')==original)
(q.ROOT/'build/qa-preferences-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
