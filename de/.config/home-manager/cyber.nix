{ pkgs, ... }:

{
  home.packages = with pkgs; [

    # RECON & OSINT
    amass                    # subdomain enumeration
    arping                   # ARP-level ping
    arp-scan                 # ARP network scanner
    dnsenum                  # DNS enumeration
    dnsrecon                 # DNS recon
    dnstracer                # trace DNS delegations
    enum4linux               # SMB/Samba enumeration
    fierce                   # DNS recon
    hping                    # TCP/IP packet assembler
    masscan                  # fast port scanner
    netmask                  # network mask calculator
    p0f                      # passive OS fingerprinting
    theharvester             # email/subdomain harvester
    whois                    # domain info lookup

    # SCANNING & ENUMERATION
    nmap                     # network scanner
    onesixtyone              # fast SNMP scanner
    sslscan                  # SSL/TLS scanner
    ssldump                  # SSL/TLS traffic analyzer
    swaks                    # SMTP test tool
    nikto                    # web server scanner
    lynis                    # security auditing

    # WEB APPLICATION TESTING
    burpsuite
    sqlmap                   # automatic SQL injection
    gobuster                 # directory/DNS brute-forcer
    ffuf                     # fast web fuzzer
    feroxbuster              # recursive content discovery
    wfuzz                    # web fuzzer
    whatweb                  # web technology identifier
    wpscan                   # WordPress vulnerability scanner (unfree — needs allowUnfree)

    # EXPLOITATION
    metasploit               # exploitation framework

    # PASSWORD ATTACKS
    john                     # password cracker (john the ripper)
    hashcat                  # GPU password cracker
    thc-hydra                # network login brute-forcer (kali: "hydra")
    ncrack                   # network auth cracker
    medusa                   # parallel login brute-forcer
    crunch                   # wordlist generator
    chntpw                   # Windows password/registry editor
    fcrackzip                # zip password cracker

    # WIRELESS
    aircrack-ng              # wireless WEP/WPA cracking suite
    bully                    # WPS brute-force
    cowpatty                 # WPA-PSK offline cracker
    kismet                   # wireless network detector/sniffer
    macchanger               # MAC address spoofer
    pixiewps                 # offline WPS brute-force (pixie dust)
    wifite2                  # automated wireless auditing
    iw                       # wireless configuration tool
    bluez                    # bluetooth stack and tools

    # SNIFFING & MITM
    wireshark                # packet analyzer
    tcpdump                  # packet capture
    tcpreplay                # replay pcap files
    tcpflow                  # TCP flow recorder
    netsniff-ng              # high-performance packet toolkit
    dsniff                   # network auditing/sniffing
    mitmproxy                # interactive HTTPS proxy
    sslsplit                 # transparent SSL/TLS interceptor

    # POST-EXPLOITATION & TUNNELING
    netcat-openbsd
    socat                    # multipurpose relay
    iodine                   # DNS tunnel
    proxychains-ng           # proxy chaining (kali: proxychains4)
    sshuttle                 # transparent proxy over SSH
    stunnel                  # SSL/TLS tunneling
    sslh                     # protocol multiplexer
    openvpn                  # VPN client/server

    # REVERSE ENGINEERING
    binaryninja-free
    radare2                  # command-line RE framework
    rizin                    # radare2 fork
    gdb                      # GNU debugger
    nasm                     # x86 assembler
    apktool                  # Android APK decompiler

    # FUZZING
    aflplusplus              # coverage-guided fuzzer
    spike                    # protocol fuzzer

    # FORENSICS & RECOVERY
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

    # CRYPTO & STEGANOGRAPHY
    steghide                 # steganography tool
    stegseek                 # fast steghide cracker
    ccrypt                   # secure encryption

    # HARDWARE & EMBEDDED
    flashrom                 # flash chip programmer
    openocd                  # JTAG debugger
    minicom                  # serial terminal

    # UTILITIES
    unrar
    dos2unix
    plocate                  # fast file finder
    ethtool
    inetutils                # provides telnet, ftp, etc.
    axel                     # download accelerator
    exiftool
  ];
}
