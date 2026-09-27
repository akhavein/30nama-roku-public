#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('watchlist');q.expect('watchlist action available',lambda s:s.get('titleactions')==['play','watchlist','cloud-watch','back'])
q.keys('Down','Select');q.expect('title added to watchlist',lambda s:s.get('watchcount')==1)
q.launch('watchlist-reload');q.expect('watchlist survives relaunch',lambda s:s.get('page')=='watchlist' and s.get('watchcount')==1)
q.keys('Select');q.expect('saved title opens',lambda s:s.get('page')=='title')
q.keys('Down','Select');q.expect('saved title removed',lambda s:s.get('watchcount')==0)
q.launch('watchlist-reload');q.expect('removal persists with helpful empty state',lambda s:s.get('watchcount')==0 and 'Save titles' in s.get('empty',''))
q.save();(q.ROOT/'build/qa-watchlist-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
