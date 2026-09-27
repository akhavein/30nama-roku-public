#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('stream:110');q.expect('bad primary source falls back to stereo',lambda s:s.get('player')=='playing' and s.get('sourceindex')==1,25)
q.launch('stream:111');q.expect('source picker fixture starts',lambda s:s.get('player')=='playing' and s.get('sourcecount')==2,15)
q.keys('Play');q.expect('source switch starts paused',lambda s:s.get('player')=='paused')
q.keys('Right','Right','Right','Right','Right','Right','Select');q.expect('source picker opened',lambda s:s.get('tracks'))
q.keys('Down','Select');q.expect('manual source switch preserves pause',lambda s:s.get('sourceindex')==1 and s.get('player')=='paused',20)
q.keys('Play');q.expect('switched source resumes',lambda s:s.get('sourceindex')==1 and s.get('player')=='playing',12)
(q.ROOT/'build/qa-sources-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
