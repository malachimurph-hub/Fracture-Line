#!/bin/bash
# M3.5: Godot's APK export stores imported textures (.ctex/.ctexarray) and binary models (.res)
# uncompressed. This re-zips those asset entries with Deflate (the engine reads assets through
# AAssetManager, which handles compressed entries), zipaligns and re-signs with the APK preset's
# release keystore (same certificate as earlier builds, so it installs over them).
# Usage: tools/apk_recompress.sh IN.apk OUT.apk
set -e
IN=$1; OUT=$2
BT=$(ls -d /workspace/tools/android/sdk/build-tools/* | sort -V | tail -1)
export JAVA_HOME=/workspace/tools/android/jdk-17.0.20.1+1 PATH=/workspace/tools/android/jdk-17.0.20.1+1/bin:$PATH
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
python3 - "$IN" "$TMP/u.apk" <<'PY'
import sys, zipfile
src, dst = sys.argv[1:]
with zipfile.ZipFile(src) as zi, zipfile.ZipFile(dst, "w") as zo:
    for it in zi.infolist():
        if it.filename.startswith("META-INF/"):
            continue
        d = zi.read(it.filename)
        ct = it.compress_type
        if it.filename.startswith("assets/") and ct == zipfile.ZIP_STORED and it.filename.endswith((".ctex", ".ctexarray", ".res")):
            ct = zipfile.ZIP_DEFLATED
        n = zipfile.ZipInfo(it.filename, it.date_time); n.external_attr = it.external_attr
        zo.writestr(n, d, compress_type=ct, compresslevel=9 if ct == zipfile.ZIP_DEFLATED else None)
PY
"$BT/zipalign" -f -p 4 "$TMP/u.apk" "$TMP/a.apk"
KS=$(sed -n '/^\[preset.0.options\]/,/^\[/{s/^keystore\/release="\(.*\)"/\1/p}' export_presets.cfg)
KU=$(sed -n '/^\[preset.0.options\]/,/^\[/{s/^keystore\/release_user="\(.*\)"/\1/p}' export_presets.cfg)
KP=$(sed -n '/^\[preset.0.options\]/,/^\[/{s/^keystore\/release_password="\(.*\)"/\1/p}' export_presets.cfg)
FL_KP="$KP" "$BT/apksigner" sign --ks "$KS" --ks-key-alias "$KU" --ks-pass env:FL_KP --key-pass env:FL_KP --out "$OUT" "$TMP/a.apk"
rm -rf "$TMP"
"$BT/apksigner" verify "$OUT" && echo "signed OK: $(stat -c%s "$OUT") bytes"
