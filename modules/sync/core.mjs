import fs from 'fs'
import { spawnSync } from 'child_process'
import { logUpdate, change } from './ui.mjs'

export const nvmrc = (val) => {
    if (val == null) return null

    const cur = fs.existsSync('.nvmrc')
        ? fs.readFileSync('.nvmrc', 'utf8').trim()
        : ''

    if (cur === val) return { name: '.nvmrc', changed: false, log: () => {} }

    return {
        name: '.nvmrc',
        changed: true,
        apply: () => fs.writeFileSync('.nvmrc', `${val}\n`),
        log: () => logUpdate('.nvmrc', [change('.nvmrc', val)]),
    }
}

export const packageJson = (config) => {
    if (
        !config ||
        !Object.keys(config).length ||
        !fs.existsSync('package.json')
    )
        return null

    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'))

    const diffs = Object.entries(config).flatMap(([section, fields]) =>
        Object.entries(fields)
            .filter(([key, val]) => (pkg[section] ?? {})[key] !== val)
            .map(([key, val]) => ({ section, key, val })),
    )

    if (!diffs.length)
        return { name: 'package.json', changed: false, log: () => {} }

    const preview = () => {
        const next = JSON.parse(JSON.stringify(pkg))
        diffs.forEach(({ section, key, val }) => {
            next[section] ??= {}
            next[section][key] = val
        })
        return JSON.stringify(next, null, 2) + '\n'
    }

    return {
        name: 'package.json',
        changed: true,
        preview,
        apply: () => fs.writeFileSync('package.json', preview()),
        log: () =>
            logUpdate(
                'package.json',
                diffs.map(({ key, val }) => change(key, val)),
            ),
    }
}

export const command = (file, cmd, { pkgChanged, isCheck }) => {
    if (!pkgChanged && !isCheck)
        return { name: file, changed: false, log: () => {} }

    if (isCheck) {
        const { status } = spawnSync(cmd[0], cmd.slice(1), {
            stdio: 'ignore',
        })

        return {
            name: file,
            changed: status !== 0,
            log: () => logUpdate(file),
        }
    }

    const before = fs.existsSync(file) ? fs.readFileSync(file) : null

    const { status } = spawnSync(cmd[0], cmd.slice(1), {
        stdio: 'pipe',
    })
    if (status !== 0) process.exit(status ?? 1)

    const after = fs.existsSync(file) ? fs.readFileSync(file) : null

    const changed =
        before === null
            ? after !== null
            : after === null
              ? true
              : !before.equals(after)

    return {
        name: file,
        changed,
        log: () => logUpdate(file),
    }
}
