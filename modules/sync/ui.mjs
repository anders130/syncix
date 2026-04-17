const green = '\x1b[32m'
const yellow = '\x1b[33m'
const cyan = '\x1b[36m'
const reset = '\x1b[0m'
const bold = '\x1b[1m'
const dim = '\x1b[2m'

const check = '\u2713'
const up = '\u2191'
const arrow = '\u2192'
const diamond = '\u25c6'
const dot = '\u00b7'
const branch = '\u251c\u2574'
const last = '\u2514\u2574'
const pipe = '\u2502'

const c = (color, text) => `${color}${text}${reset}`

const lines = []

const flush = () => {
    lines.forEach(([color, icon, msg, children], i) => {
        const isLast = i === lines.length - 1
        const tree = isLast ? last : branch

        process.stdout.write(`${c(dim, tree)}${c(color, icon)} ${msg}\n`)

        const childPrefix = isLast ? '  ' : `${c(dim, pipe)} `
        children.forEach((cm, j) => {
            const childTree = j < children.length - 1 ? branch : last
            process.stdout.write(`${childPrefix}${c(dim, childTree)} ${cm}\n`)
        })
    })

    lines.length = 0
}

const logHeader = (title, labels) => {
    const suffix = labels.length ? `  ${c(dim, labels.join(` ${dot} `))}` : ''
    process.stdout.write(`${c(bold, `${diamond} ${title}`)}${suffix}\n`)
}

const logOk = (msg) => lines.push([green, check, msg, []])
const logUpdate = (msg, children = []) =>
    lines.push([yellow, up, msg, children])
const change = (key, value) => `${key} ${c(dim, arrow)} ${c(cyan, value)}`

export { logHeader, logOk, logUpdate, change, flush }
