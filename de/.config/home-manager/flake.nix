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
          })
        ];
      };
      modules = [ ./home.nix ];
    };
  };
}
