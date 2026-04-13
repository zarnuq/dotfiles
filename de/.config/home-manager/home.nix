{ config, pkgs, lib,... }:

{
  home.username = "miles";
  home.homeDirectory = "/home/miles";
  home.stateVersion = "24.05";

  home.sessionVariables = {
    XDG_DATA_DIRS = "$HOME/.nix-profile/share:/usr/local/share:/usr/share";
    QT_PLUGIN_PATH = "/usr/lib/qt6/plugins:/usr/lib/qt/plugins";
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  xdg.desktopEntries.tidaler = {
    name = "Tidaler";
    exec = "env QT_SCALE_FACTOR=1.5 LD_LIBRARY_PATH=/usr/lib ${config.home.homeDirectory}/.local/bin/tidaler";
    terminal = false;
    type = "Application";
    categories = [ "Audio" "Music" ];
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [

    libsForQt5.qtstyleplugin-kvantum   # for Qt5 apps
    qt6Packages.qtstyleplugin-kvantum  # for Qt6 apps
    antigravity

    # ┌─────────────────────────────────────────────────────────────┐
    # │  CORE PENTESTING                                            │
    # │  Kali top 10 + essential frameworks                         │
    # └─────────────────────────────────────────────────────────────┘
    aircrack-ng              # wireless WEP/WPA cracking suite
    thc-hydra                # network login brute-forcer (kali: "hydra")
    john                     # password cracker (john the ripper)
    metasploit               # exploitation framework
    nmap                     # network scanner (includes ncat, nping, zenmap)
    sqlmap                   # automatic SQL injection
    wireshark                # packet analyzer
    ghidra

    # ┌─────────────────────────────────────────────────────────────┐
    # │  RECON / INFORMATION GATHERING                              │
    # └─────────────────────────────────────────────────────────────┘

    amass                    # subdomain enumeration
    arping                   # ARP-level ping
    dnsenum                  # DNS enumeration
    dnsrecon                 # DNS recon
    dnstracer                # trace DNS delegations
    enum4linux               # SMB/Samba enumeration
    fierce                   # DNS recon
    fping                    # fast parallel ping
    hping                    # TCP/IP packet assembler
    masscan                  # fast port scanner
    netmask                  # network mask calculator
    onesixtyone              # fast SNMP scanner
    p0f                      # passive OS fingerprinting
    ssldump                  # SSL/TLS traffic analyzer
    sslh                     # protocol multiplexer
    sslscan                  # SSL/TLS scanner
    swaks                    # SMTP test tool
    theharvester             # email/subdomain harvester

    # ┌─────────────────────────────────────────────────────────────┐
    # │  VULNERABILITY ANALYSIS                                     │
    # └─────────────────────────────────────────────────────────────┘
    nikto                    # web server scanner
    lynis                    # security auditing

    # ┌─────────────────────────────────────────────────────────────┐
    # │  WEB APPLICATION TESTING                                    │
    # └─────────────────────────────────────────────────────────────┘
    burpsuite
    gobuster                 # directory/DNS brute-forcer
    ffuf                     # fast web fuzzer
    feroxbuster              # recursive content discovery
    wfuzz                    # web fuzzer
    whatweb                  # web technology identifier
    wpscan                   # WordPress vulnerability scanner (unfree — needs allowUnfree)

    # ┌─────────────────────────────────────────────────────────────┐
    # │  PASSWORD ATTACKS                                           │
    # └─────────────────────────────────────────────────────────────┘
    hashcat                  # GPU password cracker
    ncrack                   # network auth cracker
    medusa                   # parallel login brute-forcer
    crunch                   # wordlist generator
    chntpw                   # Windows password/registry editor
    fcrackzip                # zip password cracker

    # ┌─────────────────────────────────────────────────────────────┐
    # │  WIRELESS                                                   │
    # └─────────────────────────────────────────────────────────────┘
    bully                    # WPS brute-force
    cowpatty                 # WPA-PSK offline cracker
    kismet                   # wireless network detector/sniffer
    macchanger               # MAC address spoofer
    pixiewps                 # offline WPS brute-force (pixie dust)
    wifite2                  # automated wireless auditing
    iw                       # wireless configuration tool

    # ┌─────────────────────────────────────────────────────────────┐
    # │  SNIFFING & SPOOFING                                        │
    # └─────────────────────────────────────────────────────────────┘
    tcpdump                  # packet capture
    tcpreplay                # replay pcap files
    tcpflow                  # TCP flow recorder
    ettercap                 # MITM suite
    bettercap                # MITM framework
    dsniff                   # network auditing/sniffing
    mitmproxy                # interactive HTTPS proxy
    netsniff-ng              # high-performance packet toolkit
    sslsplit                 # transparent SSL/TLS interceptor

    # ┌─────────────────────────────────────────────────────────────┐
    # │  POST-EXPLOITATION & TUNNELING                              │
    # └─────────────────────────────────────────────────────────────┘
    iodine                   # DNS tunnel
    proxychains-ng           # proxy chaining (kali: proxychains4)
    sshuttle                 # transparent proxy over SSH
    stunnel                  # SSL/TLS tunneling
    socat                    # multipurpose relay
    netcat-openbsd
    openvpn                  # VPN client/server

    # ┌─────────────────────────────────────────────────────────────┐
    # │  FORENSICS                                                  │
    # └─────────────────────────────────────────────────────────────┘
    sleuthkit                # filesystem forensics
    binwalk                  # firmware analysis
    foremost                 # file carving
    ddrescue                 # data recovery from failing drives
    dcfldd                   # forensic dd
    exiv2                    # EXIF metadata tool
    yara                     # malware pattern matching
    hashdeep                 # recursive hashing
    testdisk                 # partition recovery
    extundelete              # ext3/ext4 file recovery
    pdf-parser               # PDF analysis
    recoverjpeg              # JPEG recovery
    safecopy                 # damaged media recovery

    # ┌─────────────────────────────────────────────────────────────┐
    # │  REVERSE ENGINEERING                                        │
    # └─────────────────────────────────────────────────────────────┘
    binaryninja-free
    radare2                  # command-line RE framework
    rizin                    # radare2 fork
    gdb                      # GNU debugger
    apktool                  # Android APK decompiler
    jadx                     # Java/Android decompiler

    # ┌─────────────────────────────────────────────────────────────┐
    # │  FUZZING                                                    │
    # └─────────────────────────────────────────────────────────────┘
    aflplusplus              # coverage-guided fuzzer
    spike                    # protocol fuzzer

    # ┌─────────────────────────────────────────────────────────────┐
    # │  CRYPTO & STEGO                                             │
    # └─────────────────────────────────────────────────────────────┘
    stegseek
    steghide                 # steganography tool
    ccrypt                   # secure encryption

    # ┌─────────────────────────────────────────────────────────────┐
    # │  HARDWARE                                                   │
    # └─────────────────────────────────────────────────────────────┘
    flashrom                 # flash chip programmer
    openocd                  # JTAG debugger
    minicom                  # serial terminal

    # ┌─────────────────────────────────────────────────────────────┐
    # │  BLUETOOTH                                                  │
    # └─────────────────────────────────────────────────────────────┘
    bluez                    # bluetooth stack and tools

    # ┌─────────────────────────────────────────────────────────────┐
    # │  GENERAL SYSTEM TOOLS                                       │
    # └─────────────────────────────────────────────────────────────┘
    unrar
    dos2unix
    nasm                     # x86 assembler
    plocate                  # fast file finder
    whois
    arp-scan
    ethtool
    inetutils                # provides telnet, ftp, etc.
    axel                     # download accelerator

    # ┌─────────────────────────────────────────────────────────────┐
    # │  PYTHON ECOSYSTEM                                           │
    # └─────────────────────────────────────────────────────────────┘
    (python3.withPackages (ps: with ps; [
      scapy
      impacket
      virtualenv
      pip
      icalendar
      recurring-ical-events
      x-wr-timezone
    ]))
    pipx

    # ┌─────────────────────────────────────────────────────────────┐
    # │  LIBS                                                       │
    # └─────────────────────────────────────────────────────────────┘
    dejavu_fonts
    fontconfig

  ];
}
