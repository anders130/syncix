const indent = (n) => '  '.repeat(n)

const isComment = (s) => !s || s.trimStart().startsWith('#')

const indentOf = (line) => line.length - line.trimStart().length

const parseScalar = (s) =>
    s === 'true'
        ? true
        : s === 'false'
          ? false
          : s === 'null' || s === '~'
            ? null
            : (s[0] === '"' || s[0] === "'") && s.at(-1) === s[0]
              ? s.slice(1, -1)
              : s

const quoteScalar = (s) =>
    !s || /^[{[\]|>&*!%@`'"#?:-]/.test(s) || /^(true|false|null|~)$/.test(s)
        ? `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
        : s

// Returns index of next non-comment, non-empty line, or lines.length
const nextReal = (lines, from) => {
    let i = from
    while (i < lines.length && isComment(lines[i])) i++
    return i
}

// Parse a block of mappings at blockIndent. Returns { value, end }.
function parseBlock(lines, start, blockIndent) {
    const obj = {}
    let i = nextReal(lines, start)

    while (i < lines.length) {
        const raw = lines[i]
        if (indentOf(raw) < blockIndent) break

        const trimmed = raw.trimStart()
        const colon = trimmed.indexOf(':')
        if (colon < 0) {
            i++
            continue
        }

        const key = trimmed.slice(0, colon)
        const rest = trimmed.slice(colon + 1).trim()

        if (rest) {
            obj[key] = parseScalar(rest)
            i = nextReal(lines, i + 1)
        } else {
            const ni = nextReal(lines, i + 1)
            const childIndent = ni < lines.length ? indentOf(lines[ni]) : -1
            if (childIndent > blockIndent) {
                const res = parseBlock(lines, ni, childIndent)
                obj[key] = res.value
                i = nextReal(lines, res.end)
            } else {
                obj[key] = null
                i = nextReal(lines, i + 1)
            }
        }
    }

    return { value: obj, end: i }
}

export const parse = (text) =>
    text?.trim() ? parseBlock(text.split('\n'), 0, 0).value : {}

export const deepMerge = (target, source) =>
    Object.entries(source).reduce(
        (acc, [k, v]) => ({
            ...acc,
            [k]:
                v &&
                typeof v === 'object' &&
                acc[k] &&
                typeof acc[k] === 'object'
                    ? deepMerge(acc[k], v)
                    : v,
        }),
        { ...target },
    )

export const differs = (existing, patch) =>
    Object.entries(patch).some(([k, v]) =>
        v &&
        typeof v === 'object' &&
        existing[k] &&
        typeof existing[k] === 'object'
            ? differs(existing[k], v)
            : JSON.stringify(existing[k]) !== JSON.stringify(v),
    )

export const serialize = (obj, depth = 0) =>
    Object.entries(obj)
        .map(([k, v]) =>
            v === null || v === undefined
                ? `${indent(depth)}${k}:`
                : typeof v === 'boolean'
                  ? `${indent(depth)}${k}: ${v}`
                  : typeof v === 'object'
                    ? `${indent(depth)}${k}:\n${serialize(v, depth + 1)}`
                    : `${indent(depth)}${k}: ${quoteScalar(String(v))}`,
        )
        .join('\n')
