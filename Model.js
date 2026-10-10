.pragma library

const MARK = String.fromCodePoint(0xF1004)

const MAX_TITLE = 300
const MAX_SUMMARY = 1000
const MAX_TAGS = 4

function parsePayload(raw) {
  var text = String(raw || "").trim()
  if (!text)
    return { ok: false, stale: true, source: "The Hacker News", updated: "", error: "empty", items: [] }
  try {
    var data = JSON.parse(text)
    return {
      ok: data.ok === true,
      stale: data.stale === true,
      source: sanitizeText(data.source || "The Hacker News", 64),
      updated: sanitizeText(data.updated || "", 40),
      error: sanitizeText(data.error || "", 80),
      items: sanitizeItems(data.items)
    }
  } catch (e) {
    return { ok: false, stale: true, source: "The Hacker News", updated: "", error: "parse", items: [] }
  }
}

function sanitizeItems(list) {
  var out = []
  if (!Array.isArray(list))
    return out
  for (var i = 0; i < list.length; i++) {
    var it = list[i]
    if (!it)
      continue
    var url = sanitizeUrl(it.url)
    if (!url)
      continue
    out.push({
      title: sanitizeText(it.title, MAX_TITLE) || "(untitled)",
      url: url,
      published: sanitizeText(it.published, 40),
      relTime: relTime(it.published),
      tags: sanitizeTags(it.tags),
      summary: sanitizeText(it.summary, MAX_SUMMARY)
    })
  }
  return out
}

function sanitizeUrl(value) {
  var s = String(value || "").trim()
  if (!/^https?:\/\/[^\s]+$/i.test(s))
    return ""
  return s.slice(0, 2048)
}

function sanitizeText(value, max) {
  var t = String(value === undefined || value === null ? "" : value)
  t = t.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g, "")
  t = t.replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "")
  return t.length > max ? t.slice(0, max) : t
}

function sanitizeTags(tags) {
  var out = []
  if (!Array.isArray(tags))
    return out
  for (var i = 0; i < tags.length && out.length < MAX_TAGS; i++) {
    var t = sanitizeText(tags[i], 24)
    if (t && out.indexOf(t) === -1)
      out.push(t)
  }
  return out
}

function relTime(iso) {
  var t = Date.parse(iso)
  if (isNaN(t))
    return ""
  var s = Math.max(0, Math.floor((Date.now() - t) / 1000))
  if (s < 60)
    return "just now"
  var m = Math.floor(s / 60)
  if (m < 60)
    return m + "m ago"
  var h = Math.floor(m / 60)
  if (h < 24)
    return h + "h ago"
  var d = Math.floor(h / 24)
  if (d < 7)
    return d + "d ago"
  return Math.floor(d / 7) + "w ago"
}

function buildPrompt(item) {
  var lines = [
    "Read this cybersecurity story and explain it to me in plain language: what happened, why it matters, and who is affected.",
    "",
    sanitizeText(item.title, MAX_TITLE),
    sanitizeUrl(item.url)
  ]
  if (item.summary)
    lines.push("", item.summary)
  return lines.join("\n")
}

function metaLine(item) {
  var parts = []
  if (item.relTime)
    parts.push(item.relTime)
  for (var i = 0; i < item.tags.length; i++)
    parts.push(item.tags[i])
  return parts.join("  ·  ")
}
