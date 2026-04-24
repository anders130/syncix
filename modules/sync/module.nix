{lib, ...}: {
    flake.flakeModules.sync = {
        perSystem = {
            config,
            pkgs,
            ...
        }: let
            inherit (lib) mkEnableOption mkIf mkOption optional types;
        in {
            options.sync = {
                enable = mkEnableOption "nix sync";
                versions = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                    description = "Named versions managed by syncix (single source of truth)";
                };
                nvmrc = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Version to sync to .nvmrc, or null to skip";
                };
                packageJson = mkOption {
                    type = types.attrsOf (types.either types.str (types.attrsOf types.str));
                    default = {};
                    description = "Fields to sync into package.json, keyed by section or top-level key";
                };
                renovateJson = mkOption {
                    type = types.submodule {
                        options = {
                            enable = mkEnableOption "renovate.json sync";
                            packageRules = mkOption {
                                type = types.listOf (types.attrsOf types.anything);
                                default = [];
                                description = "Additional packageRules to inject into renovate.json on top of auto-generated ones";
                            };
                        };
                    };
                    default = {};
                    description = "Manage syncix-controlled package rules in renovate.json";
                };
                format = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Formatter run after writing any managed file — filename appended as last argument";
                };
                commands = mkOption {
                    type = types.attrsOf (types.listOf types.str);
                    default = {};
                    description = "Commands to run after sync, keyed by the file they update";
                };
            };

            config = mkIf config.sync.enable (let
                nestedSections = lib.filterAttrs (_: lib.isAttrs) config.sync.packageJson;

                disableRules =
                    optional (config.sync.nvmrc != null) {
                        description = "syncix manages .nvmrc";
                        matchManagers = ["nvm"];
                        enabled = false;
                    }
                    ++ optional (nestedSections ? engines) {
                        description = "syncix manages engines field in package.json";
                        matchDepTypes = ["engines"];
                        enabled = false;
                    }
                    ++ lib.mapAttrsToList (pkg: _: {
                        description = "syncix manages ${pkg}";
                        matchPackageNames = [pkg];
                        enabled = false;
                    }) (nestedSections.devDependencies or {});

                managedFiles =
                    optional (config.sync.nvmrc != null) ".nvmrc"
                    ++ optional (config.sync.packageJson != {}) "package.json"
                    ++ lib.attrNames config.sync.commands
                    ++ optional config.sync.renovateJson.enable "renovate.json";

                postUpgradeRule =
                    optional (managedFiles != []) {
                        description = "syncix: run sync and commit managed files after nix updates";
                        matchUpdateTypes = ["lockFileMaintenance"];
                        postUpgradeTasks = {
                            commands = ["nix run .#sync"];
                            fileFilters = ["flake.lock"] ++ managedFiles;
                            executionMode = "branch";
                        };
                    };

                renovatePackageRules =
                    lib.optionals config.sync.renovateJson.enable (
                        postUpgradeRule ++ disableRules ++ config.sync.renovateJson.packageRules
                    );
            in {
                packages.sync = pkgs.writeShellApplication {
                    name = "sync";
                    runtimeInputs = [pkgs.nodejs];
                    text = ''
                        node ${./.}/script.mjs '${builtins.toJSON {
                            inherit (config.sync) versions nvmrc packageJson format commands;
                            renovateJson.packageRules = renovatePackageRules;
                        }}' "$@"
                    '';
                };
            });
        };
    };
}
