#!/usr/bin/env python3
"""Two local network namespaces; no claim of physical remote-host acceptance."""
import argparse
import json
from enum import StrEnum
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time
from urllib.request import urlopen

HERE = Path(__file__).resolve().parent
NOTEBOOK = HERE.parent
ROOT = NOTEBOOK.parents[2]
DIST = NOTEBOOK.parent / 'dist/interactive'
DEFAULT = NOTEBOOK.parent / 'dist/network'
IMAGE = 'moxi-p04-network:local'


class Action(StrEnum):
    UP = 'up'
    DOWN = 'down'
    CUT = 'cut'
    RESTORE = 'restore'
    TOPOLOGY = 'topology'


def docker(*args, **kwargs):
    return subprocess.check_output(['docker', *map(str, args)], text=True, **kwargs).strip()


def read_state(directory):
    return json.loads((directory / 'state.json').read_text())


def stop(directory):
    state = read_state(directory)
    for name in (state['lab'], state['kernel']):
        subprocess.run(['docker', 'rm', '-f', name], check=False, stdout=subprocess.DEVNULL)
    for network in (state['network'], state['frontend_network']):
        subprocess.run(['docker', 'network', 'rm', network], check=False, stdout=subprocess.DEVNULL)
    print('Removed only this fixture\'s containers and network')


def workspace(destination):
    for name in ('interactive.py', 'static_interactive.mjs', 'interactive.ipynb', 'check_interactive.py'):
        path = destination / 'examples/fdg/notebook' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(NOTEBOOK / name, path)
    for name in ('browser.wasm', 'widget.mjs', 'runtime.mjs', 'build.json'):
        path = destination / 'examples/fdg/dist/interactive' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(DIST / name, path)
    shutil.copyfile(NOTEBOOK / 'interactive.ipynb', destination / 'examples/fdg/dist/interactive/network.ipynb')


def up(directory, port, build):
    if (directory / 'state.json').exists():
        raise RuntimeError('State already exists; use a new directory or explicitly down the previous fixture')
    if not (DIST / 'build.json').exists():
        raise RuntimeError('Prepare the P04 assets with prepare_interactive.py first')
    if build:
        # Send only these public runtime requirements, never the repository or home.
        with tempfile.TemporaryDirectory(prefix='moxi-p04-image-') as context:
            context = Path(context)
            shutil.copyfile(HERE / 'Dockerfile', context / 'Dockerfile')
            for p in NOTEBOOK.glob('requirements*.txt'):
                shutil.copyfile(p, context / p.name)
            subprocess.run(['docker', 'build', '-t', IMAGE, str(context)], check=True)
    directory.mkdir(parents=True)
    prefix = f'moxi-p04-{secrets.token_hex(5)}'
    state = dict(network=prefix, frontend_network=f'{prefix}-frontend', lab=f'{prefix}-lab', kernel=f'{prefix}-kernel',
                 port=port, token=secrets.token_hex(24), gateway_token=secrets.token_hex(24))
    statefile = directory / 'state.json'
    statefile.touch(mode=0o600)
    statefile.write_text(json.dumps(state, indent=2) + '\n')
    try:
        docker('network', 'create', '--internal', state['network'])
        # Docker Desktop does not publish ports on an internal-only bridge.
        # Lab also gets a frontend bridge; disable masquerading for that bridge.
        docker('network', 'create', '--opt', 'com.docker.network.bridge.enable_ip_masquerade=false', state['frontend_network'])
        common = ['run', '-d', '--cap-drop=ALL',
                  '--security-opt=no-new-privileges', '--memory=2g', '--cpus=2', '--pids-limit=256']
        for role in ('kernel', 'lab'):
            workspace(directory / role)
        docker(*common, '--network', state['network'], '--name', state['kernel'], '--hostname=p04-kernel', '--network-alias=kernel',
               '-v', f'{directory / "kernel"}:/workspace', IMAGE,
               'jupyter', 'kernelgateway', '--ip=0.0.0.0', '--port=8888',
               f'--KernelGatewayApp.auth_token={state["gateway_token"]}')
        info = json.loads(docker('inspect', state['kernel']))[0]
        state['kernel_ip'] = info['NetworkSettings']['Networks'][state['network']]['IPAddress']
        statefile.write_text(json.dumps(state, indent=2) + '\n')
        docker(*common, '--network', state['frontend_network'], '--name', state['lab'], '--hostname=p04-lab',
               '-p', f'127.0.0.1:{port}:8888', '-v', f'{directory / "lab"}:/workspace', IMAGE,
               'jupyter', 'lab', '--no-browser', '--allow-root', '--ip=0.0.0.0', '--port=8888',
               '--ServerApp.root_dir=/workspace', '--ServerApp.port_retries=0',
               '--LabApp.expose_app_in_browser=True', f'--IdentityProvider.token={state["token"]}',
               '--GatewayClient.url=http://kernel:8888',
               f'--GatewayClient.auth_token={state["gateway_token"]}')
        docker('network', 'connect', state['network'], state['lab'])
        deadline = time.monotonic() + 120
        while True:
            try:
                with urlopen(f'http://127.0.0.1:{port}/api/kernelspecs?token={state["token"]}', timeout=2) as response:
                    if 'python3' in json.load(response)['kernelspecs']:
                        break
            except OSError:
                pass
            if time.monotonic() > deadline:
                raise TimeoutError('Gateway/Lab startup; inspect local Docker logs')
            time.sleep(.5)
        topology(directory)
        print(f'Ready: Lab on loopback port {port}; kernel on another internal namespace')
    except BaseException:
        for role in ('lab', 'kernel'):
            with (directory / f'{role}-startup.log').open('w') as log:
                subprocess.run(['docker', 'logs', state[role]], stdout=log, stderr=subprocess.STDOUT)
        stop(directory)
        raise


