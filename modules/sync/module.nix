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

            mkTextHandler = {
                description,
                disableRules ? (_: []),
            }: {
                optionType = types.nullOr types.str;
                default = null;
                inherit description disableRules;
                isManaged = val: val != null;
            };

            mkJsonPatchHandler = {
                description,
                disableRules ? (_: []),
            }: {
                optionType = types.attrsOf (types.either types.str (types.attrsOf types.str));
                default = {};
                inherit description disableRules;
                isManaged = val: val != {};
            };

            writeHandlers = {
                ".nvmrc" = mkTextHandler {
                    description = "Value to write to .nvmrc, or null to skip";
                    disableRules = val:
                        optional (val != null) {
                            description = "syncix: manages .nvmrc";
                            matchManagers = ["nvm"];
                            enabled = false;
                        };
                };
                "package.json" = mkJsonPatchHandler {
                    description = "Fields to patch into package.json, keyed by section or top-level key";
                    disableRules = val: let
                        nestedSections = lib.filterAttrs (_: lib.isAttrs) val;
                        topLevelStrings = lib.filterAttrs (_: lib.isString) val;
                        depSections = lib.filterAttrs (k: _: k != "engines") nestedSections;
                        allPkgs = lib.concatMap lib.attrNames (lib.attrValues depSections);
                        depTypeFields = lib.attrNames topLevelStrings;
                    in
                        optional (depTypeFields != []) {
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
                };
                "renovate.json" = {
                    optionType = types.coercedTo types.bool (enable: {inherit enable;}) renovateJsonType;
                    default = {};
                    description = "Patch syncix-controlled packageRules into renovate.json. Set to true to enable with defaults";
                    isManaged = val: val.enable;
                    disableRules = _: [];
                };
            };

            mkManagedFiles = write: generate:
                lib.concatLists (lib.mapAttrsToList (
                    file: h:
                        optional (h.isManaged write.${file}) file
                )
                writeHandlers)
                ++ lib.attrNames generate;

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
                disableRules = lib.concatLists (lib.mapAttrsToList (
                    file: h:
                        h.disableRules write.${file}
                )
                writeHandlers);
            in
                lib.optionals write."renovate.json".enable (
                    mkPostUpgradeRule managedFiles
                    ++ disableRules
                    ++ write."renovate.json".packageRules
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
                        options = lib.mapAttrs (
                            _: h:
                                mkOption {
                                    type = h.optionType;
                                    default = h.default;
                                    description = h.description;
                                }
                        )
                        writeHandlers;
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
                                ".nvmrc" = w.".nvmrc";
                                "package.json" = w."package.json";
                                "renovate.json".packageRules = mkRenovatePackageRules w config.sync.generate;
                            };
                        }}' "$@"
                    '';
                };
            };
        };
    };
}
