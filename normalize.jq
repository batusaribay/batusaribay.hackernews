def cleantext:
  gsub("<[^>]*>"; " ")
  | gsub("&quot;"; "\"")
  | gsub("&#0?39;"; "'")
  | gsub("&apos;"; "'")
  | gsub("&#0?8216;"; "'")
  | gsub("&#0?8217;"; "'")
  | gsub("&#0?8220;"; "\u201c")
  | gsub("&#0?8221;"; "\u201d")
  | gsub("&#0?8211;"; "-")
  | gsub("&#0?8212;"; "-")
  | gsub("&nbsp;"; " ")
  | gsub("&amp;"; "&")
  | gsub("&lt;"; "<")
  | gsub("&gt;"; ">")
  | gsub("[[:space:]]+"; " ")
  | sub("^ +"; "")
  | sub(" +$"; "");

{
  ok: true,
  stale: false,
  source: $src,
  updated: $now,
  items: (
    [
      (.feed.entry // [])[]
      | {
          title: (.title."$t" // ""),
          url: (([.link[]? | select(.rel == "alternate") | .href][0] // "")
                | sub("^http://"; "https://")),
          published: (.published."$t" // ""),
          tags: ([.category[]?.term] // []),
          summary: ((.summary."$t" // "") | cleantext)
        }
      | select(.url != "")
    ][0:$max]
  )
}
