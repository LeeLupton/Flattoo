# Network edge: bad prefix announcements, reverse zones, minimal routing

The laptop lives on networks it does not control — the shop's Wi-Fi, a
client's, a café's — and reaches the internet through routing it cannot
see. A host cannot fix a hijacked prefix. It can refuse to act on bad
routing information, keep its own routing minimal, and make a hijacked path
useless to whoever is on it. `modules/network.nix` does that; it is on by
default (`flattoo.network.harden`, `flattoo.network.dns.enable`).

## 1. Bad prefix announcements on the link

What an attacker on the same Wi-Fi can send, and what happens to it:

| Announcement | Mitigation |
|---|---|
| ICMP / ICMPv6 redirect ("send that via me") | Ignored (`accept_redirects=0`, `secure_redirects=0`), never sent (`send_redirects=0`), and dropped at the firewall before the stack sees it. |
| IPv6 Router Advertisement with Route Information Options (routes for arbitrary prefixes) | RIOs ignored (`accept_ra_rt_info_max_plen=0`); only the on-link prefix for SLAAC is taken. Router preference ignored (`accept_ra_rtr_pref=0`) so a "high preference" rogue cannot outrank the real router. RAs from our own addresses ignored. |
| RA from a non-link-local source | Dropped at the firewall (RFC 4861 §6.1.2 says it is not an RA). |
| Source-routed packets | Dropped (`accept_source_route=0`). |
| Gratuitous ARP / unsolicited Neighbor Advertisement (gateway MAC takeover) | Ignored (`drop_gratuitous_arp=1`, `drop_unsolicited_na=1`); the neighbor table changes only when this host asked. ARP answered only for addresses on the receiving interface (`arp_ignore=1`, `arp_announce=2`). |
| Unicast IP inside an L2 multicast frame | Dropped (`drop_unicast_in_l2_multicast=1`). |
| Rogue DHCP (bad gateway, option 121 routes) | Not stoppable at the host without losing DHCP. Blast radius limited by everything below: DNS is validated and encrypted, the browser is HTTPS-only, updates are content-addressed and signed. |

Minimal routing: the laptop is a host, not a router. `ip_forward=0`,
`forwarding=0`, `route_localnet=0`, strict reverse-path filtering
(`rp_filter=1`) with martians logged, routes to links that are down
ignored, and an nftables output rule that never lets a packet leave for a
destination that has no business being routed — `0.0.0.0/8`,
`127.0.0.0/8`, `192.0.0.0/24`, `192.0.2.0/24`, `198.18.0.0/15`,
`198.51.100.0/24`, `203.0.113.0/24`, `240.0.0.0/4` (limited broadcast
excepted, for DHCP and printer discovery), `::1`, `2001:db8::/32`. Inbound,
packets claiming to come from `0.0.0.0/8`, `127.0.0.0/8`, `240.0.0.0/4` or
`::1` on a real interface are dropped. The nftables table is
`inet flattoo-edge`, ahead of the NixOS firewall.

NetworkManager: LLMNR off (spoofable name resolution), IPv6 privacy
addresses, hostname not sent to DHCP servers, MAC randomized per network
(already in `security.nix`).

## 2. Bad prefix announcements upstream

If `9.9.9.9` or `github.com` is hijacked somewhere on the internet, the
laptop should notice or not care:

* **DNS.** A local Unbound answers the whole machine. It forwards over
  **DNS-over-TLS** to Quad9 (`dns.quad9.net`, pinned by name, system CA
  bundle) — a hijacked resolver prefix presents the wrong certificate and
  gets nothing. Unbound **validates DNSSEC itself** (root trust anchor,
  `harden-dnssec-stripped`, `harden-algo-downgrade`, `harden-below-nxdomain`,
  `aggressive-nsec`), so a forged answer for a signed zone is bogus even if
  the transport were plain. `use-caps-for-id` (0x20) and
  `unwanted-reply-threshold` catch spoofed UDP replies when it has to fall
  back; `qname-minimisation`; `deny-any`; no identity/version.
* **Captive portals and hostile hotspots.** A NetworkManager dispatcher
  (`flattoo-dns-mode`) probes the upstream on every connect:
  853 reachable → `strict` (DoT). 853 blocked, 53 reachable → `plain`
  (same upstreams, port 53, still validated; `flattoo.network.dns.allowPlainFallback`).
  Neither → `dhcp`: Unbound forwards to the network's own resolver
  (still validating) so the portal page can load; the next connectivity
  event flips it back. Current mode: `cat /run/flattoo/dns-mode`;
  `journalctl -t flattoo-dns`. By hand: `sudo flattoo-dns-mode`.
