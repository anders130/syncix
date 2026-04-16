import fs from 'fs'
import { spawnSync } from 'child_process'

import { logHeader, logOk, logUpdate, change, flush } from './ui.mjs'

const { versions, nvmrc, packageJson, postSync } = JSON.parse(process.argv[2])
const versionLabels = Object.entries(versions ?? {}).map(
    ([key, value]) => `${key} ${value}`,
)

const syncNvmrc = () => {
    if (nvmrc == null) {
        return
    }

    const current = fs.existsSync('.nvmrc')
        ? fs.readFileSync('.nvmrc', 'utf8').trim()
        : ''
    if (current === nvmrc) {
        logOk('.nvmrc')
    } else {
        logUpdate(change('.nvmrc', nvmrc))
        fs.writeFileSync('.nvmrc', `${nvmrc}\n`)
    }
}

const syncPackageJson = () => {
    if (!packageJson || !Object.keys(packageJson).length) {
        return
    }

    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'))

    const sections = Object.entries(packageJson)
        .map(([section, fields]) => [
            section,
            Object.entries(fields).filter(
                ([key, value]) => (pkg[section] ?? {})[key] !== value,
            ),
        ])
        .filter(([, changed]) => changed.length)

    if (!sections.length) {
        logOk('package.json')
        return
    }

    sections.forEach(([section, changed]) => {
        changed.forEach(([key, value]) => {
            pkg[section] ??= {}
            pkg[section][key] = value
        })
        logUpdate(
            section,
            changed.map(([key, value]) => change(key, value)),
        )
    })

    fs.writeFileSync('package.json', `${JSON.stringify(pkg, null, 2)}\n`)
    if (postSync && postSync.length) {
        const [bin, ...args] = postSync
        spawnSync(bin, args, { stdio: 'pipe' })
        logUpdate('lockfile')
    }
}

logHeader('nix-sync', versionLabels)
syncNvmrc()
syncPackageJson()
flush()
