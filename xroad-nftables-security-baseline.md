# X-Road Security Server - nftables Firewall and Interoperability Security Baseline

**Platform:** Ubuntu Server
**Firewall:** nftables
**Document date:** 2026-09-21
**Authors:**

- Paulo Amaral - <paulo.s.amaral@outlook.com>

> This document adapts the original UFW guidance to native `nftables`
> and extends it into a security baseline for X-Road interoperability.
> It is intended as a deployment template and audit aid. All placeholder
> addresses, networks, interfaces and service endpoints MUST be replaced
> with values approved for the target X-Road instance before activation.

---

## 1. Purpose

The objective is to protect an X-Road Security Server while preserving
all communication required for:

- Security Server and Security Server message exchange;
- Security Server and Central Server communication;
- Security Server and Management/Monitoring Security Server
    communication;
- global configuration distribution;
- OCSP validation;
- timestamping;
- Consumer Information System and Security Server communication;
- Security Server and Producer Information System communication;
- X-Road administration;
- local communication among X-Road components;
- DNS, NTP, mail and controlled software updates.

The baseline follows a **default-deny** model for inbound, outbound and
forwarded traffic. A connection is permitted only when it has a
documented purpose.

---

## 2. Scope and Operator policy

This document provides a security baseline for deploying nftables on an X-Road Security Server. It is not an NIIS-mandated firewall configuration.

X-Road defines the network communication required between its components. Unless X-Road documentation explicitly requires otherwise, the decision to restrict a reachable endpoint to specific source or destination IP addresses remains an Operator security policy decision.

Publicly discoverable information and network access control address different risks. A public service catalogue or publicly available Global Configuration does not remove the value of firewall controls. Filtering can still reduce unnecessary exposure, automated scanning, unauthorised connection attempts and denial-of-service surface. Conversely, IP allowlisting introduces operational overhead and can affect onboarding when addresses must be registered before Security Server initialisation.

This baseline therefore distinguishes between:

- X-Road technical communication requirements;
- security hardening recommendations;
- administrative and internal interfaces that should be restricted;
- Operator Policy Decisions where public accessibility or IP allowlisting may both be valid deployment models.

> **Important:** An X-Road network dependency identifies communication that may be required. It must not automatically be interpreted as a requirement to expose that port publicly.

## 3. Security principles

### 2.1 Default deny

The firewall uses:

``` nft
policy drop;
```

for `input`, `output`, and `forward`.

This is important because outbound filtering is part of the security
boundary. A compromised Security Server should not automatically be able
to establish arbitrary connections to the Internet.

### 2.2 Stateful filtering

Established and related connections are permitted:

``` nft
ct state established,related accept
ct state invalid drop
```

Therefore, a separate reverse-direction rule is normally unnecessary for
replies belonging to an already authorised connection.

### 2.3 Source and destination allowlisting

Where infrastructure addresses are stable, access should be restricted
by both:

1. protocol/port; and
2. authorised source or destination IP/network.

Opening a port globally merely because X-Road uses that port is not
equivalent to authorising the required X-Road relationship.

### 2.4 Administrative isolation

TCP/4000 and TCP/22 MUST be reachable only from an approved management
network, bastion host or administrative VPN.

TCP/4000 MUST NOT be exposed directly to the public Internet.

### 2.5 Information System isolation

TCP/8080 and TCP/8443 are local Information System access points. They
should be reachable only from explicitly authorised Consumer Information
Systems.

### 2.6 Local X-Road services remain local

The X-Road components that normally communicate over loopback MUST NOT
be exposed through a physical interface merely because their ports
appear in X-Road documentation.

The firewall therefore permits loopback as a whole:

``` nft
iifname "lo" accept
oifname "lo" accept
```

while the default-deny policy prevents those local service ports from
being reachable externally unless a separate rule is deliberately
created.

---

## 4. X-Road communication matrix

  ---------------------------------------------------------------------------------------------
  Source       Destination             Port Protocol    Purpose           Firewall policy
  ------------ ------------- -------------- ----------- ----------------- ---------------------
  Peer         Security                5500 TCP         X-Road message    Allow only known
  Security     Server                                   exchange          peers where
  Server                                                                  operationally
                                                                          feasible

  Security     Peer Security           5500 TCP         X-Road message    Allow known peers
  Server       Server                                   exchange

  Peer         Security                5577 TCP         OCSP response     Allow only known
  Security     Server                                   queries between   peers where feasible
  Server                                                Security Servers  

  Security     Peer Security           5577 TCP         OCSP response     Allow known peers
  Server       Server                                   queries

  Security     Central                 4001 TCP         Authentication    Restrict to Central
  Server       Server                                   certificate       Server
                                                        registration /
                                                        Central Server
                                                        communication

  Security     Central               80/443 TCP         Global            Restrict to Central
  Server       Server                                   configuration     Server / approved
                                                                          configuration
                                                                          endpoints

  Security     Management         5500/5577 TCP         Management        Restrict to
  Server       Security                                 services          Management Security
               Server                                                     Server

  Monitoring   Security           5500/5577 TCP         Ecosystem         Restrict to
  Security     Server                                   monitoring        Monitoring Security
  Server                                                                  Server

  Consumer IS  Security           8080/8443 TCP         Information       Internal allowlist
               Server                                   System access     only
                                                        point

  Security     Producer IS     80/443/other TCP         Service           Allow only
  Server                                                invocation        registered/approved
                                                                          IS endpoints

  Admin        Security                4000 TCP         Admin UI /        Management network
  network      Server                                   Management REST   only
                                                        API

  Admin        Security                  22 TCP         SSH               Management network
  network      Server                                                     only

  ACME server  Security                  80 TCP         ACME HTTP         Disabled unless
               Server                                   challenge         actually required

  Security     OCSP                  80/443 TCP         Certificate       Approved endpoints
  Server                                                status validation only where feasible

  Security     TSA                   80/443 TCP         Timestamping      Approved endpoints
  Server                                                                  only where feasible

  Security     Mail server              587 TCP         Notifications     Approved mail server
  Server                                                                  only

  Security     DNS                       53 UDP/TCP     Name resolution   Approved resolvers
  Server                                                                  only

