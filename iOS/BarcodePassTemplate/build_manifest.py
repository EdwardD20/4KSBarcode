import hashlib
import json

# List all files that will be included in the pass (exclude manifest.json and signature)
files = [
    "pass.json",
    "icon.png",
    "icon@2x.png",
    "icon@3x.png",
    "logo.png",
    "strip.png"
]

manifest = {}

for f in files:
    with open(f, "rb") as fileobj:
        content = fileobj.read()
        digest = hashlib.sha1(content).hexdigest()
        manifest[f] = digest

# Write the valid JSON manifest
with open("manifest.json", "w") as out:
    json.dump(manifest, out, indent=2)