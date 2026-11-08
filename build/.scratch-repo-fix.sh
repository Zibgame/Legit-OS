#!/bin/bash
set -uo pipefail
cd /cache
mkdir -p /broken
n=0
for f in *.pkg.tar.zst; do
    if ! bsdtar -xOf "$f" .MTREE >/dev/null 2>&1 && ! bsdtar -xOf "$f" .PKGINFO >/dev/null 2>&1; then
        mv "$f" /broken/
        n=$((n+1))
        echo "broken: $f"
    fi
done
echo "CORROMPUS: $n"
rm -f legit-cache.db.tar.gz legit-cache.files.tar.gz
repo-add legit-cache.db.tar.gz *.pkg.tar.zst >/dev/null 2>&1
echo "ENTRIES: $(bsdtar -tf legit-cache.db.tar.gz 2>/dev/null | grep -c desc)"
ls -la legit-cache.db.tar.gz
