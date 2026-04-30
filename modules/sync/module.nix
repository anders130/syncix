{config, ...}: {
    flake.flakeModules.default = {
        imports = [
            config.flake.flakeModules.base
            config.flake.flakeModules.renovate
            config.flake.flakeModules.lefthook
        ];
    };
}
