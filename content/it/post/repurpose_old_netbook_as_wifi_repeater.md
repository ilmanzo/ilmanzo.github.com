---
title: "Creazione di un router Linux headless"
date: 2026-01-24
tags: ["linux", "void", "networking", "diy", "retro", "tutorial"]
categories: ["hacking","linux"]
---

## 👻 Void in taverna

Ho una taverna e ho un problema: in questa taverna non arriva il segnale Wi-Fi. Ho anche un pezzo di spazzatura elettronica che si rifiuta di morire: un netbook [**Samsung N130 del 2009**](https://en.wikipedia.org/wiki/Samsung_N130).
Ha un processore Atom single-core e 1 GB di RAM. Per gli standard moderni, riesce a malapena ad aprire un browser web. Ma per un terminale Linux, è un *supercomputer*.
Invece di acquistare un generico ripetitore Wi-Fi da una decina di euro, ho deciso di trasformare questo piccolo guerriero in un router Wi-Fi completamente programmabile, sicuro e trasparente utilizzando [**Void Linux**](https://voidlinux.org/). Ecco esattamente come ho fatto.

![qrcode](/img/n130-meme.jpg)


## 💻 La configurazione hardware

* Samsung N130 (scheda Wi-Fi interna: Atheros/Realtek a seconda del modello).
* Una chiavetta Wi-Fi USB economica (Realtek RTL8188EUS) che accumulava polvere in un cassetto.
* Void Linux (versione base, glibc).

Il piano è semplice:
1. La chiavetta USB si connette alla rete Wi-Fi principale di casa al piano superiore.
2. La scheda interna trasmette una nuova rete al piano inferiore.
3. Il netbook instrada il traffico tra le due reti.

---
## 🐧 0: Installazione di Void Linux

Nulla di troppo complicato: basta creare una chiavetta USB dall'immagine ISO, avviarla e seguire l'eccellente [documentazione](https://docs.voidlinux.org/).
Preferisco installare anche alcuni strumenti standard di uso quotidiano come zsh, fzf, ripgrep, starship, zoxide, fdfind e alcuni pacchetti extra di cui avremo bisogno in seguito: wpa_supplicant, dnsmasq, hostapd, cronie, nftables, ttyqr.

Perché proprio **Void Linux**? Beh, è disponibile per architetture a 32 bit, è costantemente aggiornata ed è estremamente parca nei consumi di risorse. Offre un'esperienza d'uso Linux vecchio stile, lineare e semplice.

## 🛜 1: Scelta della scheda (Modalità AP)

Non tutte le schede Wi-Fi sono uguali. Per funzionare come hotspot, una scheda deve supportare la **modalità AP** (Access Point).

Ho installato `iw` e controllato entrambe le schede:

```bash
iw list
```

Ho cercato l'elenco `Supported interface modes` nell'output.

Se contiene la voce `AP`, siamo a posto.

Se riporta solo `managed`, quella scheda può funzionare solo come client (da usare per il Gateway).

Nel mio caso, la scheda interna supportava perfettamente la modalità AP, quindi è diventata l'Access Point, mentre la chiavetta USB è diventata il Gateway.

## 😵 2: Rinominare le interfacce (Udev Rules)

I nomi delle interfacce Linux come `wlp2s0` o `wlp0s29f7u1`... sono impossibili da ricordare. Rinominiamoli in `wlan_ap` (interna) e `wlan_gw` (esterna/USB) così da non fare mai confusione.
Ho creato il file `/etc/udev/rules.d/10-network.rules`:

```Bash
# Internal Card -> wlan_ap
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="00:11:22:33:44:55", NAME="wlan_ap"

# USB Dongle -> wlan_gw
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="aa:bb:cc:dd:ee:ff", NAME="wlan_gw"
```

(Suggerimento: ottieni i tuoi indirizzi MAC usando il comando `ip link`).

Dopo il riavvio, il comando `ip link` ha mostrato i miei nuovi e ordinati nomi.

Se preferisci evitare il riavvio, puoi attivare le regole `udev` con:

```bash
udevadm trigger --verbose --subsystem-match=net --action=add
```

## 🔌 3: Connessione a monte (Il Client)
Ho usato `wpa_supplicant` per connettere la chiavetta USB alla rete Wi-Fi principale di casa.

File: `/etc/wpa_supplicant/wpa_supplicant.conf`

```Ini
ctrl_interface=/run/wpa_supplicant
update_config=1

network={
    ssid="MyUpstairsWiFi"
    psk="SuperSecretHomePassword"
}
```

Il parametro `psk` è una lunga stringa esadecimale, che puoi ottenere con:
`wpa_passphrase "IL_TUO_SSID" "LA_TUA_PASSWORD" | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf`

Successivamente, ho configurato il servizio. Poiché su Void utilizzo `runit`, ho configurato il file di esecuzione del servizio per forzarlo a utilizzare `wlan_gw`:

```bash
cat /var/service/wpa_supplicant/conf 
WPA_INTERFACE=wlan_gw
```

Su Void, per abilitare un servizio e farlo eseguire all'avvio da `runit`, è sufficiente creare un collegamento simbolico (symlink):

```bash
ln -s /etc/sv/wpa_supplicant /var/service/
```


## 🔥 4: L'Hotspot (hostapd)

Ora passiamo alla trasmissione della rete per gli ospiti. Ho installato `hostapd` e l'ho configurato per trasformare la scheda interna in un hotspot.

File: `/etc/hostapd/hostapd.conf`

```Ini
interface=wlan_ap
driver=nl80211
ssid=Basement_Bunker
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=BasementPassword123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
ieee80211n=1
```

Ho abilitato anche questo servizio (`ln -s /etc/sv/hostapd /var/service/`). E subito la rete è apparsa sul mio telefono! Ma connettersi ad essa non portava ancora a nulla.

## 📟 5: Il cervello (IP e DHCP)
Dobbiamo assegnare un IP statico sia all'Access Point che al Gateway.

File: `/etc/dhcpcd.conf`

```Ini
# Gateway act as a plain wifi client device
interface wlan_gw
  static ip_address=192.168.1.99/24
  static routers=192.168.1.1  # main home router with internet connection

# Access Point: Static IP (I am the Captain now)
interface wlan_ap
  static ip_address=192.168.50.1/24
```

In seguito, `dnsmasq` gestisce sia l'assegnazione degli IP ai dispositivi che si connettono alla rete in taverna, sia la risoluzione dei nomi con relativa cache.

File: `/etc/dnsmasq.conf`

```Ini
# Listen only on the local interface (AP)
interface=wlan_ap
interface=lo
bind-interfaces

cache-size=1000
domain-needed
bogus-priv

dhcp-range=192.168.50.100,192.168.50.200,255.255.255.0,12h

server=192.168.1.1
server=8.8.8.8

# Set the default gateway and DNS for clients
dhcp-option=3,192.168.50.1
dhcp-option=6,192.168.50.1
```


## 🪠 6: I collegamenti (Routing e NAT)
Il kernel deve essere autorizzato a far transitare i pacchetti da un'interfaccia all'altra.

File: `/etc/sysctl.d/99-forwarding.conf`

```Ini
net.ipv4.ip_forward=1
```

Infine, `nftables` si occupa del lavoro più pesante: NAT (masquerading), regole di firewall e l'importante correzione MSS Clamping (senza la quale i telefoni Android si connettono ma non riescono a caricare i siti web). Ho preferito questo strumento rispetto al classico `iptables` per mettermi alla prova con qualcosa di più moderno.

File: `/etc/nftables.conf`

```Ruby
#!/usr/sbin/nft -f
flush ruleset

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        # Masquerade traffic leaving the USB dongle
        oifname "wlan_gw" masquerade
    }
}

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iifname "lo" accept
        ct state established,related accept
        ip protocol icmp accept
        
        # Allow DHCP & DNS from the basement
        iifname "wlan_ap" udp dport { 67, 53 } accept
        iifname "wlan_ap" tcp dport 53 accept

        # SECURITY: Block SSH from the basement!
        # Only allow SSH from the main house network (Gateway)
        # Assuming main house is 192.168.1.x
        iifname "wlan_gw" ip saddr 192.168.1.0/24 tcp dport 22 accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
        
        # TCP MSS Clamping: The magic fix for WiFi-to-WiFi bridging
        tcp flags syn tcp option maxseg size set rt mtu

        # Allow traffic flow
        iifname "wlan_ap" oifname "wlan_gw" accept
        iifname "wlan_gw" oifname "wlan_ap" ct state established,related accept
    }
    
    chain output { type filter hook output priority 0; policy accept; }
}
```

## 🤳 7: Un tocco "User Friendly" (Accesso tramite QR Code)
Dato che questo netbook sta appoggiato su uno scaffale, volevo che lo schermo mostrasse qualcosa di utile. Al posto del solito e noioso prompt di login, gli faccio visualizzare un QR code in modo che gli ospiti possano scansionarlo per connettersi (*scan-to-connect*).

Ho installato `ttyqr` e ho aggiunto questo frammento al file `/etc/rc.local`:

```Bash
# Clear screen
echo -e "\033c" > /etc/issue

# Generate QR Code for WiFi
# Format: WIFI:T:WPA;S:MySSID;P:MyPassword;;
ttyqr -t ANSIUTF8 "WIFI:T:WPA;S:Basement_Bunker;P:BasementPassword123;;" >> /etc/issue

# Add text
echo -e "\nScan to join the Bunker!" >> /etc/issue
echo -e "IP: 192.168.50.1" >> /etc/issue
```

Ora la schermata di login TTY ha l'aspetto di un chiosco interattivo!

![qrcode](/img/n130-qrcode.jpg)

(non scansionare questo: la rete e la password mostrate qui non sono reali)

## 👾 Cos'altro si può fare con 1 GB di RAM? 🔊
Poiché la parte router consuma pochissime risorse (meno di 100 MB di RAM), ho deciso di affidare all'N130 qualche altro compito.

1. Jukebox (mpd + ncmpcpp)

Ho installato `mpd` (Music Player Daemon) e ho collegato il netbook a un vecchio altoparlante tramite il jack delle cuffie. In questo modo può riprodurre file musicali locali (disponendo di oltre 100 GB di spazio di archiviazione) e flussi radio internet senza problemi.

Posso controllare il volume e le stazioni radio via SSH o tramite un'applicazione sul telefono, oppure usare l'analizzatore di spettro in `ncmpcpp` direttamente sullo schermo del netbook.

2. Stazione per Retro Gaming

Quando internet va via, posso comunque passare il tempo. Solo qualche esempio:

[`Bastet`](https://libregamewiki.org/Bastet): un clone spietato di Tetris.

[`Ninvaders`](https://ninvaders.sourceforge.net/): Space Invaders nel terminale.

`Moon-buggy`: un gioco di guida a scorrimento orizzontale.

`Pacman4Console`: *Waka Waka*

Tutti questi giochi girano alla perfezione in modalità testo (TTY), richiedendo zero interfaccia grafica (niente Wayland né X11), risparmiando così preziosa memoria RAM per il routing.

## 📜 Verdetto finale
Il mio vecchio N130 è tornato in vita. Si avvia in pochi secondi, gestisce il traffico per l'intera taverna, blocca i tentativi SSH non autorizzati, si aggiorna automaticamente e aiuta persino gli ospiti a connettersi con un QR code. Non male per un portatile che già 10 anni fa era considerato "too slow".

In conclusione... Sì, avrei potuto semplicemente acquistare un ripetitore Wi-Fi invece di passare due ore a configurare un vecchio PC, ma nel frattempo ho imparato molto e salvato dell'hardware dalla discarica. Buon hacking!