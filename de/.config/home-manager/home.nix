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

    chromium
    claude-code
    tree-sitter # nvim-treesitter (main branch) needs the CLI to compile parsers
    kiro-cli
    termius
    nwg-look
    wl-gammarelay-rs
    firefox-bin
    signal-desktop
    tealdeer

    (texlive.combine {
      inherit (texlive) scheme-medium latexmk;
    })

    (python3.withPackages (ps: (with ps; [
      virtualenv
      pip
      icalendar
      recurring-ical-events
      x-wr-timezone
    ]) ++ config.my.cyberPythonLibs))
    # pipx 1.8.0's test suite fails against newer `packaging` (it now puts
    # spaces around `@` in PEP 508 specs), breaking the checkPhase. Skip the
    # tests until the nixpkgs snapshot ships a fixed pipx.
    (pipx.overridePythonAttrs (_: { doCheck = false; doInstallCheck = false; }))

  ];

  # proton-ge-bin's default output is a bare file, so it can't go in
  # home.packages (buildEnv can't merge a file). Steam is the system Portage
  # package; symlink the steamcompattool output into its compatibilitytools.d.
  home.file.".local/share/Steam/compatibilitytools.d/GE-Proton10-34".source =
    pkgs.proton-ge-bin.steamcompattool;
}
