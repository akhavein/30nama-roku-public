#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('diag:recover');q.expect('helper failure has actionable status',lambda s:s.get('helperstatus')=='Unavailable',15)
q.keys('Down','Down','Select');q.expect('helper retry recovers without leaving checks',lambda s:s.get('page')=='diagnostics' and s.get('helperstatus')=='Ready',15)
q.launch('diag:unauthorized');q.expect('bad helper key does not sign out service account',lambda s:s.get('helperstatus')=='Pairing key needs repair' and s.get('signedin'),15)
q.keys('Down','Down','Down','Down','Select');q.expect('diagnostics returns to account',lambda s:s.get('page')=='account')
(q.ROOT/'build/qa-diagnostics-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
