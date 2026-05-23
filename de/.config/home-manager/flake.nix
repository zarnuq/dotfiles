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
          # Ruby 3.4 dropped several libs from stdlib (getoptlong, resolv-replace,
          # csv, base64, ...). Two pentest tools on nixpkgs-unstable break on this:
          #   - whatweb:    execs ruby_3_4 but its gems build under the default ruby
          #                 and the wrapper hardcodes a gems/3.3.0 GEM_PATH.
          #   - evil-winrm: bundlerEnv builds under default ruby 3.4, dies on `csv`.
          # Each Nix package carries its own ruby, so pinning each to Ruby 3.3
          # (which still ships those stdlib libs) fixes them independently.
          (final: prev: {
            whatweb = prev.whatweb.override {
              ruby_3_4 = final.ruby_3_3;
              bundlerEnv = args: final.bundlerEnv (args // { ruby = final.ruby_3_3; });
            };
            evil-winrm = prev.evil-winrm.override {
              bundlerEnv = args: final.bundlerEnv (args // { ruby = final.ruby_3_3; });
            };
          })
        ];
      };
      modules = [ ./home.nix ];
    };
  };
}
