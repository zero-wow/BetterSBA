const vm = require("vm")

const CALCULATOR_URL = "https://static.icy-veins.com/javascript/./midnight-talent-calculator-0867b1f6719d39bccd22aaf80da478be.js"
const ICY_VEINS_SITEMAP_URL = "https://www.icy-veins.com/sitemap.xml"
const NOXXIC_SITEMAP_URL = "https://www.noxxic.com/sitemap.xml"

const classTokenByName = {
    "Death Knight": "DEATHKNIGHT",
    "Demon Hunter": "DEMONHUNTER",
    "Druid": "DRUID",
    "Evoker": "EVOKER",
    "Hunter": "HUNTER",
    "Mage": "MAGE",
    "Monk": "MONK",
    "Paladin": "PALADIN",
    "Priest": "PRIEST",
    "Rogue": "ROGUE",
    "Shaman": "SHAMAN",
    "Warlock": "WARLOCK",
    "Warrior": "WARRIOR",
}

const entityMap = {
    "&amp;": "&",
    "&quot;": "\"",
    "&#39;": "'",
    "&apos;": "'",
    "&nbsp;": " ",
    "&ndash;": "-",
    "&mdash;": "-",
}

function decodeEntities(text) {
    let value = text || ""
    for (const [entity, decoded] of Object.entries(entityMap)) {
        value = value.split(entity).join(decoded)
    }
    return value
}

