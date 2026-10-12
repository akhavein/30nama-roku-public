# Development dependency compatibility

These adapters are development-only and are excluded from the Roku ZIP. The compiler (`brighterscript@0.70.4`) and executable BrightScript test interpreter (`brs@0.45.0`) remain pinned, avoiding an unproven interpreter downgrade.

- `decompress-compat` preserves the Promise-returning CommonJS API consumed by `brs`, using dynamic import of pinned `@xhmikosr/decompress@11.1.4`. This maintained release fixes the archive traversal/symlink advisories affecting the unmaintained original `decompress@4.2.1`; see [maintainer advisory](https://github.com/XhmikosR/decompress/security/advisories/GHSA-hrh2-vp3x-79xf). The implementation remains an installed dependency with its own license.
- `decode-uri-component-cjs` contains upstream `decode-uri-component@0.5.0` with exactly one syntactic change: its default export becomes `module.exports`. This allows synchronous CommonJS callers in old source-map tooling to use the patched decoding algorithm without requiring synchronous ESM support or raising the project's Node 22 baseline. MIT notice is preserved. `UPSTREAM.json` pins the original source hash; a regression reverses the export change and checks it. See [decoder advisory](https://github.com/advisories/GHSA-vcc3-ghjq-m6fr).
- `uuid` is overridden to `11.1.1`, preserving the existing v11 CommonJS interface while applying its buffer bounds fix.

The two local packages are explicit root development dependencies, with `$` overrides ensuring transitive callers resolve the same adapters. `npm ci --ignore-scripts` installs them without post-install rewriting of node_modules. No network download is performed by the adapters at runtime.

## Compatibility and residual exposure

`tests/toolchain.test.cjs` checks synchronous Unicode/malformed URI behavior, a bounded malformed-input subprocess, unchanged upstream source, Promise and Buffer archive APIs, safe extraction plus rejected traversal/symlink escape, and the UUID/interpreter imports. The full package suite tests compiler output and executable BrightScript/QR behavior with these dependencies.

The initial online npm audit reported 11 findings: 1 critical, 7 high, 3 moderate. After remediation the critical and moderate findings are removed; **seven high findings remain**, all rooted in `braces <=3.0.3` and its compiler/interpreter glob/watch dependency chains. The registry's latest braces release is still 3.0.3, and [the nesting advisory](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) has no published patched version. The repository uses fixed, trusted glob patterns in `bsconfig.json`; these development tools do not ship in the channel. That narrows exposure but is not remediation. Do not feed arbitrary untrusted glob patterns to this toolchain. Revisit a maintained fix or independently reviewed bounded replacement rather than concealing the advisory or applying a forced downgrade. Offline npm audit output is not evidence that the tree is clean.

### Remaining paths, verified 2026-10-12

`npm ls braces micromatch fast-glob chokidar roku-deploy brighterscript brs` resolves these paths (shared nodes are deduplicated):

| Direct consumer | Path to the affected package |
| --- | --- |
| `brighterscript@0.70.4` | `chokidar@3.6.0 → braces@3.0.3` |
| `brighterscript@0.70.4` | `micromatch@4.0.8 → braces@3.0.3` |
| `brighterscript@0.70.4` | `fast-glob@3.3.3 → micromatch@4.0.8 → braces@3.0.3` |
| `brighterscript@0.70.4` | `roku-deploy@3.18.4 → fast-glob@3.3.3 / micromatch@4.0.8 → braces@3.0.3` |
| `brs@0.45.0` | `fast-glob@3.3.3 → micromatch@4.0.8 → braces@3.0.3` |

The seven audit entries are `braces`, `micromatch`, `fast-glob`, `chokidar`, `roku-deploy`, `brighterscript` and `brs`: one advisory propagated through seven affected packages, not seven independent root flaws. Registry metadata for newer `brighterscript@0.73.6` still requests the same affected glob/watch families; latest `micromatch@4.0.8` depends on `braces ^3.0.3`, and latest `fast-glob@3.3.3` depends on that micromatch release. An ordinary supported version upgrade does not resolve this chain. The [upstream issue](https://github.com/micromatch/braces/issues/70) remains open; the maintainer disputes the security framing and recommends keeping patterns trusted. This does not remove the reviewed advisory or establish a patched release.

Practical exposure here is developer/CI process availability when processing a malicious glob pattern. `npm run check` uses the repository's fixed `source/**/*` and `components/**/*`; `scripts/test.py` runs the interpreter in isolated temporary fixture directories. Provider responses, subtitle contents, QR codes and user search text are not passed into these Node glob APIs. The Roku archive contains manifest/source/components/images only, and helper/gateway server imports are Node built-ins. A malicious repository/configuration change or arbitrary developer CLI pattern remains a relevant development-input boundary. No audit ignore, advisory suppression, fake patched version, forced interpreter downgrade or dependency removal was used to obtain a misleading clean result.
