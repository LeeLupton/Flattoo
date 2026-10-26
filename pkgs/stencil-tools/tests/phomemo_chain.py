#!/usr/bin/env python3
"""Offline end-to-end test of the Phomemo print path over the Bluetooth backend.

    PDF -> pdftoraster (vendor PPD) -> rastertoM08F -> bluetooth backend -> fake printer

The fake printer answers the vendor filter's status queries with the packets
decoded from the filter binary (see docs/printers.md). File descriptors are
wired the way cupsd wires them: filter stdout -> backend stdin, backend fd 3
-> filter fd 3 (back channel), fd 4 shared socketpair (side channel).

usage: phomemo_chain.py PDFTORASTER FILTER PPD BACKEND PAGE.pdf [bluetooth|socket]

  bluetooth  (default) BACKEND is Flattoo's bluetooth backend; the fake
             printer is a Unix socket reached via FLATTOO_BT_FAKE_SOCKET.
  socket     BACKEND is CUPS' own socket backend; the fake printer listens on
             TCP 127.0.0.1 and DEVICE_URI is socket://127.0.0.1:PORT (the LAN
             path for Phomemo Wi-Fi units and networked PocketJets).
"""

import os
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time

REPLIES = {
    0x09: b"\x1a\x08" + b"M08F-FAKE000001".ljust(15, b"\x00"),  # name / serial
    0x07: b"\x1a\x07\x01\x02\x03",                               # firmware
    0x11: b"\x1a\x06\x89",                                       # paper present
    0x12: b"\x1a\x05\x98",                                       # idle
    0x43: b"\x1a\x0f\x0c",                                       # ready
    0x0b: b"\x1a\x03\xa8",                                       # temperature ok
}


class FakePrinter(threading.Thread):
    def __init__(self, path=None, tcp=False):
        super().__init__(daemon=True)
        self.received = bytearray()
        self.queries = []
        self.error = None
        self.in_page = False
        if tcp:
            self.srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.srv.bind(("127.0.0.1", 0))
            self.port = self.srv.getsockname()[1]
        else:
            self.srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.srv.bind(path)
        self.srv.listen(1)

    def run(self):
        try:
            self.serve()
        except Exception as e:  # noqa: BLE001
            self.error = e

    def serve(self):
        conn, _ = self.srv.accept()
        conn.settimeout(0.2)
        pending = b""
        while True:
            try:
                data = conn.recv(65536)
            except socket.timeout:
                continue
            except OSError:
                break
            if not data:
                break
            self.received += data
            pending += data
            # Answer 1f 11 xx queries. Only before page data starts: the same
            # byte pair occurs inside raster data and must not be "answered".
            while not self.in_page:
                i = pending.find(b"\x1f\x11")
                if i < 0 or i + 3 > len(pending):
                    pending = pending[-2:] if i < 0 else pending[i:]
                    break
                q = pending[i + 2]
                self.queries.append(q)
                pending = pending[i + 3:]
                reply = REPLIES.get(q)
                if reply:
                    try:
                        conn.sendall(reply)
                    except OSError:
                        pass
            if b"\x1dv0" in self.received:
                self.in_page = True
        conn.close()