Security     NTP                      123 UDP         Time              Approved NTP servers
  Server                                                synchronisation   only
  ---------------------------------------------------------------------------------------------

The exact set of connections depends on the X-Road instance
architecture. Do not enable optional flows merely because they are
listed here.

---

## 5. Local X-Road component communication

The following ports are normally local to the Security Server and should
remain protected by the loopback boundary:

  ------------------------------------------------------------------------
  Component                         Port Protocol         Expected
                                                          exposure
  ---------------- --------------------- ---------------- ----------------
  PostgreSQL                        5432 TCP              Loopback/local
                                                          only

  Operational                       2080 TCP              Loopback by
  Monitoring                                              default

  Environmental                     2552 TCP              Loopback/local
  Monitoring

  Signer admin                      5559 TCP              Loopback/local

  Signer gRPC                       5560 TCP              Loopback/local

  Proxy admin                       5566 TCP              Loopback/local

  Proxy gRPC                        5567 TCP              Loopback/local

  Configuration                     5675 TCP              Loopback/local
  Client

Audit log                          514 UDP              Local unless an
                                                          approved remote
                                                          logging
                                                          architecture is
                                                          explicitly
                                                          configured
  ------------------------------------------------------------------------

**Important:** no external nftables rule is required for a service that
listens only on `127.0.0.1`/`::1`.

If Operational Monitoring or another component is intentionally moved to
another host, treat that as an architectural exception: document both
endpoints, restrict the firewall to those exact hosts, and use the
X-Road-supported TLS configuration. X-Road documentation strongly
advises HTTPS for an external Operational Monitoring daemon.

---

## 6. Deployment parameters and file separation

Environment-specific values should not be embedded in the firewall policy. Keep the deployment parameters in a separate nftables file and include that file from the main ruleset.

Recommended structure:

```text
/etc/nftables.conf
/etc/nftables.d/xroad-variables.nft
```

`/etc/nftables.conf` contains the firewall policy and should normally change only when the security policy changes.

`/etc/nftables.d/xroad-variables.nft` contains interface names, server addresses and authorised networks. Routine infrastructure changes should normally be limited to this file.

This separation provides a clearer distinction between policy changes and configuration changes and reduces the risk of modifying firewall logic when only an address changes.

### 5.1 `/etc/nftables.d/xroad-variables.nft`

Create the directory if required:

```bash
sudo install -d -m 0755 /etc/nftables.d
sudoedit /etc/nftables.d/xroad-variables.nft
```

Use the following template:

