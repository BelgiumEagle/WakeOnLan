# WakeOnLan – VPN-getriggertes Wake-on-LAN fuer macOS

Kleines Bash-Programm, das auf deinem Mac erkennt, wenn du per VPN mit
deinem Heimnetz verbunden bist, und in diesem Moment ein Wake-on-LAN
"Magic Packet" an deinen Desktop-Rechner schickt – so kannst du ihn aus
der Ferne aufwecken, ohne manuell etwas ausloesen zu muessen.

Voraussetzung auf dem Desktop-Rechner: Wake-on-LAN muss in BIOS/UEFI und
im Betriebssystem/Netzwerktreiber aktiviert sein.

## Dateien

- `wol-vpn-watcher.sh` – das eigentliche Skript. Prueft den VPN-Status
  und verschickt das Magic Packet nur beim Herstellen einer neuen
  Verbindung (nicht bei jedem Durchlauf).
- `com.belgiumeagle.wolvpn.plist` – optionale `launchd`-Konfiguration,
  damit das Skript automatisch alle 30 Sekunden im Hintergrund laeuft.

## Einrichtung

### 1. Werte in `wol-vpn-watcher.sh` anpassen

```bash
MAC_ADDRESS="AA:BB:CC:DD:EE:FF"   # MAC-Adresse des Desktop-Rechners
TARGET_IP="192.168.1.255"        # Ziel-IP oder Broadcast-Adresse
VPN_SERVICE_NAME=""              # siehe unten
HOME_SUBNET_PREFIX="192.168.1."  # siehe unten
```

**MAC-Adresse ermitteln:**
- Windows: `getmac` oder `ipconfig /all`
- Linux: `ip link`
- macOS: `ifconfig en0` (bzw. das jeweilige Interface)

**TARGET_IP waehlen:**
- Feste (unicast) IP des Desktop-Rechners im Heimnetz, z.B.
  `192.168.1.50` – funktioniert in der Regel auch ueber eine geroutete
  VPN-Verbindung, sofern der Rechner eine feste IP/DHCP-Reservierung hat.
- Alternativ die Broadcast-Adresse des Heimnetzes, z.B. `192.168.1.255`
  – funktioniert nur, wenn dein VPN-Endpunkt direkt im Heimnetz sitzt
  (z.B. VPN-Server auf der Fritzbox/dem Router) und Broadcasts dorthin
  durchlaesst.

**VPN-Erkennung konfigurieren:**

- **Variante A – macOS-eigenes VPN-Profil** (unter Systemeinstellungen →
  VPN eingerichtet, z.B. IKEv2/IPSec): Servicenamen ermitteln mit

  ```bash
  scutil --nc list
  ```

  und den Namen in `VPN_SERVICE_NAME` eintragen.

- **Variante B – Drittanbieter-VPN-App** (WireGuard, Tailscale, OpenVPN
  Connect u.a., die kein eigenes `scutil`-Profil anlegen):
  `VPN_SERVICE_NAME=""` leer lassen. Es wird dann geprueft, ob eine
  Netzwerkschnittstelle eine IP aus `HOME_SUBNET_PREFIX` hat (Adresse an
  dein tatsaechliches Heimnetz/VPN-Subnetz anpassen).

### 2. Skript ausfuehrbar machen und testen

```bash
chmod +x wol-vpn-watcher.sh
./wol-vpn-watcher.sh
```

Am besten einmal manuell mit bestehender und einmal ohne VPN-Verbindung
testen (Konsolenausgabe prüfen, ggf. `cat "$HOME/Library/Application
Support/WolVpnWatcher/state"`).

### 3. Automatisch im Hintergrund laufen lassen (optional)

```bash
mkdir -p ~/wol-vpn-watcher
cp wol-vpn-watcher.sh ~/wol-vpn-watcher/
# Pfad in der plist an deinen Benutzernamen anpassen:
sed -i '' "s#/Users/DEIN_BENUTZERNAME/wol-vpn-watcher/wol-vpn-watcher.sh#$HOME/wol-vpn-watcher/wol-vpn-watcher.sh#" com.belgiumeagle.wolvpn.plist
cp com.belgiumeagle.wolvpn.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.belgiumeagle.wolvpn.plist
```

Danach prueft macOS alle 30 Sekunden im Hintergrund, ob eine VPN-Verbindung
besteht, und weckt den Desktop-Rechner beim Verbindungsaufbau automatisch.

Logs liegen unter `/tmp/wol-vpn-watcher.log` bzw. `.err`.

Zum Deaktivieren:

```bash
launchctl unload ~/Library/LaunchAgents/com.belgiumeagle.wolvpn.plist
```

## Hinweise

- `nc` (netcat) ist auf macOS vorinstalliert, es werden keine
  zusaetzlichen Tools benoetigt.
- Falls das Magic Packet den Rechner nicht aufweckt, zuerst pruefen, ob
  Wake-on-LAN im Netzwerk (nicht nur im LAN) ueberhaupt funktioniert,
  z.B. indem du es einmal aus dem lokalen Heimnetz heraus testest.
