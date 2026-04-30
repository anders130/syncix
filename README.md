# syncix

Sync versions from Nix into project files.

## Installation

```nix
# flake.nix
inputs.syncix.url = "github:anders130/syncix";
inputs.syncix.inputs.nixpkgs.follows = "nixpkgs";
inputs.syncix.inputs.flake-parts.follows = "flake-parts";
```

```nix
# your flake-parts module
{inputs, ...}: {
  imports = [inputs.syncix.flakeModules.default];
}
```

## Usage

```nix
perSystem = {config, pkgs, lib, ...}: {
  sync = {
    enable = true;

    versions = {
      node = pkgs.nodejs.version;
      pnpm = pkgs.pnpm.version;
    };

    write = {
      ".nvmrc" = config.sync.versions.node;
      "package.json" = {
        engines.node = config.sync.versions.node;
        packageManager = "pnpm@${config.sync.versions.pnpm}";
        devDependencies."@types/node" =
          "^${lib.versions.major config.sync.versions.node}";
      };
      "renovate.json" = true;
      "lefthook.yml" = true;
    };

    generate."pnpm-lock.yaml" = ["pnpm" "install" "--lockfile-only" "--silent"];
    format = ["pnpm" "exec" "prettier" "--write" "--ignore-unknown"];
  };
};
```

```sh
nix run .#sync
nix run .#sync -- --check
```

## Extensions

An extension is a folder with a `default.nix` and an `index.mjs`.

**`default.nix`**

```nix
{
  perSystem = {config, lib, ...}: {
    options.sync.write."myfile.json" = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    config = lib.mkIf config.sync.enable {
      sync._ext = {
        writeConfig."myfile.json" = config.sync.write."myfile.json";
        # Nix path copied into the sync runtime; can import from 'syncix'
        jsHandlers = [./index.mjs];
        managedFiles = lib.optional (config.sync.write."myfile.json" != null) "myfile.json";
      };
    };
  };
}
```

**`index.mjs`** (run `npm install --save-dev syncix` for editor support)

```js
import { text, jsonPatch, yamlPatch } from 'syncix'

export const writeHandlers = {
    // return null to skip, { name, changed } otherwise
    'myfile.json': (config) => {
        if (!config) return null
        // ...
        return { name: 'myfile.json', changed: true, apply, log, preview }
    },

    'myfile.yml': yamlPatch('myfile.yml'),
}
```

Import alongside `flakeModules.default`:

```nix
imports = [
  inputs.syncix.flakeModules.default
  ./nix/myext
];
```

`flakeModules.base` skips the renovate and lefthook extensions.

## Options

| Option                  | Description                                                                                                                                                              |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `versions`              | Named version values                                                                                                                                                     |
| `write.".nvmrc"`        | Value to write to `.nvmrc`                                                                                                                                               |
| `write."package.json"`  | Top-level strings set the field directly; nested attrsets merge into that section                                                                                        |
| `write."renovate.json"` | `true` or `{ packageRules = [...]; }`, auto-generates Renovate disable rules and a `postUpgradeTasks` rule                                                               |
| `write."lefthook.yml"`  | `true` or `{ extraGlobs = [...]; }`, patches lefthook.yml with a pre-commit `nix run .#sync -- --check` hook; glob auto-generated from managed files and `generate` keys |
| `generate`              | Commands that produce files, keyed by output filename; run after `write`                                                                                                 |
| `format`                | Formatter run after each write, filename appended as last argument                                                                                                       |