def main():
    pdftoraster, filt, ppd, backend, pdf = sys.argv[1:6]
    mode = sys.argv[6] if len(sys.argv) > 6 else "bluetooth"
    with tempfile.TemporaryDirectory() as td:
        if mode == "socket":
            printer = FakePrinter(tcp=True)
            uri = f"socket://127.0.0.1:{printer.port}"
            extra = {}
        else:
            sockpath = os.path.join(td, "printer.sock")
            printer = FakePrinter(sockpath)
            uri = "bluetooth://AA:BB:CC:DD:EE:FF/1"
            extra = {"FLATTOO_BT_FAKE_SOCKET": sockpath}
        printer.start()

        env = dict(os.environ, PPD=ppd, DEVICE_URI=uri, TMPDIR=td, **extra)

        raster = os.path.join(td, "page.ras")
        with open(raster, "wb") as out:
            subprocess.run([pdftoraster, "1", "artist", "test", "1", "PageSize=Letter", pdf],
                           stdout=out, stderr=subprocess.DEVNULL, env=env, check=True)
        assert os.path.getsize(raster) > 100000, "pdftoraster produced no raster"

        bc_r, bc_w = os.pipe()               # back channel: backend writes, filter reads
        sc_f, sc_b = socket.socketpair()     # side channel
        f_out_r, f_out_w = os.pipe()         # filter stdout -> backend stdin

        # Remap fds 3/4 inside the child with the shell: subprocess closes
        # everything not in pass_fds *after* preexec_fn, so dup2 there is lost.
        def with_fds(cmd, fd3, fd4, fd3_write):
            op = ">" if fd3_write else "<"
            return ["sh", "-c", f'exec 3{op}&{fd3} 4<&{fd4}; exec "$@"', "_", *cmd]

        # stderr goes to files: CUPS' socket backend logs a DEBUG line per
        # 256-byte chunk, which would fill a pipe and deadlock the chain.
        ferr_f = open(os.path.join(td, "filter.err"), "w+b")
        berr_f = open(os.path.join(td, "backend.err"), "w+b")
        filt_p = subprocess.Popen(with_fds([filt, "1", "artist", "test", "1", "PageSize=Letter"], bc_r, sc_f.fileno(), False),
                                  stdin=open(raster, "rb"), stdout=f_out_w, stderr=ferr_f,
                                  env=env, pass_fds=(bc_r, sc_f.fileno()))
        back_p = subprocess.Popen(with_fds([backend, "1", "artist", "test", "1", "PageSize=Letter"], bc_w, sc_b.fileno(), True),
                                  stdin=f_out_r, stdout=subprocess.DEVNULL, stderr=berr_f,
                                  env=env, pass_fds=(bc_w, sc_b.fileno()))
        os.close(f_out_r); os.close(f_out_w); os.close(bc_r); os.close(bc_w); sc_f.close(); sc_b.close()

        t0 = time.time()
        while time.time() - t0 < 180 and (filt_p.poll() is None or back_p.poll() is None):
            time.sleep(0.2)
        for p in (filt_p, back_p):
            if p.poll() is None:
                p.kill()
        ferr_f.seek(0); berr_f.seek(0)
        ferr = ferr_f.read().decode(errors="replace")
        berr = berr_f.read().decode(errors="replace")
        time.sleep(0.5)

        data = bytes(printer.received)
        blocks = [(d[4] + 256 * d[5], d[6] + 256 * d[7]) for d in
                  (data[m.start():m.start() + 8] for m in re.finditer(b"\x1dv0", data))]
        print(f"filter exit {filt_p.returncode}, backend exit {back_p.returncode}, printer thread alive {printer.is_alive()}, printer error {printer.error!r}")
        print("filter stderr tail:", " / ".join(l for l in ferr.splitlines() if not l.startswith("DEBUG"))[-400:])
        print("backend stderr tail:", " / ".join(berr.splitlines())[-400:])
        print(f"printer received {len(data)} bytes, queries {[hex(q) for q in printer.queries]}")
        print(f"GS v 0 blocks: {blocks[:3]}")
        print("backend:", " / ".join(l for l in berr.splitlines() if l.startswith("INFO"))[:300])

        assert filt_p.returncode == 0, f"filter failed:\n{ferr[-800:]}"
        assert back_p.returncode == 0, f"backend failed:\n{berr[-800:]}"
        assert 0x09 in printer.queries, "filter never asked the printer for its name"
        assert len(data) > 300000, "too little printer data"
        assert any(w == 196 for w, _ in blocks), f"no 1568 px wide raster block: {blocks[:3]}"
        print(f"ok ({mode}): PDF -> raster -> rastertoM08F -> {os.path.basename(backend)} backend -> printer, 1568 px wide page")


if __name__ == "__main__":
    main()
