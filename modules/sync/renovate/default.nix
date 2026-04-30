{
    flake.flakeModules.renovate = {
        perSystem = {
            config,
            lib,
            ...
        }: let
            inherit (lib) mkEnableOption mkIf mkOption optional types;

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

            mkPackageRules = write: managedFiles: disableRules:
                lib.optionals (write."renovate.json".enable or false) (
                    mkPostUpgradeRule managedFiles
                    ++ disableRules
                    ++ write."renovate.json".packageRules
                );
        in {
            options.sync.write."renovate.json" = mkOption {
                type = types.coercedTo types.bool (enable: {inherit enable;}) (types.submodule {
                    options = {
                        enable = mkEnableOption "renovate.json sync";
                        packageRules = mkOption {
                            type = types.listOf (types.attrsOf types.anything);
                            default = [];
                            description = "Additional packageRules to inject into renovate.json on top of auto-generated ones";
                        };
                    };
                });
                default = {};
                description = "Patch syncix-controlled packageRules into renovate.json. Set to true to enable with defaults";
            };

            config = mkIf config.sync.enable {
                sync._ext = {
                    writeConfig."renovate.json".packageRules =
                        mkPackageRules config.sync.write config.sync._ext.managedFiles config.sync._ext.renovateDisableRules;
                    jsHandlers = [./index.mjs];
                };
            };
        };
    };
}
