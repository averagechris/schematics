{
  description = "TODO FIXME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    pre-commit-hooks,
    ...
  }:
    flake-utils.lib.eachSystem [flake-utils.lib.system.x86_64-linux] (system: let
      # flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      inherit (pkgs) lib;
      src = lib.cleanSource ./.;
      python310Packages = pkgs.python310Packages.override {
        # overrides = final: prev: {
        #   typer = prev.typer.overrideAttrs (_: {meta.broken = false;});
        # };
      };

      schematics = with python310Packages;
        buildPythonPackage {
          inherit src;
          propagatedBuildInputs = [];
          propagatedNativeBuildInputs = [];
          checkInputs = [pytestCheckHook];
          format = "flit";
          pname = "schematics-py310-plus";
          version = "0.0.1";
        };
    in {
      checks = {
        inherit schematics;

        pre-commit = pre-commit-hooks.lib.${system}.run {
          inherit src;
          hooks = rec {
            alejandra.enable = true;
            black.enable = true;
            isort.enable = true;
            markdown-linter = {
              enable = true;
              entry = with pkgs; "${mdl}/bin/mdl -g";
              language = "system";
              name = "markdown-linter";
              pass_filenames = true;
              types = ["markdown"];
            };
            pyright = {
              # cant find imports 😢
              enable = false;
              entry = "${pkgs.writeShellApplication {
                name = "check-pyright";
                runtimeInputs = with python310Packages; [
                  pkgs.nodePackages.pyright
                  pytest
                  python
                ];
                text = "pyright";
              }}/bin/check-pyright";
              name = "pyright";
              pass_filenames = false;
              types = ["file" "python"];
            };
            statix.enable = true;
          };
        };
      };

      packages.default = schematics;
      apps.default = flake-utils.lib.mkApp {
        drv = python310Packages.pytest;
      };

      devShells.default = pkgs.mkShell {
        inherit (self.packages.${system}.default) propagatedNativeBuildInputs;

        shellHook =
          self.checks.${system}.pre-commit.shellHook
          + ''
            export PYTHONBREAKPOINT=ipdb.set_trace
            export PYTHONDONTWRITEBYTECODE=1
          '';
        inputsFrom = [self.packages.${system}.default];
        buildInputs = with python310Packages; [
          pkgs.cachix
          pkgs.nodePackages.pyright
          self.packages.${system}.default

          # python dev deps (but not CI test deps)
          black
          coverage
          flake8
          pymongo
          python-dateutil
          bson
          flit
          ipdb
          ipython
          isort
          pytest
          python
        ];
      };

      formatter = pkgs.alejandra;
    });
}
