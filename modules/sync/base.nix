{
    flake.flakeModules.base = {
        perSystem = {
            config,
            pkgs,
            lib,
            ...
        }: let
            inherit (lib) concatMap filterAttrs isAttrs isString mkEnableOption mkIf mkOption optional types;

            w = config.sync.write;

            nvmrcDisableRules = val:
                optional (val != null) {
                    description = "syncix: manages .nvmrc";
                    matchManagers = ["nvm"];
                    enabled = false;
                };

            packageJsonDisableRules = val: let
                nestedSections = filterAttrs (_: isAttrs) val;
                topLevelStrings = filterAttrs (_: isString) val;
                depSections = filterAttrs (k: _: k != "engines") nestedSections;
                allPkgs = concatMap lib.attrNames (lib.attrValues depSections);
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
        in {
            options.sync = {
                enable = mkEnableOption "nix sync";

                versions = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                    description = "Named versions (single source of truth) referenced by write and generate options";
                };

                write.".nvmrc" = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Value to write to .nvmrc, or null to skip";
                };

                write."package.json" = mkOption {
                    type = types.attrsOf (types.either types.str (types.attrsOf types.str));
                    default = {};
                    description = "Fields to patch into package.json, keyed by section or top-level key";
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

                _ext = {
                    writeConfig = mkOption {
                        type = types.attrsOf types.anything;
                        internal = true;
                        default = {};
                        description = "Merged write config passed to the sync script; extensions contribute here";
                    };
                    managedFiles = mkOption {
                        type = types.listOf types.str;
                        internal = true;
                        default = [];
                        description = "Files actively managed by sync; used by renovate postUpgradeTasks and lefthook glob";
                    };
                    renovateDisableRules = mkOption {
                        type = types.listOf types.anything;
                        internal = true;
                        default = [];
                        description = "Renovate packageRules disabling management of files handled by sync";
                    };
                    jsHandlers = mkOption {
                        type = types.listOf types.path;
                        internal = true;
                        default = [];
                        description = "Paths to extension JS modules; each file is copied into the sync runtime and may import from 'syncix'";
                    };
                };
            };

            config = mkIf config.sync.enable {
                sync._ext = {
                    writeConfig = {inherit (w) ".nvmrc" "package.json";};
                    managedFiles =
                        optional (w.".nvmrc" != null) ".nvmrc"
                        ++ optional (w."package.json" != {}) "package.json"
                        ++ lib.attrNames config.sync.generate;
                    renovateDisableRules =
                        nvmrcDisableRules w.".nvmrc"
                        ++ packageJsonDisableRules w."package.json";
                };

                packages.sync = let
                    src = ./.;
                    handlers = config.sync._ext.jsHandlers;
                    handlersJs = pkgs.writeText "handlers.mjs" (
                        "import { writeHandlers as base } from '${src}/write.mjs';\n"
                        + lib.concatStrings (lib.imap0 (
                            i: _: "import { writeHandlers as h${toString i} } from './ext/h${toString i}.mjs';\n"
                        )
                        handlers)
                        + "export const writeHandlers = { ...base"
                        + lib.concatStrings (lib.imap0 (i: _: ", ...h${toString i}") handlers)
                        + " };\n"
                    );
                    syncixShimPkg = pkgs.writeText "syncix-pkg.json" ''{"type":"module","exports":{".":{"import":"./index.mjs"}}}'';
                    syncixShimMjs = pkgs.writeText "syncix-shim.mjs" "export * from '../../index.mjs'\n";
                    syncDir = pkgs.runCommand "sync" {} (''
                        mkdir $out
                        cp -r --no-preserve=mode ${src}/. $out/
                        mkdir -p $out/ext $out/node_modules/syncix
                        cp ${handlersJs} $out/handlers.mjs
                        cp ${syncixShimPkg} $out/node_modules/syncix/package.json
                        cp ${syncixShimMjs} $out/node_modules/syncix/index.mjs
                    ''
                    + lib.concatStrings (lib.imap0 (i: path: ''
                        cp ${path} $out/ext/h${toString i}.mjs
                    '')
                    handlers));
                in
                    pkgs.writeShellApplication {
                        name = "sync";
                        runtimeInputs = [pkgs.nodejs];
                        text = ''
                            node ${syncDir}/script.mjs '${builtins.toJSON {
                                inherit (config.sync) versions format generate;
                                write = config.sync._ext.writeConfig;
                            }}' "$@"
                        '';
                    };
            };
        };
    };
}
