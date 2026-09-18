"""Losslessly archive raw profiling JSON, with deterministic gzip and hashes."""
import gzip
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'docs' / 'verification'
records = []
manifest = root / 'performance-archive-manifest.json'
if manifest.exists():
    raise FileExistsError(manifest)
for source in sorted(root.glob('performance-*.json')):
    raw = source.read_bytes()
    json.loads(raw)  # Reject broken evidence instead of archiving it.
    target = source.with_suffix('.json.gz')
    if target.exists():
        raise FileExistsError(target)
    target.write_bytes(gzip.compress(raw, mtime=0))
    assert gzip.decompress(target.read_bytes()) == raw
    records.append({'file': target.name, 'sha256_uncompressed': hashlib.sha256(raw).hexdigest(),
                    'original_bytes': len(raw), 'compressed_bytes': target.stat().st_size})
    source.unlink()
if records:
    manifest = root / 'performance-archive-manifest.json'
    if manifest.exists():
        raise FileExistsError(manifest)
    manifest.write_text(json.dumps(records, indent=2) + '\n')
    print(json.dumps({'files': len(records), 'before': sum(r['original_bytes'] for r in records),
                      'after': sum(r['compressed_bytes'] for r in records)}))
