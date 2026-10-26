#!/usr/bin/env python3
"""stencil-lan-scan must find a fake Phomemo answering on 127.0.0.1:<port> and
report nothing for a closed port."""
import socket
import subprocess
import sys
import threading

scan = sys.argv[1]
srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 0))
srv.listen(4)
port = srv.getsockname()[1]


def serve():
    while True:
        c, _ = srv.accept()
        try:
            if c.recv(16).startswith(b"\x1f\x11\x09"):
                c.sendall(b"\x1a\x08" + b"M08F-WS-Q803".ljust(15, b"\x00"))
        finally:
            c.close()


threading.Thread(target=serve, daemon=True).start()

r = subprocess.run([scan, "--subnet", "127.0.0.1/32", "--no-mdns", "--port", str(port)],
                   capture_output=True, text=True, timeout=60)
print(r.stdout.strip())
assert r.returncode == 0 and f"socket://127.0.0.1:{port} phomemo M08F-WS-Q803" in r.stdout, r.stderr
r2 = subprocess.run([scan, "--subnet", "127.0.0.1/32", "--no-mdns", "--port", str(port + 1)],
                    capture_output=True, text=True, timeout=60)
assert r2.returncode == 1 and not r2.stdout.strip(), r2.stdout
print("ok: LAN fingerprint finds the printer and ignores closed ports")
