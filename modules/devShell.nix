{
    perSystem = {pkgs, ...}: {
        devShells.default = pkgs.mkShell {
            packages = with pkgs; [
                nodejs
                pnpm
            ];
        };
    };
}
