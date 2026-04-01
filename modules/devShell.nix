{
    perSystem = {
        config,
        pkgs,
        ...
    }: {
        devShells.default = pkgs.mkShell {
            packages = with pkgs; [
                nodejs
                pnpm
            ];
            shellHook = config.pre-commit.installationScript;
        };
    };
}
