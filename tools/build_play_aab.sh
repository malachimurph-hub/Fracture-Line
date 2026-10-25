#!/bin/bash
# M3.2.2 Play prep: build the signed Android App Bundle (preset "Android Play (AAB)", targetSdk 36).
# Signs with the upload key; the passwords are read from the secrets file into Godot's env overrides
# (never written to export_presets.cfg). Uses the same size-stripped arm64 engine as the APK
# (/workspace/tools/fl_templates) by swapping its libgodot_android.so into the gradle template's aar.
# Usage: tools/build_play_aab.sh
set -e
cd "$(dirname "$0")/.."
G=/workspace/tools/godot
SEC=/workspace/mobile-rts/keys/upload_key_secrets.txt
export JAVA_HOME=/workspace/tools/android/jdk-17.0.20.1+1
export ANDROID_HOME=/workspace/tools/android/sdk
[ -d android/build ] || $G --headless --path . --install-android-build-template --quit
AAR=android/build/libs/release/godot-lib.template_release.aar
if [ ! -f android/build/.fl_engine ]; then
  python3 - "$AAR" <<'PY'
import sys, zipfile, shutil
aar = sys.argv[1]; tmp = aar + ".new"
so = zipfile.ZipFile("/workspace/tools/fl_templates/android_release_fl_arm64.apk").read("lib/arm64-v8a/libgodot_android.so")
with zipfile.ZipFile(aar) as zi, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zo:
    for it in zi.infolist():
        if it.filename.startswith(("jni/armeabi-v7a/", "jni/x86/", "jni/x86_64/")):
            continue
        zo.writestr(it, so if it.filename == "jni/arm64-v8a/libgodot_android.so" else zi.read(it.filename))
shutil.move(tmp, aar)
PY
  touch android/build/.fl_engine
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$(sed -n 's/^keystore=//p' "$SEC")
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=$(sed -n 's/^alias=//p' "$SEC")
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(sed -n 's/^store_password=//p' "$SEC")
mkdir -p ../builds/play
$G --headless --path . --export-release "Android Play (AAB)" ../builds/play/RulesOfEngagement.aab