```nft
# ============================================================
# X-Road deployment parameters
# ============================================================
#
# This file contains environment-specific values only.
# Do not define firewall policy or filtering rules here.
#
# Replace every CHANGE_ME value before activation.
#
# Validate the complete configuration after any change:
#
#   sudo nft -c -f /etc/nftables.conf
#
# Examples below are syntax examples only. Addresses from
# 192.0.2.0/24, 198.51.100.0/24 and 203.0.113.0/24 are
# documentation ranges and must not be copied into production.
#
# Do not use example or documentation IP addresses in
# production configuration.


# ============================================================
# Value syntax quick reference
# ============================================================
#
# Use commas to separate multiple addresses or networks.
#
# One IP address:
#   define CENTRAL_SERVERS = { 203.0.113.30 }
#
# Multiple IP addresses:
#   define CENTRAL_SERVERS = {
#       203.0.113.30,
#       203.0.113.31,
#       203.0.113.32
#   }
#
# One network:
#   define ADMIN_NETWORKS = { 10.30.30.0/24 }
#
# Multiple networks:
#   define ADMIN_NETWORKS = {
#       10.30.30.0/24,
#       10.40.40.0/24
#   }
#
# A single value may be written on one line. For two or more
# values, one entry per line is recommended for easier review
# and change control.
#
# Do not add a comma after the final entry. This convention
# keeps the configuration consistent and easy to review.


# ------------------------------------------------------------
# Network interfaces
# ------------------------------------------------------------

# Interface used for communication with X-Road infrastructure,
# peer Security Servers and external trust services.
#
# Identify the correct interface with:
#   ip -br address
#   ip route
# Example: define EXT_IF = "ens18"
define EXT_IF = "CHANGE_ME"


# Interface connected to Consumer and Producer Information
# Systems.
#
# If the deployment uses a single interface for external and
# internal traffic, document that design and set the appropriate
# interface name here.
# Example: define INT_IF = "ens19"
define INT_IF = "CHANGE_ME"


# Interface used for administrative access.
#
# A dedicated management network, VPN or bastion path is
# preferred for SSH and X-Road administration.
# Example: define MGMT_IF = "ens20"
define MGMT_IF = "CHANGE_ME"


# ------------------------------------------------------------
# Peer Security Servers
# ------------------------------------------------------------

# IP addresses of peer Security Servers authorised to exchange
# X-Road messages with this Security Server when the Operator
# has selected the source-IP allowlisting model.
#
# OPERATOR POLICY DECISION:
# X-Road does not require universal source-IP allowlisting for
# peer message exchange. This baseline uses allowlisting as the
# restrictive deployment model. Operators may choose public
# reachability when it is consistent with their security and
# operational requirements.
#
# These addresses are used for TCP/5500 and TCP/5577.
#
# Maintain this list from the authoritative X-Road instance
# inventory. Remove obsolete addresses through normal change
# control.
# Example with multiple peer servers:
#   define PEER_SECURITY_SERVERS = {
#       203.0.113.10,
#       203.0.113.11,
#       203.0.113.12
#   }
define PEER_SECURITY_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Management Security Server
# ------------------------------------------------------------

# IP address(es) of the Security Server providing X-Road
# management services for this instance.
#
# Keep management servers separate from ordinary peers so that
# management traffic can be reviewed independently.
# Example with one server:
#   define MANAGEMENT_SECURITY_SERVERS = { 203.0.113.20 }
#
# Example with multiple servers:
#   define MANAGEMENT_SECURITY_SERVERS = {
#       203.0.113.20,
#       203.0.113.21
#   }
define MANAGEMENT_SECURITY_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Monitoring Security Server
# ------------------------------------------------------------

# IP address(es) of the Security Server authorised to perform
# central monitoring of this Security Server.
#
# Do not add ordinary member Security Servers to this group.
# Example with one server:
#   define MONITORING_SECURITY_SERVERS = { 203.0.113.21 }
#
# Multiple servers use comma-separated entries:
#   define MONITORING_SECURITY_SERVERS = {
#       203.0.113.21,
#       203.0.113.22
#   }
define MONITORING_SECURITY_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Central Server
# ------------------------------------------------------------

# IP address(es) of the Central Server for this X-Road instance.
#
# Used for Central Server communication and retrieval of global
# configuration.
#
# Values should come from the X-Road Operator's authoritative
# infrastructure configuration.
# Example with one server:
#   define CENTRAL_SERVERS = { 203.0.113.30 }
#
# Example with multiple servers:
#   define CENTRAL_SERVERS = {
#       203.0.113.30,
#       203.0.113.31
#   }
define CENTRAL_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Consumer Information Systems
# ------------------------------------------------------------

# Hosts or networks authorised to submit requests through this
# Security Server.
#
# These systems normally use TCP/8080 and/or TCP/8443.
#
# Use the smallest practical network range. Avoid authorising
# an entire internal network when the actual systems can be
# identified more precisely.
# Example with one network:
#   define CONSUMER_IS_NETWORKS = { 10.10.10.0/24 }
#
# Example with multiple networks:
#   define CONSUMER_IS_NETWORKS = {
#       10.10.10.0/24,
#       10.10.20.0/24
#   }
define CONSUMER_IS_NETWORKS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Producer Information Systems
# ------------------------------------------------------------

# Hosts or networks containing services published through this
# Security Server.
#
# The Security Server connects to these systems when processing
# requests for locally registered X-Road services.
#
# Application ports other than those defined in the baseline
# must be authorised explicitly in the firewall policy.
# Example with one network:
#   define PRODUCER_IS_NETWORKS = { 10.20.20.0/24 }
#
# Example with multiple networks:
#   define PRODUCER_IS_NETWORKS = {
#       10.20.20.0/24,
#       10.20.30.0/24
#   }
define PRODUCER_IS_NETWORKS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Administration network
# ------------------------------------------------------------

# Administrative network, VPN range or bastion host authorised
# to manage this Security Server.
#
# Used by the baseline for:
#   TCP/22   SSH
#   TCP/4000 X-Road Admin UI / Management REST API
#
# TCP/4000 must not be exposed directly to an untrusted network.
# Example with one network:
#   define ADMIN_NETWORKS = { 10.30.30.0/24 }
#
# Example with management LAN and VPN:
#   define ADMIN_NETWORKS = {
#       10.30.30.0/24,
#       10.40.40.0/24
#   }
define ADMIN_NETWORKS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# DNS resolvers
# ------------------------------------------------------------

# Approved DNS resolver address(es).
#
# With default-deny outbound filtering, name resolution will
# fail unless the configured resolver is permitted here.
#
# Verify the active resolver configuration with:
#   resolvectl status
# Example with redundant DNS resolvers:
#   define DNS_SERVERS = {
#       10.0.0.53,
#       10.0.0.54
#   }
define DNS_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# NTP servers
# ------------------------------------------------------------

# Approved time synchronisation server(s).
#
# Accurate system time is required for reliable certificate
# validation, timestamping, signatures and audit records.
#
# Verify the active configuration with:
#   timedatectl status
#   timedatectl timesync-status
# Example with redundant NTP servers:
#   define NTP_SERVERS = {
#       10.0.0.123,
#       10.0.0.124
#   }
define NTP_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Mail server
# ------------------------------------------------------------

# Approved SMTP submission server used for X-Road alerts or
# operational notifications.
#
# The firewall permits SMTP submission only to the destinations
# listed here.
# Example:
#   define MAIL_SERVERS = { 10.0.0.25 }
define MAIL_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# OCSP responders
# ------------------------------------------------------------

# Approved OCSP responder address(es) used for certificate
# revocation-status validation.
#
# Obtain the authoritative endpoints from the X-Road Operator
# or Trust Service Provider.
#
# If an endpoint uses dynamic addressing that cannot be safely
# represented by an IP allowlist, document the required
# exception and its compensating controls.
# Example with multiple OCSP responders:
#   define OCSP_SERVERS = {
#       198.51.100.10,
#       198.51.100.11
#   }
define OCSP_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Timestamping services
# ------------------------------------------------------------

# Approved Timestamp Authority (TSA) address(es).
#
# Obtain the authoritative endpoints from the X-Road Operator
# or Trust Service Provider.
# Example with multiple TSA endpoints:
#   define TSA_SERVERS = {
#       198.51.100.20,
#       198.51.100.21
#   }
define TSA_SERVERS = {
    CHANGE_ME
}


# ------------------------------------------------------------
# Package repositories
# ------------------------------------------------------------

# Approved Ubuntu and X-Road package repository destinations.
#
# If repositories use CDNs or dynamically changing addresses,
# static IP allowlisting may not be operationally appropriate.
# Document the approved alternative instead of enabling
# unrestricted outbound HTTP/HTTPS without review.
# Example with separate Ubuntu and X-Road repositories:
#   define PACKAGE_REPOSITORIES = {
#       10.0.0.80,
#       10.0.0.81
#   }
define PACKAGE_REPOSITORIES = {
    CHANGE_ME
}
```

