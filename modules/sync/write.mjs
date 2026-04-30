import fs from 'fs'
import { logUpdate, change } from './ui.mjs'
import {
    parse as parseYaml,
    deepMerge,
    differs,
    serialize as serializeYaml,
} from './yaml.mjs'

export const text = (file) => (val) => {
    if (val == null) return null
    const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').trim() : ''
    if (cur === val) return { name: file, changed: false }
    return {
        name: file,
        changed: true,
        apply: () => fs.writeFileSync(file, `${val}\n`),
        log: () => logUpdate(file, [change('value', val)]),
    }
}

export const jsonPatch = (file) => (config) => {
    if (!config || !Object.keys(config).length || !fs.existsSync(file))
        return null

    const doc = JSON.parse(fs.readFileSync(file, 'utf8'))

    const isAtomic = (v) =>
        typeof v !== 'object' || v === null || Array.isArray(v)

    const diffs = Object.entries(config).flatMap(([section, fields]) => {
        if (isAtomic(fields)) {
            return JSON.stringify(doc[section]) !== JSON.stringify(fields)
                ? [{ section, key: null, val: fields }]
                : []
        }
        return Object.entries(fields)
            .filter(([key, val]) => (doc[section] ?? {})[key] !== val)
            .map(([key, val]) => ({ section, key, val }))
    })

    if (!diffs.length) return { name: file, changed: false }

    const preview = () => {
        const next = JSON.parse(JSON.stringify(doc))
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
        name: file,
        changed: true,
        preview,
        apply: () => fs.writeFileSync(file, preview()),
        log: () =>
            logUpdate(
                file,
                diffs.map(({ section, key, val }) =>
                    change(key ?? section, val),
                ),
            ),
    }
}

export const yamlPatch = (file) => (patch) => {
    if (!patch || !Object.keys(patch).length) return null
    const existing = fs.existsSync(file)
        ? parseYaml(fs.readFileSync(file, 'utf8'))
        : {}
    if (!differs(existing, patch)) return { name: file, changed: false }
    const merged = deepMerge(existing, patch)
    const content = serializeYaml(merged) + '\n'
    return {
        name: file,
        changed: true,
        apply: () => fs.writeFileSync(file, content),
        log: () => logUpdate(file, [change('patch', file)]),
        preview: () => content,
    }
}

export const writeHandlers = {
    '.nvmrc': text('.nvmrc'),
    'package.json': jsonPatch('package.json'),
}
