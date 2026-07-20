{ config, pkgs, lib, ... }:

{
  imports = [ ./default.nix ];

  home.username = "miles";
  home.homeDirectory = "/home/miles";
  home.stateVersion = "26.05";
  home.sessionVariables = {
    XDG_DATA_DIRS = "/usr/local/share:/usr/share:$HOME/.nix-profile/share";
  };

  programs.home-manager.enable = true;
  home.packages = with pkgs; [

    pyright

    chromium
    claude-code
    kiro-cli
    unhide
    antigravity
    termius
    nwg-look
    wl-gammarelay-rs
    firefox-bin

    (texlive.combine {
      inherit (texlive) scheme-medium latexmk;
    })

    # PYTHON ECOSYSTEM
    (python3.withPackages (ps: with ps; [
      impacket
      virtualenv
      pip
      icalendar
      recurring-ical-events
      x-wr-timezone
    ]))
    # pipx 1.8.0's test suite fails against newer `packaging` (it now puts
    # spaces around `@` in PEP 508 specs), breaking the checkPhase. Skip the
    # tests until the nixpkgs snapshot ships a fixed pipx.
    (pipx.overridePythonAttrs (_: { doCheck = false; doInstallCheck = false; }))

  ];
}