For maintainability, use one address or CIDR per line when a variable contains multiple values. Separate entries with commas and keep the last entry without a trailing comma. This makes additions and removals easier to review in version control and change records.

The variable file should be readable only by authorised administrators. It does not normally contain credentials, but it documents security-relevant network topology.

Recommended permissions:

```bash
sudo chown root:root /etc/nftables.d/xroad-variables.nft
sudo chmod 0640 /etc/nftables.d/xroad-variables.nft
```

## 7. Recommended `/etc/nftables.conf`

The main ruleset contains policy only. It imports the environment-specific parameters from `/etc/nftables.d/xroad-variables.nft`.

No production IP address should appear directly in this file.

```nft
#!/usr/sbin/nft -f

flush ruleset

# Environment-specific interfaces, server addresses and networks.
# This file must exist and must be completed before the firewall
# is activated.
include "/etc/nftables.d/xroad-variables.nft"

table inet xroad_filter {

    chain input {
        type filter hook input priority filter;
        policy drop;

        # Permit local communication between X-Road components.
        # Services intended for local use should remain bound to
        # loopback and should not receive separate external rules.
        iifname "lo" accept comment "Loopback"

        # Permit response traffic for connections already
        # authorised by this firewall.
        ct state established,related accept

        # Invalid connection-tracking states are not required for
        # normal X-Road operation and are discarded.
        ct state invalid counter drop

        # Permit essential IPv4 control and diagnostic messages.
        # Rate limiting reduces exposure to excessive ICMP traffic.
        ip protocol icmp icmp type {
            destination-unreachable,
            time-exceeded,
            parameter-problem,
            echo-request
        } limit rate 10/second counter accept

        # OPERATOR POLICY DECISION
        #
        # This baseline implements the restrictive model and
        # accepts message exchange only from Security Servers in
        # PEER_SECURITY_SERVERS. X-Road does not require universal
        # source-IP allowlisting for peer message exchange.
        #
        # Operators choosing public peer reachability must replace
        # this rule deliberately and document the associated
        # operational and security decision.
        iifname $EXT_IF ip saddr $PEER_SECURITY_SERVERS \
            tcp dport 5500 ct state new \
            counter accept \
            comment "X-Road message exchange from peer Security Servers"

        # Accept peer OCSP-related X-Road traffic only from
        # authorised Security Servers.
        iifname $EXT_IF ip saddr $PEER_SECURITY_SERVERS \
            tcp dport 5577 ct state new \
            counter accept \
            comment "X-Road OCSP queries from peer Security Servers"

        # Permit the designated Monitoring Security Server to use
        # the X-Road communication ports required for monitoring.
        iifname $EXT_IF ip saddr $MONITORING_SECURITY_SERVERS \
            tcp dport { 5500, 5577 } ct state new \
            counter accept \
            comment "X-Road monitoring traffic"

        # Permit authorised Consumer Information Systems to access
        # the HTTP Information System access point.
        iifname $INT_IF ip saddr $CONSUMER_IS_NETWORKS \
            tcp dport 8080 ct state new \
            counter accept \
            comment "Consumer IS HTTP access point"

        # Permit authorised Consumer Information Systems to access
        # the HTTPS Information System access point.
        iifname $INT_IF ip saddr $CONSUMER_IS_NETWORKS \
            tcp dport 8443 ct state new \
            counter accept \
            comment "Consumer IS HTTPS access point"

        # Restrict SSH to the approved management network and
        # management interface.
        iifname $MGMT_IF ip saddr $ADMIN_NETWORKS \
            tcp dport 22 ct state new \
            counter accept \
            comment "SSH from management network"

        # Restrict the X-Road Admin UI and Management REST API to
        # the approved management network.
        iifname $MGMT_IF ip saddr $ADMIN_NETWORKS \
            tcp dport 4000 ct state new \
            counter accept \
            comment "X-Road administration"

        # ACME / HTTP-01
        #
        # Do not enable inbound TCP/80 by default.
        # Enable it only when the Trust Service Provider and the
        # certificate lifecycle used by this X-Road instance
        # require HTTP-01 validation.
        #
        # The presence of TCP/80 in an X-Road network diagram must
        # not be interpreted as a requirement to expose this port
        # in every deployment.

        # Log denied inbound traffic at a controlled rate.
        # Rate limiting prevents scans or attacks from generating
        # excessive kernel logs.
        limit rate 5/second burst 20 packets \
            counter log prefix "NFT-XROAD-IN-DROP " level warning

        counter drop
    }

    chain output {
        type filter hook output priority filter;
        policy drop;

        # Permit local communication between X-Road components.
        oifname "lo" accept comment "Loopback"

        # Permit response traffic for connections already
        # authorised by this firewall.
        ct state established,related accept
        ct state invalid counter drop

        # Permit message exchange only to registered peer Security
        # Servers listed in the deployment parameter file.
        oifname $EXT_IF ip daddr $PEER_SECURITY_SERVERS \
            tcp dport 5500 ct state new \
            counter accept \
            comment "X-Road message exchange to peer Security Servers"

        # Permit X-Road OCSP-related traffic only to registered
        # peer Security Servers.
        oifname $EXT_IF ip daddr $PEER_SECURITY_SERVERS \
            tcp dport 5577 ct state new \
            counter accept \
            comment "X-Road OCSP queries to peer Security Servers"

        # Permit management-service communication only to the
        # designated Management Security Server.
        oifname $EXT_IF ip daddr $MANAGEMENT_SECURITY_SERVERS \
            tcp dport { 5500, 5577 } ct state new \
            counter accept \
            comment "X-Road management services"

        # Permit Central Server communication on the X-Road
        # registration/management port.
        oifname $EXT_IF ip daddr $CENTRAL_SERVERS \
            tcp dport 4001 ct state new \
            counter accept \
            comment "X-Road Central Server communication"

        # Permit global-configuration retrieval only from the
        # designated Central Server address(es).
        oifname $EXT_IF ip daddr $CENTRAL_SERVERS \
            tcp dport { 80, 443 } ct state new \
            counter accept \
            comment "X-Road global configuration"

        # Permit certificate-status checks only to approved OCSP
        # responders.
        oifname $EXT_IF ip daddr $OCSP_SERVERS \
            tcp dport { 80, 443 } ct state new \
            counter accept \
            comment "Approved OCSP services"

        # Permit timestamp requests only to approved Timestamp
        # Authority endpoints.
        oifname $EXT_IF ip daddr $TSA_SERVERS \
            tcp dport { 80, 443 } ct state new \
            counter accept \
            comment "Approved timestamping services"

        # Permit connections to approved Producer Information
        # Systems on the baseline HTTP/HTTPS service ports.
        # Non-standard application ports require explicit rules.
        oifname $INT_IF ip daddr $PRODUCER_IS_NETWORKS \
            tcp dport { 80, 443 } ct state new \
            counter accept \
            comment "Approved Producer Information Systems"

        # Permit DNS only to approved resolvers.
        ip daddr $DNS_SERVERS udp dport 53 \
            counter accept comment "DNS UDP"

        ip daddr $DNS_SERVERS tcp dport 53 \
            counter accept comment "DNS TCP"

        # Permit time synchronisation only to approved NTP
        # servers.
        ip daddr $NTP_SERVERS udp dport 123 \
            counter accept comment "NTP"

        # Permit SMTP submission only to the approved notification
        # mail server.
        ip daddr $MAIL_SERVERS tcp dport 587 ct state new \
            counter accept comment "SMTP submission"

        # Permit package downloads only from approved Ubuntu and
        # X-Road repository destinations.
        ip daddr $PACKAGE_REPOSITORIES \
            tcp dport { 80, 443 } ct state new \
            counter accept \
            comment "Approved package repositories"

        # Log denied outbound connections. This is useful for
        # detecting missing dependencies and unexpected egress.
        limit rate 5/second burst 20 packets \
            counter log prefix "NFT-XROAD-OUT-DROP " level warning

        counter drop
    }

    chain forward {
        type filter hook forward priority filter;
        policy drop;

        # The Security Server is not intended to operate as a
        # general-purpose router. Forwarded traffic is therefore
        # denied and logged at a controlled rate.
        limit rate 2/second burst 10 packets \
            counter log prefix "NFT-XROAD-FWD-DROP " level warning

        counter drop
    }
}
```

