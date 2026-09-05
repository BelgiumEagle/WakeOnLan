#!/bin/bash
#
# wol-vpn-watcher.sh
#
# Prueft, ob dieser Mac gerade per VPN mit dem Heimnetz verbunden ist, und
# schickt in diesem Fall genau einmal (pro Verbindungsaufbau) ein
# Wake-on-LAN "Magic Packet" an den Desktop-Rechner zu Hause.
#
# Gedacht zum manuellen Aufruf oder als wiederkehrender Job ueber launchd
# (siehe com.belgiumeagle.wolvpn.plist).

set -euo pipefail

# ---------------------------------------------------------------------------
# Konfiguration - bitte anpassen!
# ---------------------------------------------------------------------------

# MAC-Adresse des Desktop-Rechners (Netzwerkkarte, nicht WLAN falls per Kabel)
MAC_ADDRESS="2c:f0:5d:d9:e9:b7"

# Ziel-IP fuer das Magic Packet:
#  - entweder die feste IP des Desktop-Rechners im Heimnetz (Unicast,
#    funktioniert meist auch ueber eine geroutete VPN-Verbindung)
#  - oder die Broadcast-Adresse des Heimnetzes, z.B. 192.168.2.255
#    (funktioniert nur, wenn dein VPN-Endpunkt direkt im Heimnetz haengt,
#    z.B. VPN-Server auf dem Router)
TARGET_IP="192.168.2.100"
WOL_PORT=9

# Wie wird erkannt, dass die VPN-Verbindung steht?
#
# Variante A (macOS-eigenes VPN-Profil unter Systemeinstellungen > VPN):
#   Name des Dienstes eintragen, wie er in "scutil --nc list" erscheint.
VPN_SERVICE_NAME=""

# Variante B (Fallback, z.B. bei WireGuard/Tailscale/OpenVPN-Apps ohne
#   eigenes scutil-Profil): Es wird geprueft, ob irgendeine Netzwerk-
#   schnittstelle eine IP aus dem Heimnetz besitzt. Nur relevant, wenn
#   VPN_SERVICE_NAME oben leer gelassen wird.
HOME_SUBNET_PREFIX="192.168.2."

# Datei, in der der zuletzt erkannte Verbindungsstatus gespeichert wird,
# damit das Magic Packet nur beim Herstellen der Verbindung (nicht bei
# jedem Lauf) verschickt wird.
STATE_FILE="${HOME}/Library/Application Support/WolVpnWatcher/state"

# ---------------------------------------------------------------------------
# Ab hier muss nichts mehr angepasst werden
# ---------------------------------------------------------------------------

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

is_vpn_connected() {
    if [[ -n "$VPN_SERVICE_NAME" ]]; then
        local status
        status=$(scutil --nc status "$VPN_SERVICE_NAME" 2>/dev/null | head -n1 || true)
        [[ "$status" == "Connected" ]]
        return $?
    fi

    ifconfig 2>/dev/null | grep -q "inet ${HOME_SUBNET_PREFIX}"
}

send_magic_packet() {
    local mac_hex packet
    mac_hex=$(echo "$MAC_ADDRESS" | tr -d ':-' | tr '[:lower:]' '[:upper:]')

    if [[ ! "$mac_hex" =~ ^[0-9A-F]{12}$ ]]; then
        log "Fehler: Ungueltige MAC-Adresse '$MAC_ADDRESS'"
        exit 1
    fi

    packet="ffffffffffff"
    for _ in $(seq 1 16); do
        packet+="$mac_hex"
    done

    printf '%b' "$(echo "$packet" | sed 's/../\\x&/g')" | nc -u -w1 "$TARGET_IP" "$WOL_PORT"
}

mkdir -p "$(dirname "$STATE_FILE")"
previous_state="disconnected"
[[ -f "$STATE_FILE" ]] && previous_state=$(cat "$STATE_FILE")

if is_vpn_connected; then
    if [[ "$previous_state" != "connected" ]]; then
        log "VPN-Verbindung erkannt - sende Wake-on-LAN Paket an $MAC_ADDRESS ($TARGET_IP:$WOL_PORT)"
        send_magic_packet
    fi
    echo "connected" > "$STATE_FILE"
else
    echo "disconnected" > "$STATE_FILE"
fi
