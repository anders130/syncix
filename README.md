# syncix

Sync version values from Nix into project files.

## What it does

- Uses Nix as the single source of truth for versions.
- Writes a version to `.nvmrc` when enabled.
- Writes fields into `package.json` when configured.

## Usage

1. Add this flake as an input and import the module.
2. Configure `sync` options in your flake.
3. Run the sync package.

Example config:

```nix
{
  sync = {
    enable = true;
    versions.node = pkgs.nodejs.version;
    nvmrc = config.sync.versions.node;
    packageJson = {
      engines.node = config.sync.versions.node;
      devDependencies."@types/node" =
        "^${lib.versions.major config.sync.versions.node}";
    };
    commands."pnpm-lock.yaml" = ["pnpm" "install" "--lockfile-only" "--silent"];
  };
}
```

The `commands` option allows providing a map of files to commands that should run after `package.json` is updated to ensure their consistency.

Run:

```sh
nix run .#sync
```
