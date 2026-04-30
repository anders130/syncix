{
    flake.flakeModules.lefthook = {
        perSystem = {
            config,
            lib,
            ...
        }: let
            inherit (lib) concatStringsSep mkEnableOption mkIf mkOption types;

            lefthookType = types.submodule {
                options = {
                    enable = mkEnableOption "lefthook.yml nix-sync pre-commit command";
                    extraGlobs = mkOption {
                        type = types.listOf types.str;
                        default = [];
                        description = "Additional glob patterns that trigger the nix-sync pre-commit check";
                    };
                };
            };

            mkGlob = managedFiles: extraGlobs:
                "{" + concatStringsSep "," (managedFiles ++ extraGlobs) + "}";

            mkConfig = write: managedFiles:
                if !(write."lefthook.yml".enable or false)
                then {}
                else {
                    "pre-commit" = {
                        parallel = true;
                        commands.nix-sync = {
                            name = "sync nix versions";
                            glob = mkGlob managedFiles (write."lefthook.yml".extraGlobs or []);
                            run = "if command -v nix >/dev/null 2>&1; then nix run .#sync -- --check; fi";
                        };
                    };
                };
        in {
            options.sync.write."lefthook.yml" = mkOption {
                type = types.coercedTo types.bool (enable: {inherit enable;}) lefthookType;
                default = {};
                description = "Patch lefthook.yml with a pre-commit nix-sync command. Set to true to enable with defaults";
            };

            config = mkIf config.sync.enable {
                sync._ext = {
                    writeConfig."lefthook.yml" = mkConfig config.sync.write config.sync._ext.managedFiles;
                    jsHandlers = [./index.mjs];
                };
            };
        };
    };
}
