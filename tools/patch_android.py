"""Menyesuaikan proyek Android hasil `flutter create`: nama aplikasi, izin, ikon."""
import re, pathlib, shutil
m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = m.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="Maxx Laundry"', s, count=1)
perms = '''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
'''
if 'BLUETOOTH_CONNECT' not in s:
    s = s.replace('<application', perms + '    <application', 1)
q = '''        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="intent"/></intent>
'''
if '<queries>' in s:
    s = s.replace('<queries>', '<queries>\n' + q, 1)
else:
    s = s.replace('</manifest>', '    <queries>\n' + q + '    </queries>\n</manifest>', 1)
m.write_text(s)
sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for k, px in sizes.items():
    out = f'android/app/src/main/res/mipmap-{k}/ic_launcher.png'
    shutil.copy(f'launcher/ic_launcher-{k}.png', out)
print('Android project patched')
