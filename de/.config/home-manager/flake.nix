{
  description = "Home Manager configuration of miles";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."miles" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            # pipx 1.8.0's test suite asserts the old PEP 508 "name@ url" form, but
            # the newer `packaging` in nixpkgs 26.11 normalizes it to "name @ url",
            # so 7 tests in test_package_specifier.py fail and the build aborts.
            # The shipped binary is unaffected — skip the check phase.
            pipx = prev.pipx.overridePythonAttrs (old: { doCheck = false; });

            # evil-winrm's Gemfile pulls in winrm-fs, which does `require "csv"`.
            # Ruby 3.4 (the current nixpkgs default) dropped csv from its default
            # gems, and it isn't in evil-winrm's gemset, so the tool dies at startup
            # with `cannot load such file -- csv`. Build its bundlerEnv against
            # Ruby 3.3, where csv is still a default gem.
            evil-winrm = prev.evil-winrm.override {
              bundlerEnv = args: prev.bundlerEnv (args // { ruby = final.ruby_3_3; });
            };
          })
        ];
      };
      modules = [ ./home.nix ];
    };
  };
}
