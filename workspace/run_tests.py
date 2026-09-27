"""Runs every offline test suite of the game and prints a short summary.

Needs the Luau CLI: put `luau` (or `luau.exe`) in workspace/bin/, on PATH, or point LUAU=... at it.
Download: https://github.com/luau-lang/luau/releases (luau-<os>.zip).
Usage:  python run_tests.py
"""
import os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)


def luau_path():
    for cand in (os.environ.get('LUAU'), os.path.join('bin', 'luau.exe'), os.path.join('bin', 'luau'), shutil.which('luau')):
        if cand and os.path.exists(cand):
            return cand
    sys.exit('Luau CLI not found: put it in workspace/bin/ or set LUAU=path')


LUAU = luau_path()


def run_lua(path):
    r = subprocess.run([LUAU, path], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.returncode, r.stdout + r.stderr


def bundle(script, *args):
    subprocess.run([sys.executable, os.path.join('test', script), *args], check=True, capture_output=True)


def compile_all():
    bad = []
    comp = LUAU.replace('luau', 'luau-compile') if os.path.exists(LUAU.replace('luau', 'luau-compile')) else None
    for f in sorted(os.listdir('new')):
        if not f.endswith('.lua'):
            continue
        if comp:
            r = subprocess.run([comp, os.path.join('new', f)], capture_output=True)
            if r.returncode:
                bad.append(f)
    return 'skipped (no luau-compile)' if comp is None else ('all compile' if not bad else 'FAILED: ' + ', '.join(bad))


results = []


def suite(name, prepare, lua_file, check):
    out = ''
    try:
        prepare()
        code, out = run_lua(lua_file)
        ok, detail = check(code, out)
    except Exception as e:  # noqa: BLE001 - report and continue with the next suite
        ok, detail = False, repr(e)
    results.append((name, ok, detail))
    print(('PASS ' if ok else 'FAIL ') + name + ' - ' + detail)
    if not ok:
        print('\n'.join(out.splitlines()[-25:]))


def last(out, pattern):
    m = re.findall(pattern, out)
    return m[-1] if m else None


print('compile:', compile_all())


def cmdlist_prepare():
    subprocess.run([sys.executable, os.path.join('test', 'cmdgen.py')], check=True, capture_output=True)
    with open('test/cmdlist_full.lua', 'w', encoding='utf-8') as f:
        f.write(open('test/cmdlist_data.lua', encoding='utf-8').read() + '\n' + open('test/cmdlist.lua', encoding='utf-8').read())
    bundle('bundle.py', 'cmdlist_full.lua')


suite('admin command dictionary (every command in commands.txt, RU+EN)', cmdlist_prepare, 'test/bundle.lua',
      lambda c, o: (c == 0 and 'not instant 0, exec failed 0' in o, last(o, r'commands \d+.*') or 'no summary'))
suite('admin event flow (roulette, additions, AI, fallback, ### filter)', lambda: bundle('bundle.py', 'admin.lua'), 'test/bundle.lua',
      lambda c, o: (c == 0 and 'fallback' in o, 'ok' if c == 0 else 'crashed'))
suite('typos, phone input, 200 troop limit', lambda: bundle('bundle.py', 'q3.lua'), 'test/bundle.lua',
      lambda c, o: (c == 0 and 'server got:\tдай мне 100 золота' in o and 'Alice +50 Barbarian' in o, 'ok' if c == 0 else 'crashed'))
suite('15 minute bot round', lambda: bundle('bundle.py', 'cycle.lua', 'RoundBots=new/RoundBots.lua'), 'test/bundle.lua',
      lambda c, o: (c == 0 and 'status\tActive' in o, last(o, r'events\t\d+') or 'no summary'))
suite('server: lobby, shop, promo codes, like reward', lambda: bundle('srvbundle.py'), 'test/srvbundle.lua',
      lambda c, o: (c == 0 and 'ERRORS:\t0' in o, last(o, r'ERRORS:\t\d+') or 'crashed'))
suite('server: cabins 0/6, two rounds at once, last player standing', lambda: bundle('srvbundle.py', 'srv2.lua'), 'test/srvbundle.lua',
      lambda c, o: (c == 0 and 'ERRORS:\t0' in o, last(o, r'ERRORS:\t\d+') or 'crashed'))
suite('lobby UI: title, shop, codes window', lambda: bundle('uibundle.py'), 'test/uibundle.lua',
      lambda c, o: (c == 0 and 'ERRORS:\t0' in o, last(o, r'ERRORS:\t\d+') or 'crashed'))
suite('round client', lambda: bundle('rcbundle.py'), 'test/rcbundle.lua',
      lambda c, o: (c == 0 and 'ERROR:' not in o, 'ok' if 'ERROR:' not in o else 'errors'))
suite('UI layout on several screen sizes', lambda: bundle('layoutbundle.py'), 'test/layoutbundle.lua',
      lambda c, o: (c == 0 and 'ERRORS:\t0' in o, last(o, r'ERRORS:\t\d+') or 'crashed'))

failed = [n for n, ok, _ in results if not ok]
print('\n%d/%d suites passed' % (len(results) - len(failed), len(results)))
sys.exit(1 if failed else 0)
