{ pkgs, lib, ... }:

{
  # Merged into home.nix's python3.withPackages (one env avoids a bin/python3 collision).
  options.my.cyberPythonLibs = lib.mkOption {
    type = with lib.types; listOf package;
    default = with pkgs.python3Packages; [
      # AD / SMB / WinRM
      termcolor
      aiohttp
      tabulate
      impacket
      pywinrm
      ldap3
      pyasn1
      # workshop reqs (~/Workshops requirements.txt)
      pyyaml
      pycdlib
      lxml
      xmljson
      passlib
      jmespath
      jsonschema
      netaddr
      # HTTP / web
      requests
      httpx
      beautifulsoup4
      xmltodict
      flask
      websocket-client
      # crypto
      cryptography
      pycryptodome
      pyopenssl
      asn1crypto
      # network / recon
      dnspython
      scapy
      paramiko
      python-nmap
      shodan
      # exploit dev / binary
      pwntools
      pefile
      capstone
      ropper
      # output / TUI
      rich
      colorama
    ];
  };

  config.home.packages = with pkgs; [

    # RECON & OSINT
    enum4linux-ng
    theharvester              # email/subdomain harvester
    whois                     # domain info lookup
    dnsrecon                  # Advanced DNS enumeration

    # SCANNING & ENUMERATION
    nmap                      # network scanner
    onesixtyone               # fast SNMP scanner
    snmpcheck                 # Detailed SNMP enumeration
    nuclei

    # WEB APPLICATION TESTING
    burpsuite                 # Intercepting proxy
    sqlmap                    # automatic SQL injection
    gobuster                  # directory/DNS brute-forcer
    ffuf                      # fast web fuzzer
    feroxbuster               # recursive content discovery
    whatweb                   # web technology identifier
    wpscan                    # WordPress scanner (unfree — needs allowUnfree)
    rustscan

    # EXPLOITATION
    metasploit                # exploitation framework

    # PASSWORD ATTACKS
    #john                      # password cracker (john the ripper)
    hashcat                   # — use system /usr/bin/hashcat for OpenCL drivers
    crunch                    # wordlist generator
    chntpw                    # Windows password/registry editor

    # WIRELESS
    aircrack-ng               # wireless WEP/WPA cracking suite
    macchanger                # MAC address spoofer
    bluez                     # bluetooth stack and tools

    # SNIFFING & MITM
    wireshark                 # packet analyzer
    tcpdump                   # packet capture
    bettercap                 # Advanced MITM and network attack tool

    # POST-EXPLOITATION & TUNNELING
    netcat-openbsd            # The Swiss Army Knife of networking
    evil-winrm                # Interactive WinRM shell

    # REVERSE ENGINEERING
    binaryninja-free          # Modern RE platform
    gdb                       # GNU debugger

    # FORENSICS & RECOVERY
    binwalk                   # firmware analysis
    steghide                  # steganography tool
    stegseek                  # fast steghide cracker

    # UTILITIES
    unrar                     # RAR archive extractor
    dos2unix                  # Fix line endings between OS transfers
    inetutils                 # provides telnet, ftp, etc.
    exiftool                  # Metadata analysis
    responder                 # LLMNR/NBT-NS/mDNS poisoner
    # nixpkgs pairs netexec 1.5.1 with an impacket whose LDAPConnection has no
    # `signing` param, so every `nxc ldap` dies in check_ldap_signing with
    # TypeError. Drop the kwarg (pre-signing behavior); impacket still falls
    # back to LDAPS if a DC enforces signing. Remove once nixpkgs realigns them.
    (netexec.overrideAttrs (old: {   # Modern network exploitation (Successor to CME)
      postPatch = (old.postPatch or "") + ''
        substituteInPlace nxc/protocols/ldap.py \
          --replace-fail ', signing=False)' ')' \
          --replace-fail ', signing=self.auth_choice != "simple")' ')'
      '';
    }))
    smbclient-ng              # Enhanced SMB client
    nfs-utils
    zip
    penelope
    metasploit
    httpie
    samba
    #ilspycmd
    openldap
    #apache-directory-studio
    #bloodhound
    #bloodhound-py
    #neo4j
    adalanche
    dig
    thc-hydra
    swaks
    websocat
    qFlipper

  ];
}
