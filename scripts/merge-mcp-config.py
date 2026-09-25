#!/usr/bin/env python3
"""Merge usable MCP entries without replacing user settings or installing packages."""
import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('template', type=Path)
    parser.add_argument('target', type=Path)
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--desktop', action='store_true', help='Resolve GUI executable paths and preserve runtime PATH')
    args = parser.parse_args()
    config = json.loads(args.target.read_text()) if args.target.exists() else {}
    if not isinstance(config, dict) or not isinstance(config.get('mcpServers', {}), dict):
        parser.error('Existing config/mcpServers must be JSON objects; nothing changed.')
    servers = config.setdefault('mcpServers', {})
    home = str(Path.home())
    cert = next((str(p) for p in (Path.home() / '.mamba_ca_bundle.pem', Path('/etc/ssl/certs/ca-certificates.crt')) if p.is_file()), '')
    replacements = {'{{HOME}}': home, '{{CA_CERT_PATH}}': cert, '{{NPX_PATH}}': shutil.which('npx') or 'npx'}
    def substitute(value):
        if isinstance(value, str):
            for key, replacement in replacements.items():
                value = value.replace(key, replacement)
            return value
        if isinstance(value, list):
            return [substitute(item) for item in value]
        if isinstance(value, dict):
            return {key: substitute(item) for key, item in value.items()}
        return value
    for name, entry in json.loads(args.template.read_text()).get('mcpServers', {}).items():
        if name in servers and not args.force:
            print(f'Preserved existing MCP server: {name}')
            continue
        entry = substitute(entry)
        command = entry.get('command')
        if command and not shutil.which(command):
            print(f'Skipped {name}: command unavailable: {command}')
            continue
        missing = [p for p in entry.get('args', []) if isinstance(p, str) and p.startswith(home + '/') and not Path(p).exists()]
        if missing:
            print(f'Skipped {name}: local files unavailable: {missing}')
            continue
        if entry.get('url'):
            print(f'Skipped {name}: remote endpoint {entry["url"]}; add deliberately after reviewing privacy/authentication.')
            continue
        if command and args.desktop:
            entry['command'] = shutil.which(command)
            entry.setdefault('env', {}).setdefault('PATH', os.environ.get('PATH', ''))
        env = entry.get('env', {})
        if env.get('NODE_EXTRA_CA_CERTS') == '':
            del env['NODE_EXTRA_CA_CERTS']
        if any('YOUR_' in str(value) for value in env.values()):
            print(f'Skipped {name}: credentials are placeholders')
            continue
        servers[name] = entry
        print(f'Configured {name}; packages/authentication may be needed at first launch.')
    content = json.dumps(config, indent=2) + '\n'
    if args.target.exists() and json.loads(args.target.read_text()) == config:
        return
    args.target.parent.mkdir(parents=True, exist_ok=True)
    if args.target.exists():
        backup = args.target.with_name(args.target.name + '.skillweave.bak')
        if not backup.exists():
            shutil.copy2(args.target, backup)
    fd, name = tempfile.mkstemp(prefix='.skillweave-', dir=args.target.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        if args.target.exists():
            os.chmod(name, args.target.stat().st_mode & 0o777)
        os.replace(name, args.target)
    finally:
        if os.path.exists(name):
            os.unlink(name)


if __name__ == '__main__':
    main()