function cleanText(text) {
    return decodeEntities((text || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ")).trim()
}

function toTitleCase(text) {
    return cleanText(text).split(/\s+/).filter(Boolean).map((word) => word.charAt(0).toUpperCase() + word.slice(1)).join(" ")
}

function slugify(text) {
    return cleanText(text).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

async function fetchText(url) {
    let target = url
    if (target.startsWith("//")) {
        target = "https:" + target
    }
    const response = await fetch(target, {
        headers: {
            "User-Agent": "Mozilla/5.0",
        },
    })
    if (!response.ok) {
        throw new Error(`Failed to fetch ${target}: ${response.status}`)
    }
    return response.text()
}

function makeElement() {
    const el = {
        style: {
            setProperty() {},
            removeProperty() {},
            getPropertyValue() { return "" },
        },
        dataset: {},
        children: [],
        className: "",
        innerHTML: "",
        textContent: "",
        value: "",
        checked: false,
        offsetWidth: 0,
        offsetHeight: 0,
        clientWidth: 0,
        clientHeight: 0,
        scrollWidth: 0,
        scrollHeight: 0,
        appendChild() { return makeElement() },
        removeChild() {},
        remove() {},
        setAttribute() {},
        getAttribute() { return "" },
        addEventListener() {},
        removeEventListener() {},
        querySelector() { return makeElement() },
        querySelectorAll() { return [] },
        getElementsByClassName() { return [] },
        getElementsByTagName() { return [] },
        closest() { return makeElement() },
        focus() {},
        blur() {},
        click() {},
        cloneNode() { return makeElement() },
        insertAdjacentHTML() {},
        insertBefore() {},
        replaceChildren() {},
        getBoundingClientRect() {
            return { left: 0, top: 0, width: 0, height: 0, right: 0, bottom: 0 }
        },
        classList: {
            add() {},
            remove() {},
            contains() { return false },
            toggle() {},
        },
    }
    return new Proxy(el, {
        get(target, prop) {
            if (prop in target) {
                return target[prop]
            }
            if (prop === Symbol.iterator) {
                return function* () {}
            }
            return makeElement()
        },
        set(target, prop, value) {
            target[prop] = value
            return true
        },
    })
}

function installDomStubs() {
    const nativeFetch = global.fetch
    global.fetch = (url, ...args) => {
        let target = url
        if (typeof target === "string" && target.startsWith("//")) {
            target = "https:" + target
        }
        return nativeFetch(target, ...args)
    }
    const root = makeElement()
    global.window = {
        location: { hash: "" },
        addEventListener() {},
        removeEventListener() {},
        innerWidth: 1920,
        innerHeight: 1080,
        fetch: global.fetch,
    }
    global.document = {
        getElementById() { return makeElement() },
        querySelector() { return makeElement() },
        querySelectorAll() { return [] },
        createElement() { return makeElement() },
        body: root,
    }
    global.navigator = {
        clipboard: {
            writeText: async () => {},
        },
    }
    global.localStorage = {
        getItem() { return null },
        setItem() {},
        removeItem() {},
    }
    global.MIDNIGHTDEBUG = false
}

async function loadCalculator() {
    installDomStubs()
    const source = await fetchText(CALCULATOR_URL)
    vm.runInThisContext(source)
}

async function exportStringFromHash(hash) {
    const calculator = new MidnightTalentCalculator("x", hash, "-1", {
        embed: true,
        heroOnly: false,
        displayLevels: false,
        ptr: false,
        collapseEmbed: true,
    })
    calculator.renderer = new Proxy({
        hashLocked: false,
        idSuffix: "-1",
    }, {
        get(target, prop) {
            if (prop in target) {
                return target[prop]
            }
            return () => {}
        },
        set(target, prop, value) {
            target[prop] = value
            return true
        },
    })
    await calculator.processHash(hash)
    return calculator.exportString()
}

function readSpecID(importString) {
    const reader = new BinaryArrayReader(importString, base64Table)
    reader.read(8)
    return reader.read(16)
}

function parsePageMeta(html) {
    const specMatch = html.match(/"specData":\{"specName":"([^"]+)","className":"([^"]+)"\}/)
    const authorMatch = html.match(/"author":\{\s*"@type":"Person",\s*"name":"([^"]+)"/)
    const titleMatch = html.match(/"headline":"([^"]+)"/)
    const seasonMatch = titleMatch ? cleanText(titleMatch[1]).match(/-\s*([^"]+)$/) : null
    const author = authorMatch ? cleanText(authorMatch[1]).replace(/,([^\s])/g, ", $1") : "Icy Veins"
    return {
        specName: specMatch ? cleanText(specMatch[1]) : "",
        className: specMatch ? cleanText(specMatch[2]) : "",
        classToken: specMatch ? classTokenByName[cleanText(specMatch[2])] || "" : "",
        author,
        patch: seasonMatch ? cleanText(seasonMatch[1]) : "",
    }
}

function parseNoxxicPageMeta(html, url) {
    const titleMatch = html.match(/<title>([^<]+)<\/title>/i)
    const patchMatch = html.match(/Updated for the latest patch in World of Warcraft:\",\" \",\"([^\"]+)\",\" \(\",\"([^\"]+)\"/)
    const slugMatch = url.match(/\/wow\/guide\/([^/]+)\/talent-builds/)
    const slugParts = slugMatch ? slugMatch[1].split("-") : []
    const className = slugParts.length > 1 ? slugParts.slice(1).map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(" ") : ""
    const specName = slugParts.length > 0 ? slugParts[0].charAt(0).toUpperCase() + slugParts[0].slice(1) : ""
    return {
        title: titleMatch ? cleanText(titleMatch[1]) : "",
        classToken: classTokenByName[className] || "",
        className,
        specName,
        author: "Noxxic",
        patch: patchMatch ? `${cleanText(patchMatch[1])} (${cleanText(patchMatch[2])})` : "",
    }
}

function normalizeNoxxicEntryName(name, meta) {
    const specLabel = cleanText(`${meta.specName} ${meta.className}`.trim())
    const cleaned = cleanText(name)
    if (!cleaned) {
        return `${specLabel} - Recommended`
    }
    if (cleaned === "Recommended Build") {
        return `${specLabel} - Recommended`
    }
    const typedMatch = cleaned.match(/^(Recommended|Alternative\s+\d+)\s*-\s*(.+?)\s+build$/i)
    if (typedMatch) {
        const contentLabel = toTitleCase(typedMatch[2])
        return `${specLabel} - ${contentLabel}`
    }
    if (/build$/i.test(cleaned)) {
        return `${specLabel} - ${cleaned.replace(/\s+build$/i, "")}`
    }
    if (cleaned.startsWith(specLabel)) {
        return cleaned
    }
    return `${specLabel} - ${cleaned}`
}

function parseSectionBlocks(html) {
    const sections = []
    const builderNames = {}
    const buttonLabels = {}
    for (const buttonMatch of html.matchAll(/<span id="area_(\d+)_button">([\s\S]*?)<\/span>/g)) {
        buttonLabels[buttonMatch[1]] = cleanText(buttonMatch[2])
    }
    const matches = [...html.matchAll(/<div class="image_block_content" id="area_\d+">/g)]
    for (let i = 0; i < matches.length; i++) {
        const start = matches[i].index
        const end = i + 1 < matches.length ? matches[i + 1].index : html.length
        const block = html.slice(start, end)
        const areaMatch = matches[i][0].match(/area_(\d+)/)
        const areaID = areaMatch ? areaMatch[1] : ""
        const headingMatch = block.match(/<h[23][^>]*>([\s\S]*?)<\/h[23]>/)
        const name = headingMatch ? cleanText(headingMatch[1]) : ""
        const buttonLabel = buttonLabels[areaID] || ""
        for (const builderMatch of block.matchAll(/id="(midnight-skill-builder-\d+)"/g)) {
            builderNames[cleanText(builderMatch[1])] = {
                name,
                buttonLabel,
            }
        }
        sections.push({
            start,
            end,
            name,
            buttonLabel,
        })
    }
    return { sections, builderNames }
}

function parseRawWidgetEntries(html) {
    const entries = []
    const widgetRegex = /<div class="export_string_widget compact">\s*<span>([\s\S]*?)<\/span>[\s\S]*?<div style="display:none;">([\s\S]*?)<\/div>/g
    for (const match of html.matchAll(widgetRegex)) {
        const name = cleanText(match[1])
        const importString = cleanText(match[2])
        if (name && importString) {
            entries.push({ name, importString })
        }
    }
    return entries
}

// A generic beginner build on a page that mentions SBA is not an SBA build.
// Only export widgets individually designated for assist/one-button use qualify.
// Compatible starter builds require a separate reviewed evidence record.
function isExplicitAssistantBuild(entry) {
    return /\b(?:SBA|(?:single|one)[ -]button|rotation[ -]assist|annihilator[ -]assist)\b/i.test(`${entry.name || ""} ${entry.buttonLabel || ""}`)
}

function parseHashEntries(html, sections, builderNames) {
    const entries = []
    const hashRegex = /const args = \[\s*"([^"]+)",\s*\/\/ targetElementId\s*"([^"]+)",\s*\/\/ hash/g
    for (const match of html.matchAll(hashRegex)) {
        const builderID = cleanText(match[1])
        const hash = cleanText(match[2])
        if (!hash || !builderID) {
            continue
        }
        const section = sections.find((item) => match.index >= item.start && match.index < item.end)
        const builderInfo = builderNames[builderID]
        entries.push({
            name: builderInfo && builderInfo.name ? builderInfo.name : (section && section.name ? section.name : builderID),
            buttonLabel: builderInfo && builderInfo.buttonLabel ? builderInfo.buttonLabel : (section && section.buttonLabel ? section.buttonLabel : ""),
            hash,
        })
    }
    return entries
}

function parseNoxxicBuildLabels(html) {
    const labels = []
    const buttonRegex = /<button id="[^"]*-tab-\d+"[^>]*>([\s\S]*?)<\/button>/g
    for (const match of html.matchAll(buttonRegex)) {
        const spans = [...match[1].matchAll(/<span[^>]*>([\s\S]*?)<\/span>/g)].map((spanMatch) => cleanText(spanMatch[1])).filter(Boolean)
        if (!spans.length) {
            continue
        }
        const label = spans.length > 1 ? `${spans[0]} - ${spans[1]}` : spans[0]
        labels.push(label)
    }
    return labels
}

function parseNoxxicEntries(html, fallbackName) {
    const labels = parseNoxxicBuildLabels(html)
    const entries = []
    const seen = new Set()
    let index = 0
    for (const match of html.matchAll(/copyText\\?":\\?"([A-Za-z0-9+/=]{80,})/g)) {
        const importString = cleanText(match[1])
        if (!importString || seen.has(importString)) {
            continue
        }
        seen.add(importString)
        index = index + 1
        entries.push({
            name: labels[index - 1] || (index === 1 && fallbackName ? fallbackName : `Build ${index}`),
            importString,
        })
    }
    return entries
}

function buildID(source, specID, name, seen) {
    const base = `${source}-${specID}-${slugify(name)}`
    let id = base
    let counter = 2
    while (seen.has(id)) {
        id = `${base}-${counter}`
        counter = counter + 1
    }
    seen.add(id)
    return id
}

function toLuaString(value) {
    const str = value == null ? "" : String(value)
    return "\"" + str.replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
}

function formatLua(entries) {
    const lines = []
    lines.push("local ADDON_NAME, NS = ...")
    lines.push("")
    lines.push("NS.TALENT_BUILD_CUSTOM_ID = \"CUSTOM\"")
    lines.push("NS.TALENT_BUILD_FILTER_ALL = \"All\"")
    lines.push("NS.TALENT_BUILD_TYPE_BUILTIN = \"Built-In\"")
    lines.push("NS.TALENT_BUILD_TYPE_USER = \"User\"")
    lines.push("NS.TALENT_BUILD_TYPE_CUSTOM = \"Custom\"")
    lines.push("NS.TALENT_BUILD_TYPES = {")
    lines.push("    NS.TALENT_BUILD_TYPE_BUILTIN,")
    lines.push("    NS.TALENT_BUILD_TYPE_USER,")
    lines.push("    NS.TALENT_BUILD_TYPE_CUSTOM,")
    lines.push("}")
    lines.push("NS.TALENT_BUILD_RATINGS = { \"S\", \"A\", \"B\", \"C\", \"D\" }")
    lines.push("NS.TALENT_BUILD_AUTO_APPLY_MODES = { \"Auto-Apply\", \"Prompt Before Spending\" }")
    lines.push("NS.TALENT_BUILD_SOURCES = {")
    lines.push("    NS.TALENT_BUILD_FILTER_ALL,")
    lines.push("    \"Icy Veins\",")
    lines.push("    \"Noxxic\",")
    lines.push("    \"Wowhead\",")
    lines.push("    \"Custom\",")
    lines.push("}")
    lines.push("NS.TALENT_BUILD_SOURCE_URLS = {")
    lines.push("    [\"Icy Veins\"] = \"https://www.icy-veins.com/wow/news/single-button-assistant-and-assisted-highlight-design-intentions/\",")
    lines.push("    [\"Noxxic\"] = \"https://www.noxxic.com/wow/\",")
    lines.push("    [\"Wowhead\"] = \"https://www.wowhead.com/guide/classes\",")
    lines.push("    [\"Custom\"] = \"\",")
    lines.push("}")
    lines.push("NS.TALENT_BUILD_CATALOG = {")
    lines.push("    version = 1,")
    lines.push("    entries = {")
    for (const entry of entries) {
        lines.push("        {")
        lines.push(`            id = ${toLuaString(entry.id)},`)
        lines.push(`            classToken = ${toLuaString(entry.classToken)},`)
        lines.push(`            specID = ${entry.specID},`)
        lines.push(`            name = ${toLuaString(entry.name)},`)
        lines.push(`            author = ${toLuaString(entry.author)},`)
        lines.push(`            rating = ${toLuaString(entry.rating)},`)
        lines.push(`            source = ${toLuaString(entry.source)},`)
        lines.push(`            catalogSource = ${toLuaString(entry.catalogSource || entry.source)},`)
        lines.push(`            sourceURL = ${toLuaString(entry.sourceURL)},`)
        lines.push(`            patch = ${toLuaString(entry.patch)},`)
        lines.push(`            importString = ${toLuaString(entry.importString)},`)
        lines.push("            notes = \"\",")
        lines.push("            category = \"\",")
        lines.push("            buildType = NS.TALENT_BUILD_TYPE_BUILTIN,")
        lines.push("        },")
    }
    lines.push("    },")
    lines.push("}")
    lines.push("")
    return lines.join("\n")
}

async function collectIcyVeinsEntries() {
    const xml = await fetchText(ICY_VEINS_SITEMAP_URL)
    const urls = [...xml.matchAll(/<loc>(https:\/\/www\.icy-veins\.com\/wow\/[^<]*easy-mode)<\/loc>/g)].map((match) => match[1])
    const entries = []
    const seenIDs = new Set()
    const seenKeys = new Set()

    for (const url of urls) {
        const html = await fetchText(url)
        if (!/(?:Combat Assistant|Single[ -]Button Assistant|Rotation Assist)/i.test(html)) {
            continue
        }

        const meta = parsePageMeta(html)
        if (!meta.classToken) {
            continue
        }

        const pageEntries = []
        const pageImportStrings = new Set()
        const sectionData = parseSectionBlocks(html)

        for (const rawEntry of parseRawWidgetEntries(html)) {
            if (!isExplicitAssistantBuild(rawEntry)) {
                continue
            }
            if (!pageImportStrings.has(rawEntry.importString)) {
                pageImportStrings.add(rawEntry.importString)
                pageEntries.push(rawEntry)
            }
        }

        const hashEntries = parseHashEntries(html, sectionData.sections, sectionData.builderNames)
        for (const hashEntry of hashEntries) {
            if (!isExplicitAssistantBuild(hashEntry)) {
                continue
            }
            const importString = await exportStringFromHash(hashEntry.hash)
            if (!pageImportStrings.has(importString)) {
                pageImportStrings.add(importString)
                pageEntries.push({
                    name: hashEntry.name,
                    buttonLabel: hashEntry.buttonLabel,
                    importString,
                })
            }
        }

        const nameCounts = {}
        for (const pageEntry of pageEntries) {
            nameCounts[pageEntry.name] = (nameCounts[pageEntry.name] || 0) + 1
        }
        for (const pageEntry of pageEntries) {
            if (nameCounts[pageEntry.name] > 1 && pageEntry.buttonLabel && !pageEntry.name.includes(pageEntry.buttonLabel)) {
                pageEntry.name = `${pageEntry.name} - ${pageEntry.buttonLabel}`
            }
        }
        const finalNameCounts = {}
        for (const pageEntry of pageEntries) {
            finalNameCounts[pageEntry.name] = (finalNameCounts[pageEntry.name] || 0) + 1
        }
        const finalNameSeen = {}
        for (const pageEntry of pageEntries) {
            if ((finalNameCounts[pageEntry.name] || 0) > 1) {
                finalNameSeen[pageEntry.name] = (finalNameSeen[pageEntry.name] || 0) + 1
                pageEntry.name = `${pageEntry.name} - ${finalNameSeen[pageEntry.name]}`
            }
        }

        for (const pageEntry of pageEntries) {
            const importString = pageEntry.importString
            if (!importString) {
                continue
            }
            const specID = readSpecID(importString)
            const uniqueKey = `${meta.classToken}|${specID}|${pageEntry.name}|${importString}`
            if (seenKeys.has(uniqueKey)) {
                continue
            }
            seenKeys.add(uniqueKey)
            entries.push({
                id: buildID("ICY", specID, pageEntry.name, seenIDs),
                classToken: meta.classToken,
                specID,
                name: pageEntry.name,
                author: meta.author,
                rating: "",
                source: "Icy Veins",
                catalogSource: "Icy Veins",
                sourceURL: url,
                patch: meta.patch,
                importString,
            })
        }
    }

    entries.sort((a, b) => {
        if (a.classToken !== b.classToken) {
            return a.classToken < b.classToken ? -1 : 1
        }
        if (a.specID !== b.specID) {
            return a.specID - b.specID
        }
        return a.name.localeCompare(b.name)
    })
    return entries
}

async function collectNoxxicEntries() {
    const xml = await fetchText(NOXXIC_SITEMAP_URL)
    const urls = [...xml.matchAll(/<loc>(https:\/\/www\.noxxic\.com\/wow\/guide\/[^<]*\/talent-builds)<\/loc>/g)].map((match) => match[1])
    const entries = []
    const seenIDs = new Set()

    for (const url of urls) {
        const html = await fetchText(url)
        const meta = parseNoxxicPageMeta(html, url)
        if (!meta.classToken) {
            continue
        }
        const pageEntries = parseNoxxicEntries(html, "Recommended Build")
        for (const pageEntry of pageEntries) {
            if (!pageEntry.importString) {
                continue
            }
            const specID = readSpecID(pageEntry.importString)
            entries.push({
                id: buildID("NOX", specID, pageEntry.name, seenIDs),
                classToken: meta.classToken,
                specID,
                name: normalizeNoxxicEntryName(pageEntry.name, meta),
                author: meta.author,
                rating: "A",
                source: "Noxxic",
                catalogSource: "Noxxic",
                sourceURL: url,
                patch: meta.patch,
                importString: pageEntry.importString,
            })
        }
    }

    entries.sort((a, b) => {
        if (a.classToken !== b.classToken) {
            return a.classToken < b.classToken ? -1 : 1
        }
        if (a.specID !== b.specID) {
            return a.specID - b.specID
        }
        return a.name.localeCompare(b.name)
    })
    return entries
}

function dedupeEntries(entries) {
    const deduped = []
    const seenImportStrings = new Set()
    for (const entry of entries) {
        if (!entry.importString || seenImportStrings.has(entry.importString)) {
            continue
        }
        seenImportStrings.add(entry.importString)
        deduped.push(entry)
    }
    return deduped
}

async function collectEntries(sourceMode) {
    const sources = []
    if (sourceMode === "all") {
        sources.push(await collectIcyVeinsEntries())
        sources.push(await collectNoxxicEntries())
    } else if (sourceMode === "noxxic") {
        sources.push(await collectNoxxicEntries())
    } else {
        sources.push(await collectIcyVeinsEntries())
    }

    const combined = []
    for (const batch of sources) {
        for (const entry of batch) {
            combined.push(entry)
        }
    }
    const deduped = dedupeEntries(combined)
    deduped.sort((a, b) => {
        if (a.classToken !== b.classToken) {
            return a.classToken < b.classToken ? -1 : 1
        }
        if (a.specID !== b.specID) {
            return a.specID - b.specID
        }
        if (a.source !== b.source) {
            return a.source.localeCompare(b.source)
        }
        return a.name.localeCompare(b.name)
    })
    return deduped
}

async function main() {
    await loadCalculator()
    const format = (process.argv[2] || "json").toLowerCase()
    const sourceMode = (process.argv[3] || "icy").toLowerCase()
    const entries = await collectEntries(sourceMode)
    if (format === "lua") {
        process.stdout.write(formatLua(entries))
        return
    }
    process.stdout.write(JSON.stringify(entries, null, 2))
}

main().catch((error) => {
    console.error(error)
    process.exit(1)
})
