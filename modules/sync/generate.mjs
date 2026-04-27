import fs from 'fs'
import { spawnSync } from 'child_process'
import { logUpdate } from './ui.mjs'

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
