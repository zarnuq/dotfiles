#!/bin/bash

packages=(
  metasploit        # Popular penetration testing framework for exploit development and scanning
  netexec           # Swiss army knife for pentesting Active Directory and network protocols
  enum4linux        # Tool for gathering information from Windows machines via SMB
  ffuf              # Fast web fuzzer for discovering files, directories, parameters
  ghidra            # NSA's open-source reverse engineering suite
  binaryninja-free  # Free binary analysis platform
  wireshark-qt      # GUI network protocol analyzer for capturing and inspecting packets
  smbclient         # Command-line SMB/CIFS client for accessing Windows/Samba shares
  openssh           # SSH client and server for secure remote login and file transfer
  freerdp           # Free implementation of the Remote Desktop Protocol (RDP)
  impacket          # Python collection of tools for working with network protocols (SMB, RDP, etc.)
  dirbuster         # Directory and file brute-forcing tool for web servers
  dnslookup-bin     # DNS query utility (nslookup-like functionality)
  remmina           # Remote desktop client supporting RDP, VNC, SSH, SPICE
  hashcat           # GPU-accelerated password cracker
  john              # CPU-based password cracker with many format plugins
  gobuster          # URI/DNS/vhost/S3 brute-force enumerator
  binwalk           # Firmware analysis and extraction tool
  pngcheck          # Verifies PNG image integrity and displays info about PNG files
  zsteg             # LSB steganography detection for PNG/BMP
  evil-winrm-py     # WinRM shell for pentesting Windows hosts
  seclists          # Collection of security-related wordlists
  perl-image-exiftool
  bind-tools
)

paru -S "${packages[@]}"
