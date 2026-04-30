import fs from 'fs'
import { logUpdate, change } from 'syncix'

const renovateJson = (file) => (config) => {
    const { packageRules: syncixRules = [] } = config ?? {}
    if (!syncixRules.length || !fs.existsSync(file)) return null

    const existing = JSON.parse(fs.readFileSync(file, 'utf8'))
    const isSyncix = (r) => r.description?.startsWith('syncix:')
    const oldSyncixRules = (existing.packageRules ?? []).filter(isSyncix)

    if (JSON.stringify(oldSyncixRules) === JSON.stringify(syncixRules))
        return { name: file, changed: false }

    const userRules = (existing.packageRules ?? []).filter((r) => !isSyncix(r))
    const content =
        JSON.stringify(
            { ...existing, packageRules: [...syncixRules, ...userRules] },
            null,
            2,
        ) + '\n'
    return {
        name: file,
        changed: true,
        preview: () => content,
        apply: () => fs.writeFileSync(file, content),
        log: () =>
            logUpdate(
                file,
                syncixRules.map((r) => change('rule', r.description ?? '?')),
            ),
    }
}

export const writeHandlers = {
    'renovate.json': renovateJson('renovate.json'),
}
