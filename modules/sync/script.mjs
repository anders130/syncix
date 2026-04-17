import { logHeader, logOk, flush } from './ui.mjs'
import * as core from './core.mjs'

const { versions, nvmrc, packageJson, commands } = JSON.parse(process.argv[2])
const isCheck = process.argv.includes('--check')
const cmds = Object.entries(commands ?? {})

logHeader(
    'nix-sync',
    Object.entries(versions ?? {}).map(([k, v]) => `${k} ${v}`),
)

const nvmTask = core.nvmrc(nvmrc)
const pkgTask = core.packageJson(packageJson)
const baseTasks = [nvmTask, pkgTask].filter(Boolean)

if (isCheck) {
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
