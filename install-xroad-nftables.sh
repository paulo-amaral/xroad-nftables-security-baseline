#!/usr/bin/env bash
# Install the X-Road Security Server nftables baseline on Ubuntu Server.
#
# Default run: install nftables, back up the current firewall state,
# install the policy and the variables template, and validate. Nothing
# is applied.
#
# --apply: load the ruleset, then wait for confirmation. Without it, the
# previous ruleset is restored automatically (lockout protection).
#
# Usage: sudo ./install-xroad-nftables.sh [--apply] [--timeout SECONDS]

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nftables"
POLICY=/etc/nftables.conf
VARS_DIR=/etc/nftables.d
VARS="$VARS_DIR/xroad-variables.nft"
STAMP="$(date +%F-%H%M%S)-$$"
BACKUP_DIR="/var/backups/xroad-nftables/$STAMP"

APPLY=0
TIMEOUT=120

while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1 ;;
        --timeout) TIMEOUT="${2:?--timeout needs a value}"; shift ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

log()  { printf '[xroad-nft] %s\n' "$*"; }
fail() { printf '[xroad-nft] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "run as root (sudo)."
[ -f "$SRC_DIR/nftables.conf" ] && [ -f "$SRC_DIR/xroad-variables.nft" ] \
    || fail "missing $SRC_DIR/nftables.conf or xroad-variables.nft."

# Check the operating system (section 17)
# shellcheck source=/dev/null
. /etc/os-release
[ "${ID:-}" = ubuntu ] || fail "this baseline targets Ubuntu Server (found: ${ID:-unknown})."
log "OS: $PRETTY_NAME, kernel $(uname -r)"

# Install nftables (section 17)
if ! command -v nft >/dev/null 2>&1; then
    log "Installing nftables"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nftables
fi
log "$(nft --version)"

# Record the existing firewall state (section 17)
install -d -m 0700 "$BACKUP_DIR"
nft list ruleset > "$BACKUP_DIR/nft-ruleset.conf"
{ command -v ufw >/dev/null && ufw status verbose; } > "$BACKUP_DIR/ufw-status.txt" 2>&1 || true
{ command -v iptables >/dev/null && iptables -S; } > "$BACKUP_DIR/iptables.txt" 2>&1 || true
{ command -v ip6tables >/dev/null && ip6tables -S; } > "$BACKUP_DIR/ip6tables.txt" 2>&1 || true
ss -lntup > "$BACKUP_DIR/listening-sockets.txt" 2>&1 || true
ip -br address > "$BACKUP_DIR/interfaces.txt" 2>&1 || true
[ -f "$POLICY" ] && cp -a "$POLICY" "$BACKUP_DIR/nftables.conf"
[ -f "$VARS" ] && cp -a "$VARS" "$BACKUP_DIR/xroad-variables.nft"
log "Current state saved to $BACKUP_DIR"

# Install policy and variables (sections 6, 7 and 17)
if [ -f "$POLICY" ] && ! cmp -s "$SRC_DIR/nftables.conf" "$POLICY"; then
    log "Replacing $POLICY (previous copy in $BACKUP_DIR). Differences:"
    diff -u "$POLICY" "$SRC_DIR/nftables.conf" | sed "s/^/    /" || true
fi
install -m 0755 -o root -g root "$SRC_DIR/nftables.conf" "$POLICY"
install -d -m 0755 "$VARS_DIR"
if [ -f "$VARS" ]; then
    log "Keeping existing $VARS (operator values are never overwritten)"
else
    install -m 0640 -o root -g root "$SRC_DIR/xroad-variables.nft" "$VARS"
    log "Installed variables template at $VARS"
fi
chown root:root "$VARS"
chmod 0640 "$VARS"

# Unresolved placeholders (section 17). Comments are stripped first: the template's
# comments contain documentation-range examples that would always match.
placeholders="$(sed 's/#.*//' "$POLICY" "$VARS" \
    | grep -nE 'CHANGE_ME|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.' || true)"
if [ -n "$placeholders" ]; then
    log "Interfaces present on this host:"
    ip -br address | sed 's/^/    /'
    fail "unresolved placeholders in $VARS. Edit it (sudoedit $VARS), then run again."
fi

# Syntax validation (section 17) without touching the active firewall
nft -c -f "$POLICY" || fail "nft -c rejected $POLICY. Nothing was applied."
log "Validation passed: $POLICY"

if [ "$APPLY" -eq 0 ]; then
    log "Prepared and validated. Review, then run again with --apply."
    exit 0
fi

# One authoritative firewall (section 18): refuse to stack on top of UFW.
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
    fail "UFW is active. Retire it per your change procedure (section 18) before --apply."
fi

# Apply with automatic rollback (section 17). The rollback runs in its own
# session so it still fires if this SSH session is cut by the new rules.
ROLLBACK="$BACKUP_DIR/rollback.nft"
{ echo 'flush ruleset'; cat "$BACKUP_DIR/nft-ruleset.conf"; } > "$ROLLBACK"
PIDFILE="$BACKUP_DIR/rollback.pid"
setsid bash -c "echo \$\$ > '$PIDFILE'; sleep $TIMEOUT; nft -f '$ROLLBACK'" \
    </dev/null >/dev/null 2>&1 &
sleep 1

nft -f "$POLICY"
log "Ruleset applied. Open a NEW SSH session and test admin access now."
log "Type 'yes' within $TIMEOUT s to keep it; anything else restores the previous ruleset."

answer=""
read -r -t "$TIMEOUT" answer || true
if [ "$answer" != yes ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    nft -f "$ROLLBACK"
    fail "not confirmed. Previous ruleset restored from $ROLLBACK."
fi
kill "$(cat "$PIDFILE")" 2>/dev/null || true
log "Confirmed. Automatic rollback cancelled."

# Persistence (section 17)
systemctl enable nftables
log "nftables enabled at boot. Next: the reboot validation in section 17 and the checklist in section 19."