def topology(directory):
    state = read_state(directory)
    network = json.loads(docker('network', 'inspect', state['network']))[0]
    proof = dict(local_emulation=True, physical_remote_host_acceptance=False,
                 network=dict(driver=network['Driver'], internal=network['Internal'], ipam=network['IPAM']),
                 frontend_network=dict(masquerading=False,lab_loopback_port=state['port']), hosts={})
    for role in ('lab', 'kernel'):
        info = json.loads(docker('inspect', state[role]))[0]
        script = '''import json,os,socket,platform,importlib.metadata as m
print(json.dumps(dict(hostname=socket.gethostname(), network_namespace=os.readlink('/proc/self/ns/net'),
 pid_namespace=os.readlink('/proc/self/ns/pid'), python=platform.python_version(),
 versions={n:m.version(n) for n in ['jupyterlab','jupyter_kernel_gateway','ipykernel','anywidget','ipywidgets']},
 ipykernel_processes=[p.name for p in __import__('pathlib').Path('/proc').iterdir() if p.name.isdigit()
 and p.name!=str(os.getpid()) and b'ipykernel_launcher' in (p/'cmdline').read_bytes()])))'''
        host = json.loads(docker('exec', state[role], 'python', '-c', script))
        host.update(ip=info['NetworkSettings']['Networks'][state['network']]['IPAddress'],
                    image=info['Image'], port_bindings=info['HostConfig']['PortBindings'],
                    mounts=[m['Destination'] for m in info['Mounts']])
        proof['hosts'][role] = host
    assert proof['network']['internal']
    assert proof['hosts']['kernel']['network_namespace'] != proof['hosts']['lab']['network_namespace']
    assert proof['hosts']['kernel']['ip'] != proof['hosts']['lab']['ip']
    (directory / 'topology.json').write_text(json.dumps(proof, indent=2) + '\n')
    return proof


def partition(directory, restore=False):
    state = read_state(directory)
    if restore:
        docker('network', 'connect', '--ip', state['kernel_ip'], '--alias=kernel', state['network'], state['kernel'])
    else:
        docker('network', 'disconnect', state['network'], state['kernel'])
    print('Restored kernel network interface' if restore else 'Disconnected kernel network interface')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', type=Action, choices=list(Action))
    parser.add_argument('--directory', type=Path, default=DEFAULT)
    parser.add_argument('--port', type=int, default=8927)
    parser.add_argument('--no-build', action='store_true')
    args = parser.parse_args()
    directory = args.directory.resolve()
    if args.action == Action.UP:
        up(directory, args.port, not args.no_build)
    elif args.action == Action.DOWN:
        stop(directory)
    elif args.action == Action.TOPOLOGY:
        topology(directory)
    else:
        partition(directory, restore=args.action == Action.RESTORE)


if __name__ == '__main__':
    main()
