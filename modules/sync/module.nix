{lib, ...}: {
    flake.flakeModules.sync = {
        perSystem = {
            config,
            pkgs,
            ...
        }: let
            inherit (lib) mkEnableOption mkIf mkOption optional types;

            renovateJsonType = types.submodule {
                options = {
                    enable = mkEnableOption "renovate.json sync";
                    packageRules = mkOption {
                        type = types.listOf (types.attrsOf types.anything);
                        default = [];
                        description = "Additional packageRules to inject into renovate.json on top of auto-generated ones";
                    };
                };
            };

            mkDisableRules = write: let
                nestedSections = lib.filterAttrs (_: lib.isAttrs) write.packageJson;
                topLevelStrings = lib.filterAttrs (_: lib.isString) write.packageJson;
                depSections = lib.filterAttrs (k: _: k != "engines") nestedSections;
                allPkgs = lib.concatMap lib.attrNames (lib.attrValues depSections);
                depTypeFields = lib.attrNames topLevelStrings;
            in
                optional (write.nvmrc != null) {
                    description = "syncix: manages .nvmrc";
                    matchManagers = ["nvm"];
                    enabled = false;
                }
                ++ optional (depTypeFields != []) {
                    description = "syncix: manages top-level fields in package.json";
                    matchDepTypes = depTypeFields;
                    enabled = false;
                }
                ++ optional (nestedSections ? engines) {
                    description = "syncix: manages engines field in package.json";
                    matchDepTypes = ["engines"];
                    enabled = false;
                }
                ++ optional (allPkgs != []) {
                    description = "syncix: manages packages in package.json";
                    matchPackageNames = allPkgs;
                    enabled = false;
                };

            mkManagedFiles = write: generate:
                optional (write.nvmrc != null) ".nvmrc"
                ++ optional (write.packageJson != {}) "package.json"
                ++ lib.attrNames generate
                ++ optional write.renovateJson.enable "renovate.json";

            mkPostUpgradeRule = managedFiles:
                optional (managedFiles != []) {
                    description = "syncix: run sync and commit managed files after nix updates";
                    matchUpdateTypes = ["lockFileMaintenance"];
                    postUpgradeTasks = {
                        commands = ["nix run .#sync"];
                        fileFilters = ["flake.lock"] ++ managedFiles;
                        executionMode = "branch";
                    };
                };

            mkRenovatePackageRules = write: generate: let
                managedFiles = mkManagedFiles write generate;
            in
                lib.optionals write.renovateJson.enable (
                    mkPostUpgradeRule managedFiles
                    ++ mkDisableRules write
                    ++ write.renovateJson.packageRules
                );
        in {
            options.sync = {
                enable = mkEnableOption "nix sync";

                versions = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                    description = "Named versions (single source of truth) referenced by write and generate options";
                };

                write = mkOption {
                    type = types.submodule {
                        options = {
                            nvmrc = mkOption {
                                type = types.nullOr types.str;
                                default = null;
                                description = "Value to write to .nvmrc, or null to skip";
                            };
                            packageJson = mkOption {
                                type = types.attrsOf (types.either types.str (types.attrsOf types.str));
                                default = {};
                                description = "Fields to patch into package.json, keyed by section or top-level key";
                            };
                            renovateJson = mkOption {
                                type = types.coercedTo types.bool (enable: {inherit enable;}) renovateJsonType;
                                default = {};
                                description = "Patch syncix-controlled packageRules into renovate.json. Set to true to enable with defaults";
                            };
                        };
                    };
                    default = {};
                    description = "Files syncix directly patches with computed values";
                };

                generate = mkOption {
                    type = types.attrsOf (types.listOf types.str);
                    default = {};
                    description = "Commands that generate files, keyed by the file they produce";
                };

                format = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Formatter run after writing any managed file — filename appended as last argument (e.g. [\"pnpm\" \"exec\" \"prettier\" \"--write\" \"--ignore-unknown\"])";
                };
            };

            config = mkIf config.sync.enable {
                packages.sync = pkgs.writeShellApplication {
                    name = "sync";
                    runtimeInputs = [pkgs.nodejs];
                    text = let
                        w = config.sync.write;
                    in ''
                        node ${./.}/script.mjs '${builtins.toJSON {
                            inherit (config.sync) versions format;
                            generate = config.sync.generate;
                            write = {
                                inherit (w) nvmrc packageJson;
                                renovateJson.packageRules = mkRenovatePackageRules w config.sync.generate;
                            };
                        }}' "$@"
                    '';
                };
            };
        };
    };
}
