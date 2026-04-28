{lib}: let
    inherit (lib) concatLists concatStringsSep elem mapAttrsToList mkEnableOption mkOption optional types;

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

    handler = {
        optionType = types.coercedTo types.bool (enable: {inherit enable;}) lefthookType;
        default = {};
        description = "Patch lefthook.yml with a pre-commit nix-sync command. Set to true to enable with defaults";
        isManaged = val: val.enable or false;
        disableRules = _: [];
    };

    mkGlob = writeHandlers: write: generate: let
        managed = concatLists (mapAttrsToList (
            file: h:
                optional (!elem file ["renovate.json" "lefthook.yml"] && h.isManaged write.${file}) file
        )
        writeHandlers);
        parts = managed ++ lib.attrNames generate ++ write."lefthook.yml".extraGlobs or [];
    in
        "{" + concatStringsSep "," parts + "}";

    mkConfig = writeHandlers: write: generate:
        if !(write."lefthook.yml".enable or false)
        then {}
        else {
            "pre-commit" = {
                parallel = true;
                commands.nix-sync = {
                    name = "sync nix versions";
                    glob = mkGlob writeHandlers write generate;
                    run = "if command -v nix >/dev/null 2>&1; then nix run .#sync -- --check; fi";
                };
            };
        };
in {
    inherit handler mkConfig;
}
