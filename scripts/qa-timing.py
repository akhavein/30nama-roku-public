#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('stream:104');q.expect('timing fixture playing',lambda s:s.get('player')=='playing',15)
q.keys('Play','Right','Right','Right','Select','Down','Down','Down','Down','Select');q.expect('timing menu opens',lambda s:s.get('trackkind')=='timing' and s.get('tracks'))
q.keys('Down','Down','Select');q.expect('timing reset',lambda s:s.get('captionoffset')==0)
q.keys('Down','Select');q.expect('later timing applied',lambda s:s.get('captionoffset')==500)
q.launch('stream:104');q.expect('timing survives relaunch for title',lambda s:s.get('captionoffset')==500 and s.get('player')=='playing',15)
q.launch('stream:101');q.expect('other titles retain independent timing',lambda s:s.get('captionoffset')==0 and s.get('player')=='playing',15)
(q.ROOT/'build/qa-timing-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
