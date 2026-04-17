{lib, ...}: {
    flake.flakeModules.sync = {
        perSystem = {
            config,
            pkgs,
            ...
        }: let
            inherit (lib) mkEnableOption mkIf mkOption types;
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
                    type = types.attrsOf (types.attrsOf types.str);
                    default = {};
                    description = "Fields to sync into package.json, keyed by section";
                };
                commands = mkOption {
                    type = types.attrsOf (types.listOf types.str);
                    default = {};
                    description = "Commands to run after sync, keyed by the file they update";
                };
            };

            config = mkIf config.sync.enable {
                packages.sync = pkgs.writeShellApplication {
                    name = "sync";
                    runtimeInputs = [pkgs.nodejs];
                    text = ''
                        node ${./.}/script.mjs '${builtins.toJSON {
                            inherit (config.sync) versions nvmrc packageJson commands;
                        }}' "$@"
                    '';
                };
            };
        };
    };
}
