const [green, yellow, cyan, reset, bold, dim] = [
    '\x1b[32m',
    '\x1b[33m',
    '\x1b[36m',
    '\x1b[0m',
    '\x1b[1m',
    '\x1b[2m',
]
const [check, up, arrow, diamond, dot, branch, last, pipe] = [
    '\u2713',
    '\u2191',
    '\u2192',
    '\u25c6',
    '\u00b7',
    '\u251c\u2574',
    '\u2514\u2574',
    '\u2502',
]

const c = (color, text) => `${color}${text}${reset}`

const lines = []
const log = (color, icon, msg, children = []) =>
    lines.push([color, icon, msg, children])

const flush = () =>
    lines.forEach(([color, icon, msg, children], i) => {
        const isLast = i === lines.length - 1
        const tree = isLast && !children.length ? last : branch
        process.stdout.write(`${c(dim, tree)}${c(color, icon)} ${msg}\n`)

        const childPrefix = isLast ? '  ' : `${c(dim, pipe)} `
        children.forEach(([cc, ci, cm], j) => {
            const childTree = j < children.length - 1 ? branch : last
            process.stdout.write(
                `${childPrefix}${c(dim, childTree)}${c(cc, ci)} ${cm}\n`,
            )
        })
    })

const logHeader = (title, labels) => {
    const suffix = labels.length ? `  ${c(dim, labels.join(` ${dot} `))}` : ''
    process.stdout.write(`${c(bold, `${diamond} ${title}`)}${suffix}\n`)
}

const logOk = (msg) => log(green, check, msg)
const logUpdate = (msg, children = []) =>
    log(
        yellow,
        up,
        msg,
        children.map((child) => ['', '', child]),
    )
const change = (key, value) => `${key} ${c(dim, arrow)} ${c(cyan, value)}`

export { logHeader, logOk, logUpdate, change, flush }
