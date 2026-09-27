#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('stream:104');q.expect('size fixture playing',lambda s:s.get('player')=='playing',15)
q.keys('Play','Right','Right','Right','Select','Down','Down','Select');q.expect('English captions enabled for sizing',lambda s:s.get('customcaption') and s.get('captiontext'),15)
q.keys('Select','Down','Down','Down','Down','Down','Select');q.expect('caption size menu opens',lambda s:s.get('trackkind')=='size')
q.keys('Down','Down','Select','Back');q.expect('large caption size applied to renderer',lambda s:s.get('captionsize')==40 and s.get('renderedsize')==40)
q.command('scripts/device.py','screenshot','build/feature-caption-large.jpg')
q.launch('stream:104');q.expect('caption size persists across relaunch',lambda s:s.get('captionsize')==40 and s.get('renderedsize')==40 and s.get('captiontext'),15)
(q.ROOT/'build/qa-size-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
