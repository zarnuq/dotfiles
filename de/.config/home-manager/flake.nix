{
  description = "Home Manager configuration of miles";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl.url = "github:nix-community/nixGL";
    # Build nixGL against the same nixpkgs it pins. nixGL's nvidia builder passes
    # a `kernel` arg that current nixos-unstable's nvidia-x11/generic.nix no
    # longer accepts; `follows` keeps us on nixGL's compatible nixpkgs and in
    # lockstep with it across updates.
    nixgl-nixpkgs.follows = "nixgl/nixpkgs";
  };

  outputs = { nixpkgs, home-manager, nixgl, nixgl-nixpkgs, ... }: {
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
      extraSpecialArgs = { inherit nixgl nixgl-nixpkgs; };
      modules = [ ./home.nix ];
    };
  };
}
