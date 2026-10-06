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
            # nixpkgs lags on Termius (9.43.1); shared vault hosts written by v10
            # clients show up blank. Pull the 10.x snap directly — drop this once
            # nixpkgs catches up. New revision/hash: see comment in nixpkgs' package.nix.
            termius = prev.termius.overrideAttrs (old: {
              version = "10.1.3";
              src = prev.fetchurl {
                url = "https://api.snapcraft.io/api/v1/snaps/download/WkTBXwoX81rBe3s3OTt3EiiLKBx2QhuS_271.snap";
                sha512 = "a6e0fa4cdd03a0eaaa19eb9b0df8bef7ec828661477bd31793d9d8aeda5993a8a0f7681ac2abd5fad4015117424b4a24d7a05b8e1b39fd93c9b44d993152c4e5";
              };
              # v10 stopped bundling NSS.
              buildInputs = old.buildInputs ++ [ prev.nss prev.nspr ];
              # v10 moved the electron binary under app/.
              postFixup = ''
                makeWrapper $out/opt/termius/app/termius-app $out/bin/termius-app \
                  "''${gappsWrapperArgs[@]}"
              '';
            });

            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (pyfinal: pyprev: {
                # anyio 4.14.2's TLS tests fail on python3.12 in nixpkgs a7868a7
                # ("server_hostname can only be specified in client mode"), which
                # takes httpx -> certipy-ad/proxy-py -> netexec down with it.
                # Library itself is fine — skip the check phase. 3.12 only: 3.14 anyio
                # passes and is cached; touching it rebuilds every dependent from source.
                anyio =
                  if pyprev.python.pythonVersion == "3.12"
                  then pyprev.anyio.overridePythonAttrs (old: { doCheck = false; })
                  else pyprev.anyio;
              })
            ];
          })
        ];
      };
      modules = [ ./home.nix ];
    };
  };
}
