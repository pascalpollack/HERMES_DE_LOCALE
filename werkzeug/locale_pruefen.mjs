#!/usr/bin/env node
// Static check of the German locale sources in this repository.
// It does not build Hermes, does not start it, and does not look at a
// Windows installation. Key parity uses the TypeScript parser from a
// Hermes checkout (--typescript), so missing keys are a diff, not a guess.

import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'

const require = createRequire(import.meta.url)

const repo = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..')

function arg(name) {
  const i = process.argv.indexOf(name)
  return i === -1 ? '' : process.argv[i + 1] || ''
}

const tsPath = arg('--typescript')
if (!tsPath) {
  console.error('Pfad zu typescript.js fehlt: --typescript <node_modules/typescript/lib/typescript.js>')
  process.exit(2)
}
const ts = require(path.resolve(tsPath))

function read(rel) {
  return fs.readFileSync(path.join(repo, rel), 'utf8')
}

function source(rel) {
  const text = read(rel)
  return ts.createSourceFile(rel, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
}

function propName(name) {
  if (!name) return null
  if (ts.isIdentifier(name) || ts.isStringLiteral(name) || ts.isNumericLiteral(name)) return name.text
  return null
}

function leaves(objectLiteral, prefix, out) {
  for (const prop of objectLiteral.properties) {
    if (ts.isSpreadAssignment(prop)) {
      throw new Error('Spread in einem Locale-Objekt wird nicht still übersprungen')
    }
    if (!ts.isPropertyAssignment(prop) && !ts.isShorthandPropertyAssignment(prop)) {
      throw new Error('Unerwartete Objektform: ' + ts.SyntaxKind[prop.kind])
    }
    const name = propName(prop.name)
    if (!name) throw new Error('Schlüssel ohne Namen')
    const next = prefix ? prefix + '.' + name : name
    if (ts.isPropertyAssignment(prop) && ts.isObjectLiteralExpression(prop.initializer)) {
      leaves(prop.initializer, next, out)
    } else {
      out.add(next)
    }
  }
}

function objectNamed(sf, name) {
  const found = []
  for (const st of sf.statements) {
    if (!ts.isVariableStatement(st)) continue
    for (const decl of st.declarationList.declarations) {
      if (!ts.isIdentifier(decl.name) || decl.name.text !== name) continue
      if (!decl.initializer || !ts.isObjectLiteralExpression(decl.initializer)) {
        throw new Error(name + ' ist kein Objekt')
      }
      found.push(decl.initializer)
    }
  }
  if (found.length !== 1) throw new Error(name + ': ' + found.length + ' Objekte')
  return found[0]
}

function compare(label, enObj, deObj) {
  const en = new Set()
  const de = new Set()
  leaves(enObj, '', en)
  leaves(deObj, '', de)
  const missing = [...en].filter(k => !de.has(k)).sort()
  const extra = [...de].filter(k => !en.has(k)).sort()
  console.log(label + ': en ' + en.size + ', de ' + de.size + ', fehlend ' + missing.length + ', zusätzlich ' + extra.length)
  if (missing.length || extra.length) {
    for (const k of missing.slice(0, 20)) console.error('  fehlt: ' + k)
    for (const k of extra.slice(0, 20)) console.error('  zusätzlich: ' + k)
    return 1
  }
  return 0
}

let failed = 0

const core = source('src/i18n/de.ts')
const english = source('src/i18n/en.ts')
failed |= compare('Kernkatalog', objectNamed(english, 'en'), objectNamed(core, 'de'))

const deText = read('src/i18n/de.ts')
if (!deText.includes('export const de: Translations')) {
  console.error('de.ts ist nicht als Translations typisiert')
  failed = 1
}
if (deText.includes('defineLocale')) {
  console.error('de.ts benutzt defineLocale')
  failed = 1
}

const catalog = read('src/i18n/catalog.ts')
if (!catalog.includes("import { de } from './de'") || !catalog.includes('\n  de\n')) {
  console.error('catalog.ts trägt de nicht')
  failed = 1
}

const types = read('src/i18n/types.ts')
if (!types.includes("'de'")) {
  console.error("Locale-Typ ohne 'de'")
  failed = 1
}

const aliases = [
  ["de: 'de'", 'de'],
  ["'de-de': 'de'", 'de-de'],
  ["de_de: 'de'", 'de_de'],
  ["'de-at': 'de'", 'de-at'],
  ['de_at: \'de\'', 'de_at'],
  ["'de-ch': 'de'", 'de-ch'],
  ["de_ch: 'de'", 'de_ch'],
  ["'de-li': 'de'", 'de-li'],
  ["de_li: 'de'", 'de_li'],
  ["'de-lu': 'de'", 'de-lu'],
  ["de_lu: 'de'", 'de_lu'],
  ["german: 'de'", 'german'],
  ["deutsch: 'de'", 'deutsch']
]
const languages = read('src/i18n/languages.ts')
for (const [needle, alias] of aliases) {
  if (!languages.includes(needle)) {
    console.error('Alias fehlt: ' + alias)
    failed = 1
  }
}

for (const rel of [
  'src/plugins/hermes-bots/i18n.ts',
  'src/plugins/kanban/i18n.ts'
]) {
  const sf = source(rel)
  const text = read(rel)
  const marker = rel.includes('bots') ? 'BOTS_LOCALES' : 'KANBAN_LOCALES'
  if (!text.includes(marker + ': PluginLocaleBundles') || !text.includes('de,')) {
    console.error(marker + ' ohne de')
    failed = 1
  }
  failed |= compare(marker, objectNamed(sf, 'en'), objectNamed(sf, 'de'))
}

for (const name of ['de', 'ja', 'ru', 'ar', 'zh', 'zh-hant']) {
  const rel = 'src/components/chat/intro-copy.' + name + '.jsonl'
  const lines = read(rel).split(/\n/).filter(line => line.length > 0)
  if (lines.length !== 75) {
    console.error(rel + ': ' + lines.length + ' Zeilen, erwartet 75')
    failed = 1
    continue
  }
  for (const line of lines) JSON.parse(line)
  console.log(rel + ': 75 Zeilen, JSON gelesen')
}

if (failed) process.exit(1)
console.log('OK')
