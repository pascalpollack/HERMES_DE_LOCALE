/**
 * Plugin-scoped i18n — the `ctx.storage` analog for locale bundles. A plugin
 * ships its own strings and registers them under its id; it never edits core
 * `en.ts`. Resolution mirrors the app translator: active locale → the plugin's
 * own `en` bundle → the key itself. The active locale is always the app's
 * (`display.language`) — plugins follow the user's choice, they don't own it.
 *
 * Two consumers, same shape as core (`useI18n` / `translateNow`):
 *  - `usePluginI18n(id)` — reactive translator for React UI (re-renders on a
 *    locale switch or a late bundle registration);
 *  - `ctx.i18n.t` — module-level translator for handlers/stores (non-reactive).
 */

import { useStore } from '@nanostores/react'
import { atom } from 'nanostores'
import { useCallback } from 'react'

import { useI18n } from './context'
import { getRuntimeI18nLocale, translateFrom } from './runtime'
import type { Locale } from './types'

/** A leaf message: a literal or an interpolator (`n => `${n} left``). */
export type PluginMessageValue = string | ((...args: never[]) => string)

/** A plugin's messages for one locale — nested trees allowed, addressed by
 *  dot-path (`panel.title`). */
export interface PluginMessages {
  [key: string]: PluginMessages | PluginMessageValue
}

/** Locale → messages. Keyed by the app's locales so autocomplete guides you;
 *  a bundle for a locale the app can't select is simply never resolved. */
export type PluginLocaleBundles = Partial<Record<Locale, PluginMessages>>

/** Resolve `key` for this plugin against `args`; falls back to English, then
 *  the raw key. */
export type PluginTranslate = (key: string, ...args: unknown[]) => string

export interface PluginI18n {
  /** Merge locale bundles for this plugin (call once at `register`). Returns a
   *  disposer that drops the plugin's bundles on unload/reload. */
  register: (bundles: PluginLocaleBundles) => () => void
  /** Module-level translator against the app's active locale (mirrors
   *  `translateNow`). Non-reactive — in React prefer `usePluginI18n`. */
  t: PluginTranslate
}

const registry = new Map<string, Map<Locale, PluginMessages>>()

/** Bumps whenever a plugin's bundles change, so React translators re-render on
 *  a registration that lands after first paint. */
const $version = atom(0)

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function mergeMessages(base: PluginMessages, overrides: PluginMessages): PluginMessages {
  const result: PluginMessages = { ...base }

  for (const [key, value] of Object.entries(overrides)) {
    const prev = result[key]
    result[key] = isRecord(prev) && isRecord(value) ? mergeMessages(prev, value) : value
  }

  return result
}

export function registerPluginLocales(pluginId: string, bundles: PluginLocaleBundles): () => void {
  const byLocale = registry.get(pluginId) ?? new Map<Locale, PluginMessages>()
  registry.set(pluginId, byLocale)

  for (const [locale, messages] of Object.entries(bundles) as [Locale, PluginMessages | undefined][]) {
    if (!messages) {
      continue
    }

    const prev = byLocale.get(locale)
    byLocale.set(locale, prev ? mergeMessages(prev, messages) : messages)
  }

  $version.set($version.get() + 1)

  return () => {
    registry.delete(pluginId)
    $version.set($version.get() + 1)
  }
}

export function translatePlugin(pluginId: string, locale: Locale, key: string, args: unknown[]): string {
  return translateFrom(l => registry.get(pluginId)?.get(l), locale, key, args)
}

/** Build the `ctx.i18n` door for a plugin. `track` records the disposer so the
 *  loader tears bundles down on unload (same lifecycle as `register`/`socket`). */
export function createPluginI18n(pluginId: string, track: (dispose: () => void) => () => void): PluginI18n {
  return {
    register: bundles => track(registerPluginLocales(pluginId, bundles)),
    t: (key, ...args) => translatePlugin(pluginId, getRuntimeI18nLocale(), key, args)
  }
}

/**
 * Reactive translator ACROSS plugins — `(pluginId, key, …args)`, for UI that
 * renders a LIST of plugins (the Plugins page, the settings search). One
 * `usePluginI18n` per row is not available to such a list: the row count
 * changes, and hooks may not be called in a loop.
 *
 * Same reactivity as `usePluginI18n` — locale switch and late registration
 * both re-key the callback.
 */
export function usePluginTranslator(): (pluginId: string, key: string, ...args: unknown[]) => string {
  const { locale } = useI18n()
  const version = useStore($version)

  return useCallback(
    (pluginId: string, key: string, ...args: unknown[]) => translatePlugin(pluginId, locale, key, args),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [locale, version]
  )
}

/**
 * A plugin's DISPLAY NAME / one-liner: its own translation when the key
 * resolves, else the English text from the manifest.
 *
 * The fallback is the ordinary case, not an error path. A disabled plugin has
 * torn its bundles down (the loader disposes them), and a plugin that ships no
 * translations never had any — both must read as their English name and never
 * as a raw dot-path or a bare id.
 */
export function resolvePluginLabel(
  translate: (pluginId: string, key: string, ...args: unknown[]) => string,
  pluginId: string,
  key: string | undefined,
  fallback: string
): string {
  if (!key) {
    return fallback
  }

  const translated = translate(pluginId, key)

  // `translateFrom` hands back the KEY when nothing resolves — that is the
  // signal, and the only one available.
  return translated === key ? fallback : translated
}

/** Reactive scoped translator for React UI. Re-renders on a locale switch or a
 *  late bundle registration. Pass your plugin id (your default export's `id`). */
export function usePluginI18n(pluginId: string): PluginTranslate {
  const { locale } = useI18n()
  const version = useStore($version)

  // `version` is the registry's change token and must key the translator's
  // identity: memoized consumers (React.memo, React Compiler output) cache
  // render slices on `t` itself, so a stable `t` over a mutated registry
  // serves stale strings after a late bundle registration.
  return useCallback(
    (key: string, ...args: unknown[]) => translatePlugin(pluginId, locale, key, args),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [pluginId, locale, version]
  )
}
