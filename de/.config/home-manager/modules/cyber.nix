{ pkgs, ... }:

{
  home.packages = with pkgs; [

    # RECON & OSINT
    enum4linux                # SMB/Samba enumeration
    theharvester              # email/subdomain harvester
    whois                     # domain info lookup
    dnsrecon                  # Advanced DNS enumeration

    # SCANNING & ENUMERATION
    nmap                      # network scanner
    onesixtyone               # fast SNMP scanner
    nikto                     # web server scanner
    snmpcheck                 # Detailed SNMP enumeration
    nuclei

    # WEB APPLICATION TESTING
    burpsuite                 # Intercepting proxy
    sqlmap                    # automatic SQL injection
    gobuster                  # directory/DNS brute-forcer
    ffuf                      # fast web fuzzer
    feroxbuster               # recursive content discovery
    wfuzz                     # web fuzzer
    whatweb                   # web technology identifier
    wpscan                    # WordPress scanner (unfree — needs allowUnfree)
    rustscan

    # EXPLOITATION
    metasploit                # exploitation framework
    exploitdb                 # searchsploit local exploit database

    # PASSWORD ATTACKS
    #john                      # password cracker (john the ripper)
    hashcat                   # — use system /usr/bin/hashcat for OpenCL drivers
    thc-hydra                 # network login brute-forcer
    ncrack                    # network auth cracker
    medusa                    # parallel login brute-forcer
    crunch                    # wordlist generator
    chntpw                    # Windows password/registry editor
    fcrackzip                 # zip password cracker

    # WIRELESS
    aircrack-ng               # wireless WEP/WPA cracking suite
    kismet                    # wireless network detector/sniffer
    macchanger                # MAC address spoofer
    iw                        # wireless configuration tool
    bluez                     # bluetooth stack and tools

    # SNIFFING & MITM
    wireshark                 # packet analyzer
    tcpdump                   # packet capture
    bettercap                 # Advanced MITM and network attack tool

    # POST-EXPLOITATION & TUNNELING
    netcat-openbsd            # The Swiss Army Knife of networking
    openvpn                   # VPN client/server for HTB/THM
    evil-winrm                # Interactive WinRM shell

    # REVERSE ENGINEERING
    binaryninja-free          # Modern RE platform
    gdb                       # GNU debugger

    # FORENSICS & RECOVERY
    binwalk                   # firmware analysis

    # CRYPTO & STEGANOGRAPHY
    steghide                  # steganography tool
    stegseek                  # fast steghide cracker

    # UTILITIES
    unrar                     # RAR archive extractor
    dos2unix                  # Fix line endings between OS transfers
    ethtool                   # Network interface configuration
    inetutils                 # provides telnet, ftp, etc.
    exiftool                  # Metadata analysis
    responder                 # LLMNR/NBT-NS/mDNS poisoner
    netexec                   # Modern network exploitation (Successor to CME)
    smbclient-ng              # Enhanced SMB client

  ];
}
