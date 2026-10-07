# X-Road Security Server nftables Security Baseline

A firewall and interoperability security baseline for X-Road Security Servers on Ubuntu Server, using native `nftables`.

It adapts UFW-based guidance to `nftables` and is intended as a deployment template and audit aid.

## Contents

| File | Description |
| --- | --- |
| [`xroad-nftables-security-baseline.md`](xroad-nftables-security-baseline.md) | The baseline (source) |
| [`xroad-nftables-security-baseline.html`](xroad-nftables-security-baseline.html) | Self-contained HTML rendering of the baseline |

The baseline covers:

- default-deny, stateful filtering for input, output and forward chains;
- the X-Road communication matrix (peer Security Servers, Central Server, Management and Monitoring services, OCSP, TSA);
- Consumer and Producer Information System access;
- administration-plane isolation;
- separation of policy (`/etc/nftables.conf`) from deployment parameters (`/etc/nftables.d/xroad-variables.nft`);
- installation, UFW migration, verification checklist, change control and periodic review.

## Configuration layout

```text
/etc/nftables.conf                    # firewall policy; changes only when policy changes
/etc/nftables.d/xroad-variables.nft   # interfaces, server addresses, authorised networks
```

An address change should touch only the variables file. A change to ports, protocols, direction or trust relationships is a policy change. See sections 6 and 7 of the baseline.

## Quick start

Read the full baseline first. Applying a default-deny policy over a remote session without a recovery path can lock you out.

1. Create `/etc/nftables.d/xroad-variables.nft` from the template in section 6 and replace every `CHANGE_ME`.
2. Create `/etc/nftables.conf` from section 7.
3. Validate without applying:

   ```bash
   sudo nft -c -f /etc/nftables.conf
   grep -nE 'CHANGE_ME|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.' \
     /etc/nftables.conf /etc/nftables.d/xroad-variables.nft
   ```

4. Keep a second SSH session and out-of-band console access open, then apply:

   ```bash
   sudo nft -f /etc/nftables.conf
   ```

5. Test, then enable persistence (`sudo systemctl enable nftables`).

Section 17 has the complete procedure, and section 19 the verification checklist.

## Before production

- The address allowlists are IPv4. Either govern IPv6 with equivalent rules or disable it (section 14).
- Peer source-IP allowlisting is marked **Operator Policy Decision**: X-Road does not require it, and the baseline uses it as the restrictive model. Record the choice in change control.
- Inbound TCP/80 for ACME HTTP-01 is disabled by default. Enable it only when the certificate lifecycle requires it.
- Example addresses use documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24) and must not reach production.

## Author

Paulo Amaral <paulo.s.amaral@outlook.com>

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE).
