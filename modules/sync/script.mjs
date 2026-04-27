import { spawnSync } from 'child_process'
import { logHeader, logOk, flush } from './ui.mjs'
import * as core from './core.mjs'

const { versions, write, generate, format } = JSON.parse(process.argv[2])
const isCheck = process.argv.includes('--check')
const cmds = Object.entries(generate ?? {})
const fmt = format ?? []

logHeader(
    'nix-sync',
    Object.entries(versions ?? {}).map(([k, v]) => `${k} ${v}`),
)

const baseTasks = Object.entries(write ?? {})
    .map(([file, val]) => core.writeHandlers[file]?.(val))
    .filter(Boolean)

if (isCheck) {
    const pkgTask = baseTasks.find((t) => t.name === 'package.json')
    const pkgPreview = pkgTask?.changed ? pkgTask.preview() : null
    const cmdTasks = cmds.map(([file, cmd]) =>
        core.command(file, cmd, { isCheck, pkgPreview }),
    )
    const allTasks = [...baseTasks, ...cmdTasks]
    allTasks.forEach((t) => (t.changed ? t.log() : logOk(t.name)))
    flush()
    process.exit(allTasks.some((t) => t.changed) ? 1 : 0)
}

// apply base tasks first so commands run against updated state
baseTasks.forEach((t) => {
    if (!t.changed) return logOk(t.name)
    try {
        t.apply()
        if (fmt.length)
            spawnSync(fmt[0], [...fmt.slice(1), t.name], { stdio: 'pipe' })
    } catch (err) {
        console.error(`✖ ${t.name} failed:`)
        console.error(err)
        process.exit(1)
    }
    t.log()
})

cmds.forEach(([file, cmd]) => {
    const t = core.command(file, cmd)
    if (!t.changed) return logOk(t.name)
    t.log()
})

flush()
