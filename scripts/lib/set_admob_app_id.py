#!/usr/bin/env python3
"""Set the AdMob application id in an AndroidManifest.xml.

Usage: set_admob_app_id.py <manifest> <app-id>

Sets the value whether or not the meta-data element is already present.
An insert-only patch would silently keep the old id when switching from
Google's test id to a real one, which is exactly when you least want a
silent no-op.
"""
import re
import sys

KEY = 'com.google.android.gms.ads.APPLICATION_ID'


def main(path: str, app_id: str) -> None:
    with open(path) as f:
        s = f.read()

    if KEY in s:
        pattern = (r'(<meta-data\b[^>]*android:name="' + re.escape(KEY) +
                   r'"[^>]*android:value=")[^"]*(")')
        s, n = re.subn(pattern, r'\g<1>' + app_id + r'\g<2>', s, count=1,
                       flags=re.S)
        if n != 1:
            sys.exit(f'{path}: found {KEY} but could not rewrite its value')
    else:
        meta = (f'        <meta-data\n'
                f'            android:name="{KEY}"\n'
                f'            android:value="{app_id}"/>\n')
        s, n = re.subn(r'(<application\b[^>]*>\n)', r'\1' + meta, s, count=1)
        if n != 1:
            sys.exit(f'{path}: no <application> tag to insert {KEY} into')

    with open(path, 'w') as f:
        f.write(s)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
