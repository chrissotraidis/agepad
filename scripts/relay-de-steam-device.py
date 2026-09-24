#!/usr/bin/env python3
"""Briefly forward one paired iPad's genuine Steam TCP traffic over a USB tunnel.

Bind only to the Mac side of a CoreDevice IPv6 tunnel. No protocol messages,
account state, ownership results, or paths are fabricated. The relay closes
all connections when its bounded run ends.
"""
import argparse
import asyncio
import ipaddress
import socket
import subprocess
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--bind', required=True, help='Mac-side tunnel IPv6, or :: with --allow paired-tunnel')
parser.add_argument('--allow', required=True, help='iPad tunnel IPv6, or paired-tunnel with --bind ::')
parser.add_argument('--listen-port', required=True, type=int)
parser.add_argument('--steam-port', required=True, type=int)
parser.add_argument('--path-listen-port', type=int)
parser.add_argument('--path-socket', help='Existing same-user HostSteamPathRelay Unix socket')
parser.add_argument('--seconds', type=int, default=120)
args = parser.parse_args()
dynamic_pair = args.bind == '::' and args.allow == 'paired-tunnel'
bind = ipaddress.IPv6Address(args.bind)
allow = None if dynamic_pair else ipaddress.IPv6Address(args.allow)
if not dynamic_pair and (not bind.is_private or not allow.is_private or bind == allow):
    parser.error('Use distinct private tunnel IPv6 addresses')
if not 1024 <= args.listen_port <= 65535 or not 1024 <= args.steam_port <= 65535:
    parser.error('Ports must be unprivileged TCP ports')
if not 1 <= args.seconds <= 600:
    parser.error('Relay duration must be 1–600 seconds')
if bool(args.path_listen_port) != bool(args.path_socket):
    parser.error('Specify both path relay options or neither')
if args.path_listen_port and not 1024 <= args.path_listen_port <= 65535:
    parser.error('Path listener must use an unprivileged TCP port')

active = set()

def paired_device(peer_text):
    peer = ipaddress.IPv6Address(peer_text)
    if not dynamic_pair:
        return peer == allow
    if peer.packed[0] & 0xfe != 0xfc or peer.packed[8:] != b'\0' * 7 + b'\1':
        return False
    mac_address = str(ipaddress.IPv6Address(int(peer) + 1))
    try:
        interfaces = subprocess.run(['ifconfig'], capture_output=True, text=True,
                                    timeout=2, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return bool(re.search(r'\binet6\s+' + re.escape(mac_address) + r'\s', interfaces))

async def pump(reader, writer):
    while data := await reader.read(65536):
        writer.write(data)
        await writer.drain()

async def bridge(reader, writer, path_query=False):
    peer = writer.get_extra_info('peername')
    if not peer or not paired_device(peer[0]):
        writer.close()
        await writer.wait_closed()
        return
    try:
        if path_query:
            upstream_reader, upstream_writer = await asyncio.open_unix_connection(args.path_socket)
        else:
            upstream_reader, upstream_writer = await asyncio.open_connection('127.0.0.1', args.steam_port)
    except OSError as error:
        print(f'LOCAL_STEAM_CONNECT_FAILED errno={error.errno}', flush=True)
        writer.close()
        await writer.wait_closed()
        return
    active.update((writer, upstream_writer))
    label = 'GENUINE_STEAM_PATH' if path_query else 'GENUINE_STEAM_STREAM'
    print(f'{label}_OPEN', flush=True)
    try:
        directions = (asyncio.create_task(pump(reader, upstream_writer)),
                      asyncio.create_task(pump(upstream_reader, writer)))
        done, pending = await asyncio.wait(directions, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
        await asyncio.gather(*directions, return_exceptions=True)
        for task in done:
            if task.exception():
                print(f'STREAM_ERROR {type(task.exception()).__name__}', flush=True)
    finally:
        print(f'{label}_CLOSED', flush=True)
        for endpoint in (writer, upstream_writer):
            active.discard(endpoint)
            endpoint.close()
            await endpoint.wait_closed()

async def main():
    server = await asyncio.start_server(bridge, str(bind), args.listen_port,
                                        family=socket.AF_INET6, backlog=2)
    path_server = None
    if args.path_socket:
        async def path_bridge(reader, writer):
            await bridge(reader, writer, True)
        path_server = await asyncio.start_server(path_bridge, str(bind), args.path_listen_port,
                                                 family=socket.AF_INET6, backlog=2)
    print(f'TUNNEL_READY bind={bind} allow={args.allow} port={args.listen_port}', flush=True)
    if path_server:
        print(f'PATH_TUNNEL_READY port={args.path_listen_port}', flush=True)
    try:
        await asyncio.sleep(args.seconds)
    finally:
        server.close()
        await server.wait_closed()
        if path_server:
            path_server.close()
            await path_server.wait_closed()
        for writer in tuple(active):
            writer.close()
        print('TUNNEL_CLOSED', flush=True)

try:
    asyncio.run(main())
except KeyboardInterrupt:
    pass
