{ config, pkgs, lib,... }:

let
  catppuccin-mocha-mauve = pkgs.catppuccin-gtk.override {
    accents = [ "mauve" ];
    variant = "mocha";
  };
in
{
  imports = [ ./cyber.nix ];
  home.username = "miles";
  home.homeDirectory = "/home/miles";
  home.stateVersion = "26.05";
  home.sessionVariables = {
    XDG_DATA_DIRS = "/usr/local/share:/usr/share:$HOME/.nix-profile/share";
  };

  fonts.fontconfig.enable = true;

  gtk = {
    enable = true;
    theme = { package = catppuccin-mocha-mauve; name = "catppuccin-mocha-mauve-standard"; };
    font = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; size = 14; };
  };
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
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

    antigravity
    dejavu_fonts fontconfig
    libsForQt5.qtstyleplugin-kvantum
    qt6Packages.qtstyleplugin-kvantum

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
