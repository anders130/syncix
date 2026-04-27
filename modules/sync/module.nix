let
    sync = {
        perSystem = {
            config,
            pkgs,
            lib,
            ...
        }: let
            inherit (lib) mkEnableOption mkIf mkOption types;
            handlers = import ./_handlers.nix {inherit lib;};
            renovate = import ./_renovate.nix {inherit lib;};
            writeHandlers = handlers.writeHandlers // {"renovate.json" = renovate.handler;};
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
                                inherit (w) ".nvmrc" "package.json";
                                "renovate.json".packageRules = renovate.mkRenovatePackageRules writeHandlers w config.sync.generate;
                            };
                        }}' "$@"
                    '';
                };
            };
        };
    };
in {
    flake.flakeModules = {
        inherit sync;
        default = {};
    };
}
