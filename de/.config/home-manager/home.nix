{ config, pkgs, lib,... }:

{
  imports = [ ./cyber.nix ];
  home.username = "miles";
  home.homeDirectory = "/home/miles";
  home.stateVersion = "26.05";
  home.sessionVariables = {
    XDG_DATA_DIRS = "/usr/local/share:/usr/share:$HOME/.nix-profile/share";
  };

  programs.home-manager.enable = true;
  home.packages = with pkgs; [

    antigravity
    termius
    legcord
    steam
    nwg-look

    # PYTHON ECOSYSTEM
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

  ];
}
