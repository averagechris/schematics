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
      pkgs = import nixpkgs {
        inherit system;
      };
      inherit (pkgs) lib;
      src = lib.cleanSource ./.;
      mkSchematics = pyPackageSet:
        with pyPackageSet;
          buildPythonPackage {
            inherit src;
            checkInputs = mkTestDependencies pyPackageSet;
            format = "flit";
            pname = "schematics-py310-plus";
            version = "0.0.1";
          };
      mkTestDependencies = pyPackageSet:
        with pyPackageSet; [
          bson
          pymongo
          pytest
          pytestCheckHook
          python-dateutil
        ];
      mkDevShell = pyPackageSet: schematicsDrv:
        with pyPackageSet;
          pkgs.mkShell {
            inherit (schematicsDrv) propagatedNativeBuildInputs;

            shellHook =
              self.checks.${system}.pre-commit.shellHook
              + ''
                export PYTHONBREAKPOINT=ipdb.set_trace
                export PYTHONDONTWRITEBYTECODE=1
              '';
            inputsFrom = [schematicsDrv];
            buildInputs =
              (mkTestDependencies pyPackageSet)
              ++ [
                pkgs.cachix
                pkgs.nodePackages.pyright
                schematicsDrv

                # python dev deps (but not CI test deps)
                black
                flake8
                flit
                ipdb
                ipython
                isort
                python
              ];
          };

      schematics310 = mkSchematics pkgs.python310Packages;
      schematics39 = mkSchematics pkgs.python39Packages;
      schematics311 = mkSchematics pkgs.python311Packages;

      get_schematics_version = pkgs.writeShellApplication {
        name = "schematics_version";
        runtimeInputs = with pkgs; [coreutils gnused ripgrep];
        text = ''
          rg -F "__version__ = " schematics/__init__.py \
          | cut -d = -f 2 \
          | sed -e 's/__version__ = //' \
          | sed 's/"//g' \
          | sed 's/\s//g' \
        '';
      };
    in {
      checks = {
        # schematics311 -- nix python 3.11 failing to compile rn
        inherit schematics39 schematics310 get_schematics_version;

        pre-commit = pre-commit-hooks.lib.${system}.run {
          inherit src;
          hooks = rec {
            alejandra.enable = true;
            black.enable = true;
            isort.enable = true;
            flake8 = {
              enable = false;
              entry = "${pkgs.writeShellApplication {
                name = "check-flake8";
                runtimeInputs = with pkgs.python310Packages; [flake8];
                text = "flake8 schematics";
              }}/bin/check-flake8";
              name = "flake8";
              pass_filenames = false;
              types = ["file" "python"];
            };
            markdown-linter = {
              enable = true;
              entry = with pkgs; "${mdl}/bin/mdl -g";
              language = "system";
              name = "markdown-linter";
              pass_filenames = true;
              types = ["markdown"];
            };
            pyright = {
              # FIXME
              enable = false;
              entry = "${pkgs.writeShellApplication {
                name = "check-pyright";
                runtimeInputs = with pkgs.python310Packages; [
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

      packages = {
        inherit schematics39 schematics310 schematics311;
        default = schematics310;
      };
      apps = rec {
        pytest = flake-utils.lib.mkApp {
          drv = pkgs.python310Packages.pytest;
        };
        default = pytest;
        flit = flake-utils.lib.mkApp {
          drv = pkgs.python310Packages.flit;
        };
        schematics_version = flake-utils.lib.mkApp {
          drv = get_schematics_version;
        };
      };

      devShells = {
        schematics39 = mkDevShell pkgs.python39Packages schematics39;
        schematics310 = mkDevShell pkgs.python310Packages schematics310;
        schematics311 = mkDevShell pkgs.python310Packages schematics311;
      };
      devShells.default = self.outputs.devShells.${system}.schematics310;

      formatter = pkgs.alejandra;
    });
}
