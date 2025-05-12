#!/usr/bin/env -S jq --args -f

# Handle :ref: macros.
walk(
  if type == "object" and .t == "Code" and .c[0] and .c[0] and .c[0][2] and .c[0][2][0] and .c[0][2][0][1] == "ref" and .c[1] then
    .c[1] as $link
    | ($link | split("<")) as $splits
    | ($splits[0] | gsub("\\s*$"; "")) as $ref_text
    | ($splits[1] | gsub(">\\s*"; "")) as $ref_link
    | { t: "Link", c: [["", [], []], [{ t: "Str", c: $ref_text }], [$ref_link, ""]] }
  else
    .
  end)

