#!/bin/bash
set -euo pipefail

echo "[boxer] Configuring outbound firewall..."

# Flush existing rules
iptables -F OUTPUT 2>/dev/null || true

# Default policy: drop all outbound
iptables -P OUTPUT DROP

# INPUT and FORWARD: drop all by default
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P FORWARD DROP

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections (responses to allowed requests)
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Block ICMP to prevent tunneling
iptables -A OUTPUT -p icmp -j DROP

# Allow DNS only to configured resolvers (blocks DNS tunneling)
while IFS= read -r ns; do
    ns="$(echo "$ns" | xargs)"
    [[ -z "$ns" || "$ns" == "#"* ]] && continue
    iptables -A OUTPUT -p udp --dport 53 -d "$ns" -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -d "$ns" -j ACCEPT
done < <(awk '/^nameserver/{print $2}' /etc/resolv.conf)

# --- Allowlisted domains ---

resolve_and_allow() {
    local domain="$1"
    local port="${2:-443}"
    local proto="${3:-tcp}"
    local ips
    ips="$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u)" || return 0
    for ip in $ips; do
        iptables -A OUTPUT -p "$proto" --dport "$port" -d "$ip" -j ACCEPT
    done
}

# Anthropic API and auth
resolve_and_allow "api.anthropic.com"
resolve_and_allow "console.anthropic.com"
resolve_and_allow "claude.ai"
resolve_and_allow "statsig.anthropic.com"

# GitHub (HTTPS + SSH)
resolve_and_allow "github.com"
resolve_and_allow "github.com" 22
resolve_and_allow "api.github.com"

# Package registries
resolve_and_allow "registry.npmjs.org"
resolve_and_allow "pypi.org"
resolve_and_allow "files.pythonhosted.org"

# Configurable extra domains from environment variable
if [[ -n "${BOXER_EXTRA_DOMAINS:-}" ]]; then
    IFS=',' read -ra _domains <<< "$BOXER_EXTRA_DOMAINS"
    for _domain in "${_domains[@]}"; do
        _domain="$(echo "$_domain" | xargs)"  # trim whitespace
        [[ -z "$_domain" ]] && continue
        resolve_and_allow "$_domain"
        echo "[boxer] Allowed extra domain: $_domain"
    done
fi

# --- IPv6: block all outbound by default ---
if command -v ip6tables &>/dev/null; then
    ip6tables -F OUTPUT 2>/dev/null || true
    ip6tables -P OUTPUT DROP 2>/dev/null || true
    ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
    ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    echo "[firewall] IPv6 OUTPUT policy set to DROP"
fi

echo "[boxer] Firewall configured: outbound restricted to allowlisted domains"