### 6.1 Policy classification in change control

When reviewing a firewall change, record whether it is:

- an **X-Road technical requirement**, required for component communication;
- a **security hardening control**, selected to reduce exposure;
- an **Operator Policy Decision**, where the X-Road architecture permits more than one valid exposure model.

This classification prevents a local hardening decision from being documented as an NIIS or X-Road mandatory requirement.

### 6.2 Configuration management

A change to an IP address or network should normally require modification only to `/etc/nftables.d/xroad-variables.nft`.

A change to permitted protocols, ports, traffic direction or trust relationships is a firewall policy change and should be made in `/etc/nftables.conf` through the applicable security and change-control process.

After any modification:

```bash
sudo nft -c -f /etc/nftables.conf
```

If validation succeeds, review the difference before application:

```bash
sudo diff -u /etc/nftables.conf.backup /etc/nftables.conf
```

Where configuration is maintained in version control, review both the policy file and the variable file as separate change objects.

---

## 8. Global Configuration exposure

The accessibility policy for X-Road Global Configuration endpoints should be defined by the X-Road Operator.

Global Configuration may be intentionally publicly accessible. Restricting access to known Security Server addresses can provide additional defence in depth, but it is not a substitute for X-Road's cryptographic verification of configuration authenticity and integrity.

When IP allowlisting is selected, the Operator must account for operational impact. In particular, the outbound address of a new Security Server may need to be authorised before Security Server initialisation can be completed.

