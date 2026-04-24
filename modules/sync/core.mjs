import fs from 'fs'
import { spawnSync } from 'child_process'
import { logUpdate, change } from './ui.mjs'

export const nvmrc = (val) => {
    if (val == null) return null

    const cur = fs.existsSync('.nvmrc')
        ? fs.readFileSync('.nvmrc', 'utf8').trim()
        : ''

    if (cur === val) return { name: '.nvmrc', changed: false }

    return {
        name: '.nvmrc',
        changed: true,
        apply: () => fs.writeFileSync('.nvmrc', `${val}\n`),
        log: () => logUpdate('.nvmrc', [change('node', val)]),
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

    const diffs = Object.entries(config).flatMap(([section, fields]) => {
        if (typeof fields === 'string') {
            return pkg[section] !== fields
                ? [{ section, key: null, val: fields }]
                : []
        }
        return Object.entries(fields)
            .filter(([key, val]) => (pkg[section] ?? {})[key] !== val)
            .map(([key, val]) => ({ section, key, val }))
    })

    if (!diffs.length) return { name: 'package.json', changed: false }

    const preview = () => {
        const next = JSON.parse(JSON.stringify(pkg))
        diffs.forEach(({ section, key, val }) => {
            if (key === null) {
                next[section] = val
            } else {
                next[section] ??= {}
                next[section][key] = val
            }
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
                diffs.map(({ section, key, val }) =>
                    change(key ?? section, val),
                ),
            ),
    }
}

export const renovateJson = (config) => {
    const { packageRules = [] } = config ?? {}
    if (!packageRules.length || !fs.existsSync('renovate.json')) return null

    const renovate = JSON.parse(fs.readFileSync('renovate.json', 'utf8'))
    const existingRules = renovate.packageRules ?? []

    const isSyncix = (r) => r.description?.startsWith('syncix:')
    const userRules = existingRules.filter((r) => !isSyncix(r))
    const syncixRules = packageRules
    const newRules = [...syncixRules, ...userRules]

    const oldSyncixRules = existingRules.filter(isSyncix)
    const changed =
        JSON.stringify(oldSyncixRules) !== JSON.stringify(syncixRules)

    if (!changed) return { name: 'renovate.json', changed: false }

    const preview = () =>
        JSON.stringify({ ...renovate, packageRules: newRules }, null, 2) + '\n'

    return {
        name: 'renovate.json',
        changed: true,
        preview,
        apply: () => fs.writeFileSync('renovate.json', preview()),
        log: () =>
            logUpdate(
                'renovate.json',
                syncixRules.map((r) => change('rule', r.description ?? '?')),
            ),
    }
}

export const command = (
    file,
    cmd,
    { isCheck = false, pkgPreview = null } = {},
) => {
    let pkgOrig = null
    if (pkgPreview != null) {
        pkgOrig = fs.readFileSync('package.json')
        fs.writeFileSync('package.json', pkgPreview)
    }

    const before = fs.existsSync(file) ? fs.readFileSync(file) : null
    const { status } = spawnSync(cmd[0], cmd.slice(1), {
        stdio: isCheck ? 'ignore' : 'pipe',
    })
    const after = fs.existsSync(file) ? fs.readFileSync(file) : null

    if (isCheck) {
        if (before !== null) fs.writeFileSync(file, before)
        else if (after !== null) fs.unlinkSync(file)
        if (pkgOrig !== null) fs.writeFileSync('package.json', pkgOrig)
    } else if (status !== 0) {
        process.exit(status ?? 1)
    }

    const changed =
        before === null
            ? after !== null
            : after === null || !before.equals(after)

    return { name: file, changed, log: () => logUpdate(file) }
}
