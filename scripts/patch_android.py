import glob, json, os, re, shutil, sys

A = 'android'
GP = A + '/app/build.gradle'

# ---------- zaxira holatiga qaytarish (agar native patch bilan yig'ilmasa) ----------
if '--restore' in sys.argv:
    try:
        rel = open(A + '/.mainactivity_path').read().strip()
        shutil.copy(A + '/MainActivity.java.orig', A + '/' + rel)
        print('MainActivity tiklandi')
    except Exception as e:
        print('MainActivity tiklanmadi:', e)
    try:
        shutil.copy(A + '/build.gradle.orig', GP)
        print('build.gradle tiklandi')
    except Exception as e:
        print('build.gradle tiklanmadi:', e)
    sys.exit(0)

cfg = {}
try:
    cfg = json.load(open('native/config.json', encoding='utf-8'))
except Exception:
    pass


def on(k, d=True):
    return bool(cfg.get(k, d))


# ---------- AndroidManifest: ruxsatlar ----------
mp = A + '/app/src/main/AndroidManifest.xml'
m = open(mp, encoding='utf-8').read()
want = [
    ('INTERNET', ''), ('ACCESS_NETWORK_STATE', ''), ('WAKE_LOCK', ''), ('VIBRATE', ''),
    ('READ_MEDIA_IMAGES', ''), ('READ_MEDIA_VIDEO', ''), ('READ_MEDIA_AUDIO', ''),
    ('READ_EXTERNAL_STORAGE', ' android:maxSdkVersion="32"'),
    ('WRITE_EXTERNAL_STORAGE', ' android:maxSdkVersion="28"'),
    ('RECEIVE_BOOT_COMPLETED', ''),
]
if on('camera'):
    want.append(('CAMERA', ''))
if on('mic'):
    want += [('RECORD_AUDIO', ''), ('MODIFY_AUDIO_SETTINGS', '')]
if on('location'):
    want += [('ACCESS_FINE_LOCATION', ''), ('ACCESS_COARSE_LOCATION', '')]
if on('notif'):
    want.append(('POST_NOTIFICATIONS', ''))
add = ''
for n, a in want:
    if 'android.permission.' + n + '"' not in m:
        add += '    <uses-permission android:name="android.permission.' + n + '"' + a + ' />\n'
if on('camera') and 'android.hardware.camera' not in m:
    add += '    <uses-feature android:name="android.hardware.camera" android:required="false" />\n'
m = m.replace('</manifest>', add + '</manifest>')
if 'requestLegacyExternalStorage' not in m:
    m = m.replace('<application', '<application android:requestLegacyExternalStorage="true"', 1)
if 'usesCleartextTraffic' not in m:
    m = m.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
open(mp, 'w', encoding='utf-8').write(m)
print('Manifest OK, ruxsatlar:', ', '.join(n for n, a in want))

# ---------- build.gradle: doimiy imzo + versionCode ----------
try:
    g = open(GP, encoding='utf-8').read()
    shutil.copy(GP, A + '/build.gradle.orig')
    ks = os.path.abspath('signing/studio.keystore')
    if os.path.exists(ks) and 'studioSign' not in g:
        block = (
            "\n    // studioSign\n    signingConfigs {\n        debug {\n"
            "            storeFile file('" + ks + "')\n"
            "            storePassword 'android'\n            keyAlias 'androiddebugkey'\n"
            "            keyPassword 'android'\n        }\n    }\n"
        )
        g = re.sub(r'(\bandroid\s*\{)', lambda mm: mm.group(1) + block, g, count=1)
        print('Doimiy imzo ulandi (yangilanganda ma\'lumot saqlanadi)')
    run = os.environ.get('GITHUB_RUN_NUMBER')
    if run and run.isdigit():
        g = re.sub(r'versionCode\s+\d+', 'versionCode ' + run, g, count=1)
        print('versionCode =', run)
    open(GP, 'w', encoding='utf-8').write(g)
except Exception as e:
    print('build.gradle patch otkazib yuborildi:', e)

# ---------- MainActivity: yuklash (blob/data/http) ----------
found = glob.glob(A + '/app/src/main/java/**/MainActivity.java', recursive=True)
if not found:
    print('MainActivity.java topilmadi')
    sys.exit(1)
jp = found[0]
src = open(jp, encoding='utf-8').read()
pk = re.search(r'^package\s+([\w.]+)\s*;', src, re.M).group(1)
shutil.copy(jp, A + '/MainActivity.java.orig')
open(A + '/.mainactivity_path', 'w').write(os.path.relpath(jp, A))
tpl = open('native/MainActivity.java.tpl', encoding='utf-8').read().replace('__PACKAGE__', pk)
open(jp, 'w', encoding='utf-8').write(tpl)
os.makedirs(A + '/app/src/main/assets', exist_ok=True)
shutil.copy('native/dl.js', A + '/app/src/main/assets/dl.js')
print('MainActivity OK, paket:', pk)
