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

      mkSchematics = pyPackageSet:
        with pyPackageSet;
          buildPythonPackage {
            inherit src;
            propagatedBuildInputs = [];
            propagatedNativeBuildInputs = [];
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

      testDependencies = mkTestDependencies pkgs.python310Packages;
      schematics = mkSchematics pkgs.python310Packages;
      schematics39 = mkSchematics pkgs.python39Packages;
      # TODO FIXME schematics311 seems fairly straightforward?
      #
      # >   File "/build/docutils-0.18.1/test/package_unittest.py", line 102, in loadTestModules
      # >     module = import_module(mod)
      # >              ^^^^^^^^^^^^^^^^^^
      # >   File "/build/docutils-0.18.1/test/package_unittest.py", line 133, in import_module
      # >     mod = __import__(name)
      # >           ^^^^^^^^^^^^^^^^
      # >   File "/build/docutils-0.18.1/test/test_parsers/test_rst/test_directives/test_tables.py", line 67, in <module>
      # >     null_bytes_exception = DocutilsTestSupport.exception_data(null_bytes)[0]
      # >                            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^
      # > TypeError: 'NoneType' object is not subscriptable
      # schematics311 = mkSchematics pkgs.python311Packages;
    in {
      checks = {
        inherit schematics schematics39;

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
                runtimeInputs = with python310Packages; [flake8];
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
        buildInputs = with pkgs.python310Packages;
          testDependencies
          ++ [
            pkgs.cachix
            pkgs.nodePackages.pyright
            self.packages.${system}.default

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

      formatter = pkgs.alejandra;
    });
}
