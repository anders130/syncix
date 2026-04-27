{lib}: let
    inherit (lib) mkEnableOption mkOption optional types;

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

    handler = {
        optionType = types.coercedTo types.bool (enable: {inherit enable;}) renovateJsonType;
        default = {};
        description = "Patch syncix-controlled packageRules into renovate.json. Set to true to enable with defaults";
        isManaged = val: val.enable;
        disableRules = _: [];
    };

    mkManagedFiles = writeHandlers: write: generate:
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

    mkRenovatePackageRules = writeHandlers: write: generate: let
        managedFiles = mkManagedFiles writeHandlers write generate;
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
    inherit handler mkRenovatePackageRules;
}
