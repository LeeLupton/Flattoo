# Network edge hardening for a laptop that lives on other people's networks.
#
# Threat model: the shop Wi-Fi (or the café's) is hostile or badly run, and
# somewhere upstream a prefix is being announced by the wrong AS. Nothing on
# a laptop can fix routing; what it can do is refuse to *act* on bad routing
# information and make hijacked paths useless to whoever sits on them.
#
#   1. Bad prefix announcements on the link: rogue IPv6 Router
#      Advertisements, Route Information Options, ICMP/ICMPv6 redirects,
#      source-routed packets, gratuitous ARP / unsolicited Neighbor
#      Advertisements. Ignored by sysctl, and the redirect/RA cases are
#      dropped at the firewall too. Minimal routing: no forwarding, strict
#      reverse-path filtering, martians logged, bogon destinations never
#      leave the box.
#   2. Bad prefix announcements upstream (a hijacked resolver or update
#      host): a local validating resolver (Unbound) talks DNS-over-TLS to a
#      fixed upstream, validates DNSSEC itself, and 0x20-randomizes what it
#      has to send in the clear. Updates are content-addressed (flake.lock
#      hashes, signed binary cache) and the repo sync can require signed
#      commits (flattoo.autoUpgrade.allowedSigners). Firefox gets HTTPS-only.
#   3. Reverse zones: the RFC 6303 / AS112 reverse zones for private and
#      reserved space (10.in-addr.arpa, 168.192.in-addr.arpa, ip6.arpa for
#      ULA/link-local, ...) are answered locally with NXDOMAIN, never
#      delegated to or asked of the internet, so the laptop neither leaks
#      its LAN layout nor trusts a PTR someone else controls. Nothing on the
#      box makes decisions on reverse lookups (sshd UseDNS and CUPS
#      HostNameLookups are off by default).
#
# Captive portals still work: a NetworkManager dispatcher probes the TLS
# upstream on every connect and, only while it is unreachable, lets Unbound
# ask the network's own resolver (still validating), then goes back.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo.network;
  upstreamTls = map (u: "${u.address}@${toString u.port}#${u.authName}") cfg.dns.upstreams;
  upstreamPlain = map (u: u.address) cfg.dns.upstreams;
  probeHost = (lib.head cfg.dns.upstreams).address;

  dnsMode = pkgs.writeShellScript "flattoo-dns-mode" ''
    # How the local resolver reaches the outside. Called by NetworkManager on
    # every network event; also fine to run by hand.
    #   strict  DNS over TLS to the configured upstreams (default, restored as soon as it works)
    #   plain   the same upstreams on port 53 — this network blocks 853; answers still DNSSEC-validated
    #   dhcp    the network's own resolver — captive portal or everything blocked; still validated
    export PATH=${
      lib.makeBinPath [
        pkgs.unbound
        pkgs.networkmanager
        pkgs.coreutils
        pkgs.util-linux
        pkgs.gnugrep
        pkgs.bash
      ]
    }
    case "''${2:-manual}" in
      up|dhcp4-change|dhcp6-change|connectivity-change|vpn-up|manual) ;;
      *) exit 0 ;;
    esac
    mkdir -p /run/flattoo
    exec 9>/run/flattoo/dns-mode.lock
    flock -w 30 9 || exit 0
    state=/run/flattoo/dns-mode
    cur=$(cat "$state" 2>/dev/null || echo strict)

    probe() { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }
    set_mode() {
      mode=$1; shift
      unbound-control forward_remove . >/dev/null 2>&1 || true
      if [ "$mode" = strict ]; then
        unbound-control forward_add +t . ${lib.concatStringsSep " " upstreamTls} >/dev/null
      else
        unbound-control forward_add . "$@" >/dev/null
      fi
      unbound-control flush_negative >/dev/null 2>&1 || true
      unbound-control flush_bogus >/dev/null 2>&1 || true
      echo "$mode" > "$state"
      echo "flattoo-dns-mode: $mode $*" | systemd-cat -t flattoo-dns -p notice
    }

    if probe ${probeHost} 853; then
      [ "$cur" = strict ] || set_mode strict
      exit 0
    fi
    ${lib.optionalString cfg.dns.allowPlainFallback ''
      if probe ${probeHost} 53; then
        [ "$cur" = plain ] || set_mode plain ${lib.concatStringsSep " " upstreamPlain}
        exit 0
      fi
    ''}
    # link-local v6 resolvers need a zone index unbound cannot take; skip them
    dhcp=$(nmcli -t -g IP4.DNS,IP6.DNS device show 2>/dev/null | tr '|' '\n' | tr -d ' ' | grep -v '^$' | grep -vi '^fe80:' | sort -u | tr '\n' ' ')
    if [ -n "$dhcp" ]; then
      # shellcheck disable=SC2086
      set_mode dhcp $dhcp
    fi
  '';