Where member, service and endpoint information is already intentionally published through a public service catalogue, confidentiality of that information should not be the primary justification for restricting Global Configuration.

Relevant security considerations include reduction of unnecessary Internet exposure, denial-of-service surface, automated scanning and probing, vulnerability exploitation against the HTTP service or supporting stack, monitoring and rate limiting, and the operational cost of maintaining accurate allowlists.

The selected model should be documented as an **Operator Policy Decision**.

## 9. Why generic outbound 80/443 is intentionally absent

A rule such as:

``` nft
tcp dport { 80, 443 } accept
```

would permit every local process to connect to any Internet host over
HTTP/HTTPS.

That weakens the value of a default-deny egress policy and makes later
destination-specific rules ineffective as security restrictions.

For a hardened Security Server, HTTP/HTTPS destinations should therefore
be classified into explicit groups:

- Central Server/global configuration;
- OCSP;
- timestamping;
- ACME, if used;
- approved package repositories;
- explicitly approved Information Systems.

Where an external service uses dynamic/CDN addresses that cannot safely
be represented by static nftables sets, this must be treated as a
documented operational exception rather than silently replaced with
unrestricted Internet access.

---

## 10. Security Server communication policy

Ports `5500/tcp` and `5577/tcp` are externally reachable X-Road ports.

The preferred policy is:

``` text
known Security Server IP
       
5500 / 5577
       
this Security Server
```

rather than:

``` text
Internet
  
5500 / 5577
  
this Security Server
```

However, X-Road ecosystems can contain many members, and peer addresses
may change. IP allowlisting therefore requires an operational process.

If the X-Road Operator cannot maintain an authoritative peer-address
inventory, opening `5500/5577` more broadly may be operationally
necessary. That decision should be recorded as an exception with
compensating controls, rather than being mistaken for equivalent
security.

---

## 11. Central, Management and Monitoring services

These are different trust relationships and should not be collapsed into
a generic "X-Road servers" firewall object.

Maintain distinct sets:

``` text
central_servers
management_security_servers
monitoring_security_servers
peer_security_servers
```

This provides:

- least privilege;
- clearer audit evidence;
- easier incident investigation;
- safer address changes;
- a direct mapping between architecture and firewall policy.

---

## 12. Producer and Consumer Information Systems

### Consumer side

A Consumer IS initiates a request to its Security Server using `8080` or
`8443`.

Therefore:

``` text
Consumer IS to Security Server to 8080/8443
```

Only registered or otherwise explicitly approved Consumer IS networks
should be present in `consumer_is_v4`.

### Producer side

The Security Server connects to the Producer IS endpoint configured for
the X-Road service.

Therefore:

``` text
Security Server to Producer IS to service port
```

Do not assume all Producer systems use only `80/443`. If an X-Road
service is legitimately published internally on another port, create a
destination-specific rule for that system and port.

Example:

``` nft
ip daddr 10.20.20.15 tcp dport 8081 accept 
    comment "Population Registry API"
```

This is preferable to opening `8081` to the entire internal network.

---

## 13. Administration plane

The management plane should be separated from interoperability traffic.

Recommended model:

``` text
Administrator
    
VPN / Bastion / Management network
    
22/tcp      SSH
4000/tcp    X-Road Admin UI / REST API
    
Security Server
```

Do not expose TCP/4000 to the Internet.

Where practical:

- use a dedicated management VLAN/interface;
- require VPN or bastion access;
- restrict SSH by source;
- use SSH public-key authentication;
- disable direct root SSH login;
- keep the X-Road Admin UI behind the management boundary;
- configure X-Road Admin UI allowed hostnames to mitigate Host header
    abuse.

---

## 14. IPv6

The ruleset uses an `inet` table, but the address allowlists shown above
are IPv4.

This is deliberate: IPv6 must not become an accidental bypass.

Before production deployment, choose one of two documented approaches:

1. **IPv6 is supported:** define equivalent `ipv6_addr` sets and `ip6`
    rules for every authorised flow.
2. **IPv6 is not part of the architecture:** disable or otherwise block
    it according to the organisation's Ubuntu baseline.

