import { logHeader, logOk, flush } from './ui.mjs'
import * as core from './core.mjs'

const { versions, nvmrc, packageJson, commands } = JSON.parse(process.argv[2])
const isCheck = process.argv.includes('--check')

logHeader(
    'nix-sync',
    Object.entries(versions ?? {}).map(([k, v]) => `${k} ${v}`),
)

const nvmTask = core.nvmrc(nvmrc)
const pkgTask = core.packageJson(packageJson)

const baseTasks = [nvmTask, pkgTask].filter(Boolean)

const pkgPreview =
    isCheck && pkgTask?.changed && typeof pkgTask.preview === 'function'
        ? pkgTask.preview()
        : null

const cmdTasks = Object.entries(commands ?? {}).map(([file, cmd]) =>
    core.command(file, cmd, {
        pkgChanged: !!pkgTask?.changed,
        pkgPreview,
        isCheck,
    }),
)

const allTasks = [...baseTasks, ...cmdTasks]

if (isCheck) {
    allTasks.forEach((t) => (t.changed ? t.log() : logOk(t.name)))
    flush()
    process.exit(allTasks.some((t) => t.changed) ? 1 : 0)
}

allTasks.forEach((t) => {
    if (!t.changed) return logOk(t.name)

    try {
        t.apply?.()
    } catch (err) {
        console.error(`✖ ${t.name} failed:`)
        console.error(err)
        process.exit(1)
    }

    t.log()
})

flush()
