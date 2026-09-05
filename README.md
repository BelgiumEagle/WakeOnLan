# WakeOnLan – VPN-getriggertes Wake-on-LAN fuer macOS

Kleines Programm, das automatisch ein Wake-on-LAN "Magic Packet" an
deinen Desktop-Rechner zu Hause schickt, sobald du dich per (Open-)VPN
mit dem Heimnetz verbindest – so kannst du ihn aus der Ferne aufwecken,
ohne manuell etwas ausloesen zu muessen.

Voraussetzung auf dem Desktop-Rechner: Wake-on-LAN muss in BIOS/UEFI und
im Betriebssystem/Netzwerktreiber aktiviert sein.

Aktuell konfiguriert fuer:
- MAC-Adresse: `2c:f0:5d:d9:e9:b7`
- IP im Heimnetz: `192.168.2.100`

## Empfohlen: Tunnelblick-Hook (sofortiger Trigger)

Da du dich per **Tunnelblick** mit OpenVPN verbindest, ist das die
einfachste und schnellste Loesung: Tunnelblick kann eigene Skripte
ausfuehren, sobald die Verbindung inklusive Routen vollstaendig steht –
das Magic Packet wird dann sofort verschickt, ohne Wartezeit.

Datei: `tunnelblick/route-up.tunnelblick.sh`

### Installation

1. Tunnelblick-Konfigurationsordner in Finder oeffnen:
   `~/Library/Application Support/Tunnelblick/Configurations/`
2. Rechtsklick auf deine `<DeineKonfiguration>.tblk` → **Show Package
   Contents** (Paketinhalt zeigen).
3. In den Ordner `Contents/Resources/` wechseln.
4. `tunnelblick/route-up.tunnelblick.sh` aus diesem Repo dorthin kopieren
   (Dateiname exakt `route-up.tunnelblick.sh` beibehalten).
5. Im Terminal ausfuehrbar machen:

   ```bash
   chmod 744 ~/"Library/Application Support/Tunnelblick/Configurations/DeineKonfiguration.tblk/Contents/Resources/route-up.tunnelblick.sh"
   ```

6. Tunnelblick beenden und neu starten, damit es die neue Konfiguration
   inkl. Skript neu einliest.
7. Verbinden und testen: In Tunnelblick's Verbindungs-Log (VPN Details →
   deine Konfiguration → Log) sollte nach dem Verbindungsaufbau die
   Zeile `wol: Wake-on-LAN Magic Packet an 2c:f0:5d:d9:e9:b7
   (192.168.2.100:9) gesendet` erscheinen.

Falls Tunnelblick das Skript nicht automatisch ausfuehrt: In den
Tunnelblick-Einstellungen der Konfiguration unter **Advanced** pruefen,
ob eine Option zum Zulassen eigener Skripte aktiviert werden muss (je
nach Tunnelblick-Version unterschiedlich benannt).

Aendert sich MAC-Adresse oder IP des Desktop-Rechners, einfach die drei
Variablen am Anfang von `tunnelblick/route-up.tunnelblick.sh` anpassen
und die Datei erneut in den `.tblk`-Ordner kopieren.

## Alternative/Fallback: Hintergrund-Polling per launchd

Zusaetzlich (oder falls der Tunnelblick-Hook aus irgendeinem Grund nicht
greift) liegt ein client-unabhaengiger Watcher bei, der alle 30 Sekunden
prueft, ob eine VPN-Verbindung besteht, und beim Verbindungsaufbau
ebenfalls das Magic Packet schickt. Die Erkennung funktioniert bei einer
Tunnelblick/OpenVPN-Verbindung, die dir eine IP aus deinem Heimnetz
(`192.168.2.x`) zuweist, bereits ohne weitere Anpassung.

- `wol-vpn-watcher.sh` – das Watcher-Skript.
- `com.belgiumeagle.wolvpn.plist` – optionale `launchd`-Konfiguration.

### Einrichtung

```bash
chmod +x wol-vpn-watcher.sh
./wol-vpn-watcher.sh   # einmal manuell testen (mit und ohne VPN)
```

Automatisch im Hintergrund laufen lassen:

```bash
mkdir -p ~/wol-vpn-watcher
cp wol-vpn-watcher.sh ~/wol-vpn-watcher/
sed -i '' "s#/Users/DEIN_BENUTZERNAME/wol-vpn-watcher/wol-vpn-watcher.sh#$HOME/wol-vpn-watcher/wol-vpn-watcher.sh#" com.belgiumeagle.wolvpn.plist
cp com.belgiumeagle.wolvpn.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.belgiumeagle.wolvpn.plist
```

Logs liegen unter `/tmp/wol-vpn-watcher.log` bzw. `.err`. Zum
Deaktivieren: `launchctl unload ~/Library/LaunchAgents/com.belgiumeagle.wolvpn.plist`.

Falls du statt der IP-Bereichs-Erkennung ein natives macOS-VPN-Profil
(Systemeinstellungen → VPN, z.B. IKEv2/IPSec) nutzt, kannst du stattdessen
den Servicenamen aus `scutil --nc list` in `VPN_SERVICE_NAME` eintragen
– fuer Tunnelblick/OpenVPN ist das nicht noetig, dort bleibt
`VPN_SERVICE_NAME=""` und die IP-Bereichs-Erkennung (`HOME_SUBNET_PREFIX`)
greift.

## Hinweise

- `nc` (netcat) ist auf macOS vorinstalliert, es werden keine
  zusaetzlichen Tools benoetigt.
- Falls das Magic Packet den Rechner nicht aufweckt, zuerst pruefen, ob
  Wake-on-LAN im Netzwerk (nicht nur im LAN) ueberhaupt funktioniert,
  z.B. indem du es einmal aus dem lokalen Heimnetz heraus testest.