* **Updates.** `flake.lock` pins nixpkgs by content hash; the binary cache
  is signed with a pinned key; `flattoo-sync` fetches the repo over TLS and,
  with `flattoo.autoUpgrade.allowedSigners` set, **refuses a tip that is
  not signed by one of those SSH keys** — a hijacked route to GitHub, or
  GitHub itself, cannot push configuration onto the laptop. Off by default
  because every commit on `main` must then be signed, including the weekly
  lock bump (CI signs it when the `FLATTOO_CI_SIGNING_KEY` secret holds a
  key whose public half is in the list). Commits pushed from Claude
  sessions carry that session's own key, so merge or re-sign those
  yourself before turning this on.
* **Browser.** Firefox HTTPS-Only Mode on (the user can allow a site), and
  Firefox's own DoH off so the validating resolver is the one policy point.
* **Remote maintenance** (if enabled) is WireGuard through Tailscale — keyed
  at both ends, indifferent to the path.

Turning signed-only on:

```nix
flattoo.autoUpgrade.allowedSigners = [
  "lee@lupton.dev ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."   # your signing key
  "flattoo-ci ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."       # the CI key, if you add the secret
];
```

and on your machine `git config --global gpg.format ssh`,
`git config --global user.signingkey ~/.ssh/id_ed25519.pub`,
`git config --global commit.gpgsign true`. Lee's key is the one that counts;
the file format is OpenSSH `allowed_signers` (principal, key).

## 3. Reverse zones

Reverse DNS for private and reserved space must never be delegated to or
asked of the internet. Unbound ships the RFC 6303 / AS112 zones as local
`static` zones — `10.in-addr.arpa`, `16-31.172.in-addr.arpa`,
`168.192.in-addr.arpa`, `64-127.100.in-addr.arpa` (shared address space,
100.64/10), `254.169.in-addr.arpa`, `0.in-addr.arpa`, `127.in-addr.arpa`,
the three TEST-NETs, `255.255.255.255.in-addr.arpa`, and the `ip6.arpa`
trees for `::`, `::1`, `fe80::/10`, `fd00::/8` and `2001:db8::/32`, plus
`home.arpa`, `test`, `invalid`, `onion` — answered NXDOMAIN on the box. The laptop
therefore does not leak its LAN layout to AS112 or the upstream, and a PTR
someone else publishes for a private address can never reach it. `.local`
is mDNS (avahi, nss-mdns) and gets the same local NXDOMAIN if anything asks
unicast DNS for it. Nothing on the machine makes a decision on a reverse
lookup: sshd `UseDNS` is off and CUPS `HostNameLookups` is off by default;
avahi is discovery only.

Trade-off: because the resolver is Quad9 rather than the shop router,
router-local names (`printer.lan`) do not resolve. Printers are found by
mDNS and the LAN sweep instead, which is how the stencil tools already
work.
With Tailscale enabled, `*.ts.net` (MagicDNS) is forwarded to
`100.100.100.100` over the tunnel; tailnet reverse lookups stay local
(100.64/10 is shared address space).

## Checks

* `nix flake check` evaluates the configuration; the Unbound config is
  validated by `unbound-checkconf` and the nftables ruleset by `nft -c`
  when the system is built.
* Offline tests run during development: the dispatcher's strict/plain/dhcp
  selection against fake upstream ports and fake `unbound-control`/`nmcli`;
  `flattoo-sync` against a local upstream with signed, unsigned and
  wrong-key tips.
* On the laptop: `sysctl net.ipv6.conf.all.accept_ra_rt_info_max_plen`,
  `sudo nft list table inet flattoo-edge`, `unbound-host -D -v nixos.org`
  (expect `(secure)`), `cat /run/flattoo/dns-mode`.

## Options

```
flattoo.network.harden                    sysctls, nftables edge table, NM privacy, Firefox HTTPS-only   (true)
flattoo.network.dns.enable                Unbound validating resolver, DoT upstream, portal fallback      (true)
flattoo.network.dns.upstreams             [{ address, port = 853, authName }]                              (Quad9)
flattoo.network.dns.allowPlainFallback    port 53 to the same upstreams before the network's resolver     (true)
flattoo.autoUpgrade.allowedSigners        SSH keys that may sign the upstream tip                          ([ ])
```
