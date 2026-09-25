import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import urllib.request
import zipfile


SOURCE = Path('/game-src')
GAME = Path('/work/game')
BEPINEX = GAME / 'BepInEx'


def install_mod(mod):
    name = mod['name']
    url = mod['url']
    expected = mod['sha256'].lower()
    if not name or '/' in name or '\\' in name or len(expected) != 64:
        raise ValueError(f'invalid mod entry: {name!r}')

    with tempfile.TemporaryDirectory() as temp:
        archive = Path(temp) / 'mod.zip'
        digest = hashlib.sha256()
        with urllib.request.urlopen(url, timeout=120) as response, archive.open('wb') as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != expected:
            raise ValueError(f'sha256 mismatch for {name}')

        extracted = Path(temp) / 'extracted'
        extracted.mkdir()
        with zipfile.ZipFile(archive) as package:
            for entry in package.infolist():
                path = Path(entry.filename)
                if path.is_absolute() or '..' in path.parts:
                    raise ValueError(f'unsafe archive path in {name}: {entry.filename}')
                # Zip symlinks can escape the extraction directory.
                if ((entry.external_attr >> 16) & 0o170000) == 0o120000:
                    raise ValueError(f'symlink in {name}: {entry.filename}')
            package.extractall(extracted)

        packaged_bepinex = extracted / 'BepInEx'
        if packaged_bepinex.is_dir():
            shutil.copytree(packaged_bepinex, BEPINEX, dirs_exist_ok=True)
        else:
            shutil.copytree(extracted, BEPINEX / 'plugins' / name, dirs_exist_ok=True)
        print(f'Installed mod {name}', flush=True)


def main():
    if not (SOURCE / 'Risk of Rain 2.exe').is_file():
        raise FileNotFoundError('Mount a current Windows game install at /game-src')
    shutil.copytree(SOURCE, GAME, dirs_exist_ok=True)
    shutil.copytree('/opt/bepinex', GAME, dirs_exist_ok=True)

    config = BEPINEX / 'config' / 'com.zdiemer.ror2.unofficialdedicatedserver.cfg'
    config.parent.mkdir(parents=True, exist_ok=True)
    port = int(os.environ.get('ROR2_PORT', '7777'))
    players = int(os.environ.get('ROR2_MAX_PLAYERS', '4'))
    delay = float(os.environ.get('ROR2_GAME_OVER_DELAY', '20'))
    if not 1 <= port <= 65535 or not 1 <= players <= 16 or delay < 0:
        raise ValueError('invalid server port, player count, or game-over delay')
    config.write_text(f'[Server]\nPort = {port}\nMaxPlayers = {players}\nGameOverReturnDelaySeconds = {delay}\n')

    mods_file = Path(os.environ.get('ROR2_MODS_JSON_PATH', '/config/mods.json'))
    mods = json.loads(mods_file.read_text()) if mods_file.is_file() else []
    for mod in mods:
        install_mod(mod)

    plugin_dir = BEPINEX / 'plugins'
    plugin_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2('/opt/server-plugin/Ror2UnofficialDedicatedServer.dll', plugin_dir)
    print(f'Prepared server with {len(mods)} extra mods on UDP {port}', flush=True)


if __name__ == '__main__':
    main()