in
{
  options.flattoo.network = {
    harden =
      lib.mkEnableOption "edge hardening: no redirects/RA tricks/source routing, strict rp_filter, bogon filters, minimal routing"
      // {
        default = true;
      };
    dns = {
      enable =
        lib.mkEnableOption "a local validating resolver (Unbound) with DNS-over-TLS upstream and RFC 6303 reverse zones served locally"
        // {
          default = true;
        };
      upstreams = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              address = lib.mkOption { type = lib.types.str; };
              port = lib.mkOption {
                type = lib.types.port;
                default = 853;
              };
              authName = lib.mkOption {
                type = lib.types.str;
                description = "TLS name the upstream's certificate must carry.";
              };
            };
          }
        );
        default = [
          {
            address = "9.9.9.9";
            authName = "dns.quad9.net";
          }
          {
            address = "149.112.112.112";
            authName = "dns.quad9.net";
          }
          {
            address = "2620:fe::fe";
            authName = "dns.quad9.net";
          }
          {
            address = "2620:fe::9";
            authName = "dns.quad9.net";
          }
        ];
        description = "DNS-over-TLS upstreams. Quad9 by default: validating, malware-blocking, no logging of client IPs.";
      };
      allowPlainFallback = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          When port 853 is blocked, use the same upstreams on port 53 (still
          DNSSEC-validated, 0x20-encoded) before falling back to the
          network's own resolver. Off means: 853 or the network's resolver.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.harden {
      boot.kernel.sysctl = {
        # Minimal routing: this is a host, not a router.
        "net.ipv4.ip_forward" = 0;
        "net.ipv6.conf.all.forwarding" = 0;
        "net.ipv6.conf.default.forwarding" = 0;
        "net.ipv4.conf.all.route_localnet" = 0;

        # Never let a packet from the LAN re-route us: no ICMP redirects in
        # either direction, no source routing, log what rp_filter drops.
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.secure_redirects" = 0;
        "net.ipv4.conf.default.secure_redirects" = 0;
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.default.accept_source_route" = 0;
        "net.ipv4.conf.all.log_martians" = 1;
        "net.ipv4.conf.default.log_martians" = 1;
        "net.ipv4.conf.all.ignore_routes_with_linkdown" = 1;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.default.accept_source_route" = 0;

        # Router Advertisements: take the prefix for SLAAC, nothing else. No
        # Route Information Options (bad prefix announcements by RA), no
        # router-preference games, no RAs from ourselves.
        "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 0;
        "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 0;
        "net.ipv6.conf.all.accept_ra_rtr_pref" = 0;
        "net.ipv6.conf.default.accept_ra_rtr_pref" = 0;
        "net.ipv6.conf.all.accept_ra_from_local" = 0;
        "net.ipv6.conf.default.accept_ra_from_local" = 0;

        # Neighbor tables only change when we asked: no gratuitous ARP, no
        # unsolicited NA, answer ARP only for addresses on that interface.
        "net.ipv4.conf.all.drop_gratuitous_arp" = 1;
        "net.ipv4.conf.default.drop_gratuitous_arp" = 1;
        "net.ipv4.conf.all.arp_ignore" = 1;
        "net.ipv4.conf.default.arp_ignore" = 1;
        "net.ipv4.conf.all.arp_announce" = 2;
        "net.ipv4.conf.default.arp_announce" = 2;
        "net.ipv6.conf.all.drop_unsolicited_na" = 1;
        "net.ipv6.conf.default.drop_unsolicited_na" = 1;
        "net.ipv4.conf.all.drop_unicast_in_l2_multicast" = 1;
        "net.ipv6.conf.all.drop_unicast_in_l2_multicast" = 1;

        "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
        "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
        "net.ipv4.tcp_rfc1337" = 1;
      };

      # Firewall layer for the same things (defense in depth; sysctls can be
      # flipped by a buggy service, nftables rules cannot) plus bogon hygiene.
      networking.nftables.tables.flattoo-edge = {
        family = "inet";
        content = ''
          chain input {
            type filter hook input priority filter - 10; policy accept;
            icmp type redirect drop
            icmpv6 type nd-redirect drop
            # RFC 4861 6.1.2: a Router Advertisement comes from a link-local address or it is not one
            icmpv6 type nd-router-advert ip6 saddr != fe80::/10 drop
            # Sources that cannot legitimately reach a laptop
            iifname != "lo" ip saddr { 0.0.0.0/8, 127.0.0.0/8, 240.0.0.0/4 } drop
            iifname != "lo" ip6 saddr ::1 drop
          }
          chain output {
            type filter hook output priority filter - 10; policy accept;
            # Destinations with no business being routed anywhere (minimal routing);
            # limited broadcast stays (DHCP DISCOVER, printer discovery)
            ip daddr 255.255.255.255 return
            oifname != "lo" ip daddr { 0.0.0.0/8, 127.0.0.0/8, 192.0.0.0/24, 192.0.2.0/24, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 240.0.0.0/4 } drop
            oifname != "lo" ip6 daddr { ::1, 2001:db8::/32 } drop
          }
        '';
      };

      # NetworkManager: no LLMNR (spoofable name resolution), privacy
      # addresses, and do not hand the hostname to every DHCP server.
      networking.networkmanager.connectionConfig = {
        "connection.llmnr" = 0;
        "ipv6.ip6-privacy" = 2;
        "ipv4.dhcp-send-hostname" = false;
        "ipv6.dhcp-send-hostname" = false;
      };

      # Firefox: only HTTPS unless the user says otherwise on a site; the
      # system resolver (validating, DoT) rather than the browser's own DoH.
      programs.firefox.policies = {
        HttpsOnlyMode = "enabled";
        DNSOverHTTPS = {
          Enabled = false;
          Locked = true;
        };
      };
    })

    (lib.mkIf cfg.dns.enable {
      services.unbound = {
        enable = true;
        resolveLocalQueries = true;
        enableRootTrustAnchor = true;
        localControlSocketPath = "/run/unbound/unbound.ctl";
        settings = {
          server = {
            tls-cert-bundle = "/etc/ssl/certs/ca-certificates.crt";
            # Validation and anti-spoofing
            harden-dnssec-stripped = true;
            harden-below-nxdomain = true;
            harden-algo-downgrade = true;
            harden-glue = true;
            val-clean-additional = true;
            aggressive-nsec = true;
            qname-minimisation = true;
            use-caps-for-id = true;
            unwanted-reply-threshold = 10000;
            edns-buffer-size = 1232;
            # Behaviour
            prefetch = true;
            prefetch-key = true;
            serve-expired = false;
            minimal-responses = true;
            hide-identity = true;
            hide-version = true;
            deny-any = true;
            do-not-query-localhost = true;
            val-log-level = 1;
            log-servfail = true;
            # Reverse zones: the AS112 / RFC 6303 zones are unbound defaults
            # (NXDOMAIN locally, never asked upstream). ".local" is mDNS
            # territory (avahi, nss-mdns) and never a unicast DNS query.
            local-zone = [ "\"local.\" always_nxdomain" ];
          };
          forward-zone = [
            {
              name = ".";
              forward-tls-upstream = true;
              forward-addr = upstreamTls;
            }
          ];
        };
      };

      # NetworkManager hands no DNS to resolv.conf; Unbound is the resolver.
      networking.networkmanager.dns = "none";
      networking.networkmanager.settings.connectivity = {
        uri = "http://detectportal.firefox.com/success.txt";
        response = "success";
        interval = 300;
      };
      networking.networkmanager.dispatcherScripts = [
        {
          source = dnsMode;
          type = "basic";
        }
      ];
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "flattoo-dns-mode" ''exec ${dnsMode} "" manual'')
      ];
    })
  ];
}
