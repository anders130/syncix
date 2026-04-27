{lib}: let
    inherit (lib) optional types;

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
    };
in {
    inherit mkTextHandler mkJsonPatchHandler writeHandlers;
}
