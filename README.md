# syncix

Sync versions from Nix into project files.

## Installation

Add syncix as an input and wire up the shared inputs:

```nix
inputs = {
  syncix = {
    url = "github:anders130/syncix";
    inputs = {
      flake-parts.follows = "flake-parts";
      import-tree.follows = "import-tree";
      nixpkgs.follows = "nixpkgs";
    };
  };
};
```

Then import the module in your sync config file:

```nix
{inputs, ...}: {
  imports = [inputs.syncix.flakeModules.sync];
  perSystem = {config, ...}: {
    sync = { ... };
  };
}
```

## Usage

```nix
{
  sync = {
    enable = true;

    versions = {
      node = pkgs.nodejs.version;
      pnpm = pkgs.pnpm.version;
    };

    write = {
      nvmrc = config.sync.versions.node;
      packageJson = {
        engines.node = config.sync.versions.node;
        packageManager = "pnpm@${config.sync.versions.pnpm}";
        devDependencies."@types/node" =
          "^${lib.versions.major config.sync.versions.node}";
      };
      renovateJson = true;
    };

    generate."pnpm-lock.yaml" = ["pnpm" "install" "--lockfile-only" "--silent"];
    format = ["pnpm" "exec" "prettier" "--write" "--ignore-unknown"];
  };
}
```

```sh
nix run .#sync
nix run .#sync -- --check
```

## Options

| Option               | Description                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------- |
| `versions`           | Named version values                                                                                        |
| `write.nvmrc`        | Value to write to `.nvmrc`                                                                                  |
| `write.packageJson`  | Top-level strings set the field directly; nested attrsets merge into that section                           |
| `write.renovateJson` | `true` or `{ packageRules = [...]; }` — auto-generates Renovate disable rules and a `postUpgradeTasks` rule |
| `generate`           | Commands that produce files, keyed by output filename; run after `write`                                    |
| `format`             | Formatter run after each write; filename appended as last argument                                          |
