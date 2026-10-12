# Development dependency compatibility

These adapters are development-only and are excluded from the Roku ZIP. The compiler (`brighterscript@0.70.4`) and executable BrightScript test interpreter (`brs@0.45.0`) remain pinned, avoiding an unproven interpreter downgrade.

- `decompress-compat` preserves the Promise-returning CommonJS API consumed by `brs`, using dynamic import of pinned `@xhmikosr/decompress@11.1.4`. This maintained release fixes the archive traversal/symlink advisories affecting the unmaintained original `decompress@4.2.1`; see [maintainer advisory](https://github.com/XhmikosR/decompress/security/advisories/GHSA-hrh2-vp3x-79xf). The implementation remains an installed dependency with its own license.
- `decode-uri-component-cjs` contains upstream `decode-uri-component@0.5.0` with exactly one syntactic change: its default export becomes `module.exports`. This allows synchronous CommonJS callers in old source-map tooling to use the patched decoding algorithm without requiring synchronous ESM support or raising the project's Node 22 baseline. MIT notice is preserved. `UPSTREAM.json` pins the original source hash; a regression reverses the export change and checks it. See [decoder advisory](https://github.com/advisories/GHSA-vcc3-ghjq-m6fr).
- `uuid` is overridden to `11.1.1`, preserving the existing v11 CommonJS interface while applying its buffer bounds fix.

The two local packages are explicit root development dependencies, with `$` overrides ensuring transitive callers resolve the same adapters. `npm ci --ignore-scripts` installs them without post-install rewriting of node_modules. No network download is performed by the adapters at runtime.

## Compatibility and residual exposure

`tests/toolchain.test.cjs` checks synchronous Unicode/malformed URI behavior, a bounded malformed-input subprocess, unchanged upstream source, Promise and Buffer archive APIs, safe extraction plus rejected traversal/symlink escape, and the UUID/interpreter imports. The full package suite tests compiler output and executable BrightScript/QR behavior with these dependencies.

The initial online npm audit reported 11 findings: 1 critical, 7 high, 3 moderate. After remediation the critical and moderate findings are removed; **seven high findings remain**, all rooted in `braces <=3.0.3` and its compiler/interpreter glob/watch dependency chains. The registry's latest braces release is still 3.0.3, and [the nesting advisory](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) has no published patched version. The repository uses fixed, trusted glob patterns in `bsconfig.json`; these development tools do not ship in the channel. That narrows exposure but is not remediation. Do not feed arbitrary untrusted glob patterns to this toolchain. Revisit a maintained fix or independently reviewed bounded replacement rather than concealing the advisory or applying a forced downgrade. Offline npm audit output is not evidence that the tree is clean.
