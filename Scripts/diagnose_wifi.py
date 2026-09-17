#!/usr/bin/env python3
"""Read-only diagnosis for upstream #210; never modifies pairing records."""
import argparse
import json
import plistlib
import re
import socket
import struct
import subprocess
from pathlib import Path


def compare_addresses(record, service):
    """Return a diagnosis without disclosing pairing secrets or MAC addresses."""
    stored = record.get('WiFiMACAddress')
    advertised = service.split('@', 1)[0].strip()
    valid = re.compile(r'^[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5}$')
    if not isinstance(stored, str) or not valid.fullmatch(stored) or not valid.fullmatch(advertised) or '@' not in service:
        return 'unknown'
    return 'match' if stored.lower() == advertised.lower() else 'mismatch'


def receive_exact(connection, length):
    data = bytearray()
    while len(data) < length:
        part = connection.recv(length - len(data))
        if not part:
            raise ValueError('Incomplete usbmuxd response')
        data.extend(part)
    return bytes(data)


def read_pair_record(udid):
    body = plistlib.dumps({'MessageType': 'ReadPairRecord', 'PairRecordID': udid,
                          'ClientVersionString': 'AirBattery diagnostic', 'ProgName': 'AirBattery diagnostic'})
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(5)
        connection.connect('/var/run/usbmuxd')
        connection.sendall(struct.pack('<IIII', len(body) + 16, 1, 8, 1) + body)
        length, version, kind, tag = struct.unpack('<IIII', receive_exact(connection, 16))
        if version != 1 or kind != 8 or tag != 1 or not 16 <= length <= 4 * 1024 * 1024:
            raise ValueError('Unexpected usbmuxd response')
        response = plistlib.loads(receive_exact(connection, length - 16))
        data = response.get('PairRecordData')
        if not isinstance(data, bytes):
            raise ValueError('No readable pairing record; USB pairing may be required')
        record = plistlib.loads(data)
        # Discard all certificate/key fields; only the matching key is needed.
        return {'WiFiMACAddress': record.get('WiFiMACAddress')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid', required=True, help='Already paired iPhone/iPad connected by USB')
    options = parser.parse_args()
    executable = Path(__file__).resolve().parents[1] / 'AirBattery/libimobiledevice/bin/ideviceinfo'
    try:
        info = subprocess.run([str(executable), '-u', options.udid, '-q', 'com.apple.mobile.wireless_lockdown',
                               '-k', 'BonjourFullServiceName'], capture_output=True, text=True, timeout=10)
        if info.returncode:
            raise ValueError('Could not read the device service name; check USB connection and existing trust')
        result = compare_addresses(read_pair_record(options.udid), info.stdout.strip())
        print(json.dumps({'pair_record_bonjour_mac': result, 'modified': False}))
        if result == 'mismatch':
            print('Address mismatch detected. This is a candidate cause, not proof of the network failure. No repair was applied.')
    except (OSError, ValueError, plistlib.InvalidFileException, subprocess.TimeoutExpired):
        # Raw helper responses and pairing data may contain identifiers or keys.
        print('Diagnosis unavailable: check the USB connection, existing pairing, and local usbmuxd access.')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
