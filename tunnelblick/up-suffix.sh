#!/bin/bash
#
# up-suffix.sh
#
# Wird von Tunnelblicks eigenem "up"-Skript (client.up.tunnelblick.sh)
# automatisch ausgefuehrt, wenn eine Datei mit genau diesem Namen
# ("up-suffix.sh") im selben Ordner wie die OpenVPN-Konfiguration
# liegt. Der Zeitpunkt ist direkt nach dem Verbindungsaufbau. Schickt
# in diesem Moment ein Wake-on-LAN "Magic Packet" an den Desktop-Rechner
# zu Hause.
#
# WICHTIG: Der Dateiname muss exakt "up-suffix.sh" lauten - andere
# Namen (z.B. "route-up.tunnelblick.sh") werden von Tunnelblick nicht
# erkannt und einfach stillschweigend ignoriert.
#
# Installation: Diese Datei unveraendert nach
#   <DeineKonfiguration>.tblk/Contents/Resources/up-suffix.sh
# kopieren und ausfuehrbar machen. Details siehe README.md.
#
# Hinweis: Tunnelblick fuehrt dieses Skript mit minimaler Umgebung aus
# - daher keine Abhaengigkeit von $HOME o.ae. und absoluter Pfad zu
# "nc".

set -euo pipefail

# ---------------------------------------------------------------------------
# Konfiguration - bitte anpassen, falls sich Rechner/IP aendern!
# ---------------------------------------------------------------------------

MAC_ADDRESS="2c:f0:5d:d9:e9:b7"
TARGET_IP="192.168.2.100"
WOL_PORT=9

# ---------------------------------------------------------------------------

mac_hex=$(echo "$MAC_ADDRESS" | tr -d ':-' | tr '[:lower:]' '[:upper:]')

if [[ ! "$mac_hex" =~ ^[0-9A-F]{12}$ ]]; then
    echo "wol: Ungueltige MAC-Adresse '$MAC_ADDRESS'" >&2
    exit 0
fi

packet="ffffffffffff"
for _ in $(seq 1 16); do
    packet+="$mac_hex"
done

printf '%b' "$(echo "$packet" | sed 's/../\\x&/g')" | /usr/bin/nc -u -w1 "$TARGET_IP" "$WOL_PORT" || true

echo "wol: Wake-on-LAN Magic Packet an $MAC_ADDRESS ($TARGET_IP:$WOL_PORT) gesendet"

# Tunnelblick erwartet Exit-Code 0, unabhaengig vom Ergebnis des WoL-Versands,
# damit die VPN-Verbindung nicht als fehlgeschlagen markiert wird.
exit 0
