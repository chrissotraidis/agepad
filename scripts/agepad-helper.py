#!/usr/bin/env python3
"""AgePad Mac helper: lets a paired iPad reach this Mac's Steam over Wi-Fi or Tailscale.

The game on the iPad runs its genuine Steam library; this helper only forwards
its traffic to the Steam app running and signed in on this Mac. Nothing is
fabricated. Every connection must begin with the pairing key created by
"agepad-ipad.sh pair", and only private-network / Tailscale addresses are
accepted. Modes: S = Steam client stream, P = Steam install path query,
I = helper process ID (Steam tracks the game by it).
"""
import struct, argparse, asyncio, hmac, ipaddress, os, signal, socket, subprocess, sys, time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', type=int, default=61343)
parser.add_argument('--steam-port', type=int, default=57343)
parser.add_argument('--token-file', required=True)
parser.add_argument('--path-relay', required=True, help='HostSteamPathRelay executable')
parser.add_argument('--state-dir', required=True)
parser.add_argument('--capture', help='Diagnostics: record the game\'s Steam stream (timestamp, direction, bytes) to this local file')
args = parser.parse_args()

token = open(args.token_file).read().strip().encode()
if len(token) < 32:
    sys.exit('Pairing key missing or too short; run agepad-ipad.sh pair')
ALLOWED = [ipaddress.ip_network(n) for n in (
    '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10', '169.254.0.0/16',
    'fc00::/7', 'fe80::/10')]

def log(message):
    print(time.strftime('%H:%M:%S'), message, flush=True)

def allowed(peer):
    address = ipaddress.ip_address(peer.split('%')[0])
    if getattr(address, 'ipv4_mapped', None):
        address = address.ipv4_mapped
    return any(address in network for network in ALLOWED)

os.makedirs(args.state_dir, exist_ok=True)
path_socket = os.path.join(args.state_dir, 'path.sock')
if os.path.exists(path_socket):
    os.unlink(path_socket)
path_relay = subprocess.Popen([args.path_relay, path_socket, '0'], stdout=subprocess.DEVNULL)

STATS = {'up': 0, 'down': 0, 'P': 0, 'I': 0, 'S': 0}
capture = open(args.capture, 'ab') if args.capture else None
CAPTURE_START = time.monotonic()

async def pump(reader, writer, key=None):
    try:
        while data := await reader.read(65536):
            if key:
                STATS[key] += len(data)
                if capture:
                    capture.write(struct.pack('<dBI', time.monotonic() - CAPTURE_START, key == 'up', len(data)) + data)
            writer.write(data)
            await writer.drain()
    except (ConnectionError, OSError):
        pass

async def report():
    last = None
    while True:
        await asyncio.sleep(10)
        now = dict(STATS)
        if now != last:
            log('TRAFFIC ' + ' '.join(f'{k}={v}' for k, v in now.items()))
        last = now

async def handle(reader, writer):
    peer = writer.get_extra_info('peername')
    sock = writer.get_extra_info('socket')
    if sock is not None and sock.family in (socket.AF_INET, socket.AF_INET6):
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)  # see pump(): tiny IPC messages
    if peer and peer[0] in ('127.0.0.1', '::1'):
        writer.close(); return  # local "is it running?" check
    if not peer or not allowed(peer[0]):
        log(f'REFUSED address={peer[0] if peer else "?"}')
        writer.close(); return
    try:
        header = await asyncio.wait_for(reader.readline(), 5)
    except (asyncio.TimeoutError, ConnectionError):
        writer.close(); return
    parts = header.decode(errors='replace').split()
    if len(parts) != 3 or parts[0] != 'AGEPAD1' or not hmac.compare_digest(parts[2].encode(), token):
        log(f'REFUSED bad-key address={peer[0]}')
        writer.close(); return
    mode = parts[1]
    if mode in STATS:
        STATS[mode] += 1
    if mode == 'I':
        # Ask Steam's status service (the same query the game makes) instead of
        # opening the game port: Steam tracks games by this helper's process ID,
        # and a connect-and-drop there looked like the game quitting.
        steam = 0
        try:
            s_reader, s_writer = await asyncio.wait_for(asyncio.open_unix_connection(path_socket), 2)
            s_writer.write(b'AGEPATH1'); await s_writer.drain()
            reply = await asyncio.wait_for(s_reader.readexactly(524), 3)
            s_writer.close()
            steam = 1 if int.from_bytes(reply[0:4], 'little', signed=True) == 0 and int.from_bytes(reply[8:12], 'little') > 0 else 0
        except (OSError, asyncio.TimeoutError, asyncio.IncompleteReadError):
            steam = 0
        if not steam:
            log('STEAM_NOT_RUNNING (open Steam on this Mac and sign in)')
        writer.write(f'PID {os.getpid()} STEAM {steam}\n'.encode()); await writer.drain(); writer.close(); return
    try:
        if mode == 'S':
            up_reader, up_writer = await asyncio.open_connection('127.0.0.1', args.steam_port)
            up_sock = up_writer.get_extra_info('socket')
            if up_sock is not None:
                up_sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        elif mode == 'P':
            up_reader, up_writer = await asyncio.open_unix_connection(path_socket)
        else:
            writer.close(); return
    except OSError:
        log('STEAM_NOT_RUNNING (open Steam on this Mac and sign in)')
        writer.close(); return
    if mode == 'S':
        log(f'GAME_CONNECTED address={peer[0]}')
    tasks = [asyncio.create_task(pump(reader, up_writer, 'up' if mode == 'S' else None)),
             asyncio.create_task(pump(up_reader, writer, 'down' if mode == 'S' else None))]
    await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    for task in tasks:
        task.cancel()
    for endpoint in (writer, up_writer):
        endpoint.close()
    if mode == 'S':
        log(f'GAME_DISCONNECTED address={peer[0]}')

async def main():
    servers = [await asyncio.start_server(handle, '0.0.0.0', args.port, family=socket.AF_INET)]
    try:
        servers.append(await asyncio.start_server(handle, '::', args.port, family=socket.AF_INET6))
    except OSError:
        pass
    log(f'AGEPAD_HELPER_READY port={args.port} pid={os.getpid()}')
    asyncio.create_task(report())
    stop = asyncio.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        asyncio.get_running_loop().add_signal_handler(sig, stop.set)
    await stop.wait()
    for server in servers:
        server.close()

try:
    asyncio.run(main())
finally:
    path_relay.terminate()