Do not leave IPv6 connectivity unmanaged while assuming IPv4 rules
protect it.

---

## 15. Anti-spoofing and interface separation

When the Security Server has distinct external, internal and management
interfaces, source networks should appear only on their expected
interface.

Examples already included:

``` nft
iifname $EXT_IF ip saddr @peer_security_servers_v4 ...
iifname $INT_IF ip saddr @consumer_is_v4 ...
iifname $MGMT_IF ip saddr @admin_v4 ...
```

This means possession of an allowed source address alone is not
sufficient; the packet must also arrive through the expected network
zone.

For environments with routers, NAT, cloud security groups or virtual
networking, validate what source address is actually visible to the
Ubuntu host before enforcing these rules.

---

## 16. Logging

Rejected traffic is logged with rate limiting:

``` nft
limit rate 5/second burst 20 packets 
    counter log prefix "NFT-XROAD-IN-DROP "
```

Rate limiting is important because unrestricted firewall logging can
itself consume disk, CPU or SIEM capacity during scanning or
denial-of-service activity.

Useful checks:

``` bash
sudo journalctl -k | grep NFT-XROAD
sudo journalctl -k -f
```

Firewall logs should be incorporated into the organisation's retention
and monitoring policy where a central logging/SIEM platform exists.

Do not log application payloads or exchanged X-Road data at the firewall
layer.

---

## 17. Installation and activation on Ubuntu

Ubuntu provides `nftables` as a standard package. The package installs the `nft` command, `/etc/nftables.conf`, and the systemd service used to load the persistent ruleset.

### 15.1 Check the operating system

```bash
cat /etc/os-release
uname -r
```

Record the Ubuntu release and kernel version in the change record before modifying the firewall.

### 15.2 Install nftables

```bash
sudo apt update
sudo apt install -y nftables
```

Confirm the installation:

```bash
nft --version
systemctl status nftables --no-pager
```

Installation does not justify enabling the service immediately. The production ruleset should first be prepared and validated.

### 15.3 Record the existing firewall state

Before making changes:

```bash
sudo nft list ruleset > "$HOME/nftables-before-xroad-$(date +%F-%H%M%S).conf"
sudo ufw status verbose
sudo iptables -S
sudo ip6tables -S
sudo ss -lntup
```

Retain this output with the implementation or change record.

### 15.4 Identify the actual network interfaces

Do not assume interface names such as `eth0` or `ens18`.

```bash
ip -br address
ip route
```

Identify the interfaces used for:

- external X-Road communication;
- internal Information Systems;
- administration.

If one interface serves more than one zone, document that architecture and adjust the interface conditions in the ruleset accordingly.

### 15.5 Prepare the configuration

Create the configuration directory:

```bash
sudo install -d -m 0755 /etc/nftables.d
```

Back up the current main configuration if it already exists:

```bash
sudo cp -a /etc/nftables.conf \
  "/etc/nftables.conf.backup.$(date +%F-%H%M%S)"
```

Prepare the firewall policy:

```bash
sudoedit /etc/nftables.conf
```

Prepare the environment-specific parameters:

```bash
sudoedit /etc/nftables.d/xroad-variables.nft
```

Protect the parameter file:

```bash
sudo chown root:root /etc/nftables.d/xroad-variables.nft
sudo chmod 0640 /etc/nftables.d/xroad-variables.nft
```

Complete every required deployment parameter before applying the ruleset. Do not add production IP addresses directly to `/etc/nftables.conf`.

### 15.6 Validate syntax without changing the active firewall

```bash
sudo nft -c -f /etc/nftables.conf
```

The `-c` option checks the ruleset without applying it. Do not continue if validation returns an error.

Review the file for unresolved example values:

```bash
grep -nE 'CHANGE_ME|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.' \
  /etc/nftables.conf /etc/nftables.d/xroad-variables.nft
```

Production deployment should return no unresolved placeholder addresses.

### 15.7 Protect administrative access

Before applying a default-deny policy:

1. verify the management interface;
2. verify the administrator or VPN source network;
3. verify that SSH access is represented in the deployment parameters;
4. keep a second authenticated SSH session open;
5. ensure console, hypervisor or equivalent out-of-band recovery access is available.

Do not perform the first activation through an unverified remote path without a recovery method.

### 15.8 Apply the validated ruleset

```bash
sudo nft -f /etc/nftables.conf
```

Immediately verify:

```bash
sudo nft list ruleset
sudo nft -a list table inet xroad_filter
```

Test SSH, X-Road administration, Central Server connectivity, peer communication and Information System connectivity before closing the recovery session.

### 15.9 Enable persistence

After the active ruleset has passed the required tests:

```bash
sudo systemctl enable nftables
sudo systemctl restart nftables
sudo systemctl status nftables --no-pager
```

Confirm that the persistent configuration can still be parsed:

```bash
sudo nft -c -f /etc/nftables.conf
```

### 15.10 Reboot validation

A controlled reboot test is recommended before production acceptance.

After reboot:

```bash
sudo systemctl is-active nftables
sudo nft list ruleset
sudo ss -lntup
```

Repeat the connectivity tests defined in the verification section.

---

## 18. UFW migration

Do not independently manage the same host using both a hand-maintained
nftables policy and UFW.

Before migration:

``` bash
sudo ufw status numbered
sudo nft list ruleset
```

