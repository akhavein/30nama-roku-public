const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const decompress = require('decompress');
const decode = require('decode-uri-component');

test('patched decoder preserves its synchronous CommonJS API and Unicode behavior', () => {
  assert.equal(typeof decode, 'function');
  assert.equal(decode('%D9%81%D8%A7%D8%B1%D8%B3%DB%8C'), 'فارسی');
  assert.equal(decode('file%20name%2Ebrs'), 'file name.brs');
  assert.equal(decode('%FF%41'), '%FFA');
  assert.equal(decode('%C2'), '\uFFFD');
  assert.equal(decode('100% + %G0'), '100% + %G0');
  assert.throws(() => decode(null), TypeError);
});

test('decoder conversion is exactly upstream 0.5.0 with its export changed', () => {
  const base = path.resolve(__dirname, '../tools/decode-uri-component-cjs');
  const upstream = JSON.parse(fs.readFileSync(path.join(base, 'UPSTREAM.json')));
  const original = fs.readFileSync(path.join(base, 'index.cjs'), 'utf8')
    .replace('module.exports = function decodeUriComponent', 'export default function decodeUriComponent');
  assert.equal(crypto.createHash('sha256').update(original).digest('hex'), upstream.original_index_sha256);
  assert.match(fs.readFileSync(path.join(base, 'LICENSE'), 'utf8'), /Sam Verschueren/);
});

test('malformed percent sequences finish within a bounded subprocess timeout', () => {
  const script = `const decode = require(${JSON.stringify(require.resolve('decode-uri-component'))});
    const input = '%FF'.repeat(3000); if (decode(input) !== input) process.exit(2);`;
  execFileSync(process.execPath, ['-e', script], {timeout: 3000, stdio: 'pipe'});
});

async function archiveFixture(fn) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'roku-toolchain-'));
  try {
    // Synthetic archives are generated only inside this isolated test directory.
    execFileSync('python3', ['-c', `import io,sys,tarfile,zipfile
from pathlib import Path
r=Path(sys.argv[1])
with zipfile.ZipFile(r/'safe.zip','w') as z: z.writestr('components/Fixture.brs','sub Main()\\nend sub\\n')
with zipfile.ZipFile(r/'traversal.zip','w') as z: z.writestr('../escaped.txt','blocked')
with tarfile.open(r/'symlink.tar','w') as t:
    link=tarfile.TarInfo('link'); link.type=tarfile.SYMTYPE; link.linkname='../outside'; t.addfile(link)
    payload=b'blocked'; item=tarfile.TarInfo('link/escaped.txt'); item.size=len(payload); t.addfile(item,io.BytesIO(payload))
`, root]);
    await fn(root);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
}

test('maintained decompressor supports the Promise API and normal component ZIPs', () => archiveFixture(async root => {
  const output = path.join(root, 'safe');
  const result = decompress(path.join(root, 'safe.zip'), output);
  assert.equal(typeof result.then, 'function');
  const files = await result;
  assert.equal(files[0].path, 'components/Fixture.brs');
  assert.match(fs.readFileSync(path.join(output, files[0].path), 'utf8'), /sub Main/);
  const memoryFiles = await decompress(fs.readFileSync(path.join(root, 'safe.zip')));
  assert.equal(memoryFiles[0].path, files[0].path);
}));

test('archive traversal and symlink escapes cannot write outside extraction target', () => archiveFixture(async root => {
  fs.mkdirSync(path.join(root, 'outside'));
  for (const name of ['traversal.zip', 'symlink.tar']) {
    // Rejection or safely skipping an unsafe entry are both acceptable.
    await decompress(path.join(root, name), path.join(root, name + '-out')).catch(() => {});
    assert.equal(fs.existsSync(path.join(root, 'escaped.txt')), false);
    assert.equal(fs.existsSync(path.join(root, 'outside', 'escaped.txt')), false);
  }
}));

test('patched UUID package retains the API used by the BrightScript interpreter', () => {
  const uuid = require('uuid');
  assert.equal(uuid.validate(uuid.v4()), true);
  assert.equal(typeof require('brs').execute, 'function');
});
