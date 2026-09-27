#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('recent-reset');q.expect('search recorded',lambda s:s.get('results')==1 and s.get('recents')==['pages'])
q.launch('recent-reload');q.expect('recent search persists',lambda s:s.get('items')==['New search','pages','Clear recent searches'])
q.keys('Down','Select');q.expect('recent query runs with one selection',lambda s:s.get('page')=='search' and s.get('results')==1)
q.mark();q.keys('Back');q.expect('Edit preserves the current query',lambda s:s.get('keyboardtext')=='pages')
q.mark();q.keys('Back');q.expect('cancel Edit restores results',lambda s:s.get('page')=='search' and 'message' not in s and s.get('results')==1)
q.mark();q.keys('Left','Down','Down','Select','Select');q.expect('New search starts with a blank query',lambda s:s.get('keyboardtext')=='')
q.mark();q.keys('Back');q.expect('cancel New search returns to recent searches',lambda s:s.get('page')=='recent-searches' and 'message' not in s)
q.launch('recent-reload');q.expect('reused query remains deduplicated',lambda s:s.get('recents')==['pages'])
q.keys('Down','Down','Select');q.expect('clear removes history',lambda s:s.get('recents')==[] and s.get('items')==['New search'])
(q.ROOT/'build/qa-recents-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