Document every existing rule and map it to the new policy.

After the nftables ruleset has been validated and an approved rollback
method exists, retire the previous UFW configuration according to the
organisation's change procedure.

The objective is one authoritative firewall policy, not two overlapping
configuration layers.

---

## 19. Verification checklist

After deployment, verify at least the following.

### Local services

``` bash
sudo ss -lntup
```

Confirm that PostgreSQL, Signer, Proxy, Configuration Client and
monitoring components expected to be local are not unintentionally
listening on `0.0.0.0` or a public interface.

### Firewall

``` bash
sudo nft list ruleset
sudo nft -a list table inet xroad_filter
```

### X-Road services

``` bash
sudo systemctl list-units 'xroad*'
```

### Central Server

Confirm the Security Server can reach the authorised Central Server on:

``` text
4001/tcp
80/tcp or 443/tcp as configured for global configuration
```

### Peer Security Servers

Confirm authorised peers can establish the required X-Road communication
on:

``` text
5500/tcp
5577/tcp
```

and confirm a non-authorised test source cannot.

### Information Systems

Confirm:

``` text
approved Consumer IS to 8080/8443 to Security Server
Security Server to approved Producer IS/service port
```

Also test that an unauthorised internal host cannot access `8080`,
`8443` or `4000`.

### Administration

Verify:

``` text
approved management host to 22/tcp    PASS
approved management host to 4000/tcp  PASS
external/untrusted host to 4000/tcp    BLOCK
```

### Egress

Test that the Security Server can reach required DNS, NTP, Central
Server, OCSP, TSA, mail and repository endpoints.

Then test an arbitrary external destination. Under the hardened policy
it should not be reachable unless explicitly authorised.

---

## 20. Change-control requirements

Every firewall exception should record:

  Field             Required information
  ----------------- -----------------------------------
  Rule ID           Unique change/firewall identifier
  Source            Host/network
  Destination       Host/network
  Protocol          TCP/UDP
  Port              Exact port(s)
  Direction         Inbound/outbound
  X-Road function   Business/technical purpose
  Owner             Responsible system/team
  Justification     Why the flow is necessary
  Approval          Change/security approval
  Start date        Activation date
  Review date       Next validation
  Expiry            Required for temporary exceptions

Avoid rules described only as "required by X-Road." The specific X-Road
relationship should be identified.

---

## 21. Periodic security review

At a defined interval and after material X-Road topology changes:

``` bash
sudo nft list ruleset
sudo ss -lntup
sudo systemctl list-units 'xroad*'
```

Compare the actual state against:

- registered Security Servers;
- Central/Management/Monitoring Server addresses;
- approved Consumer and Producer IS endpoints;
- trust-service endpoints;
- DNS/NTP/mail infrastructure;
- approved package repositories;
- management networks.

Remove obsolete addresses and temporary exceptions.

---

## 22. Additional X-Road hardening

Firewall controls are only one layer.

The X-Road security hardening guidance should also be applied, including
where applicable:

- restrict Admin UI access;
- configure Admin UI `allowed-hostnames`;
- use HTTPS for global configuration where supported and correctly
    configured;
- maintain supported X-Road versions;
- consider the minimum supported client Security Server version on
    service providers;
- protect private keys and software-token PINs;
- use TLS for supported components moved off-host;
- keep the Ubuntu host and X-Road packages patched under controlled
    change management.

---

## 23. Deployment policy summary

The production policy should meet the following conditions:

- inbound, outbound and forwarding policies default to `drop`;
- X-Road peer traffic is limited to approved Security Server addresses where the instance can maintain an authoritative peer inventory;
- Central, Management and Monitoring Security Servers are maintained as separate trust relationships;
- Consumer Information Systems can reach only the required local X-Road access ports;
- Producer Information Systems are restricted by destination and service port;
- SSH and TCP/4000 are limited to the management network;
- local X-Road component ports are not exposed through external interfaces;
- DNS, NTP, mail, OCSP, TSA and package repositories use approved destinations;
- unrestricted outbound TCP/80 and TCP/443 are not enabled by default;
- IPv6 is either explicitly governed by equivalent rules or disabled according to the approved host baseline;
- denied traffic is logged with rate limiting;
- all changes are validated with `nft -c` before application;
- firewall changes are subject to documented change control and periodic review.

The firewall should authorise a defined system relationship, not only a TCP or UDP port.

---

## 24. References

This baseline was checked against the X-Road documentation available on
2026-09-21, particularly:

- X-Road Security Server Installation Guide for Ubuntu - network
    requirements, Security Server firewall recommendations,
    external/internal communication and local component ports.
- X-Road Security Hardening Guide - Admin UI hardening, access
    control and HTTPS global configuration guidance.
- X-Road Security Server User Guide - Central Server connectivity
    and external Operational Monitoring guidance.

Official X-Road documentation portal: `https://docs.x-road.global/`

Ubuntu package and command references used for this revision:

- Ubuntu `nftables` package documentation;
- Ubuntu `nft(8)` manual, including `define`, `include`, `-f`, and `-c` behaviour.

### Important implementation note

X-Road versions and deployment architectures can change. Before
production rollout, compare this baseline with the documentation for the
**exact X-Road version installed in the target environment** and with
the instance-specific architecture approved by the X-Road Operator.
