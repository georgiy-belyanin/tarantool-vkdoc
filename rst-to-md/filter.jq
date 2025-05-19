#!/usr/bin/env -S jq --args -f

def convert_blocks:
  . as $input
  | try
    (.t as $type
    | .c[0][1][0] as $kind
    | {
        note: "info",
        important: "warning",
        admonition: "info",
      } as $map
    | $map[$kind] as $new_kind
    | if $type == "Div" and $new_kind then
        {
          t: "Div",
          c:[
            ["", [], [["id", $new_kind]]],
            if .c[1]?[0]?.t? == "Div" and .c[1]?[0]?.c?[0]?[1]?[0] == "title"
              then
              .c[1][1:]
            else
              .c[1]
            end
          ]
        }
      else
        .
      end)
  catch
    $input
;

# Handle :ref: macros.
walk(
  if type == "object" and .t? == "Code" and .c[0]?[2]?[0]?[1]? == "ref" and .c[1] then
    .c[1] as $link
    | ($link | split("<")) as $splits
    | ($splits[0] | gsub("\\s*$"; "")) as $ref_text
    | if ($splits | length) > 1 then
      ($splits[1] | gsub(">\\s*"; "")) as $ref_link
      | { t: "Link", c: [["", [], []], [{ t: "Str", c: $ref_text }], [$ref_link, ""]] }
    else
      { t: "Link", c: [["", [], []], [{ t: "Str", c: $ref_text }], [$ref_text, ""]] }
    end
  else
    .
  end)

# Convert code blocks to the supported ones.
#
# From:
# ```json
# {
#   "t": "CodeBlock",
#   "c": [
#     [
#       "",
#       [
#         "console"
#       ],
#       []
#     ],
#     "<code>"
#   ]
# }
# ```
#
# To:
# ```json
# {
#   "t": "CodeBlock",
#   "c": [
#     [
#       "",
#       [
#         "bash"
#       ],
#       []
#     ],
#     "<code>"
#   ]
# }
# ```
| walk(
  if type == "object" and .t? == "CodeBlock" and .c[0]?[1]?[0]? == "console" then
    .c[0][1][0] = "bash"
  else
    .
  end)

# Support note, warn and error tags.
#
# From:
# ```json
# {
#   "t": "Div",
#   "c": [
#     [
#       "",
#       [
#         <kind>
#       ],
#       []
#     ],
#     [
#       {
#         "t": "Div",
#         "c": [
#           [
#             "",
#             [
#               "title"
#             ],
#             []
#           ],
#           [
#             {
#               "t": "Para",
#               "c": [
#                 {
#                   "t": "Str",
#                   "c": "Note"
#                 }
#               ]
#             }
#           ]
#         ]
#       },
#       ...
#     ]
#   ]
# }
# ```
#
#
# To:
# ```json
# {
#   "t": "Div",
#   "c": [
#     [
#       "",
#       [
#       ],
#       [
#         {
#           "id": <kind'>
#         }
#       ]
#     ],
#     [
#       ...
#     ]
#   ]
# }
# ```

| walk(convert_blocks)

# Simplify unsupported image attributes.
#
# From:
# ```json
# {
#   "t": "Image",
#   "c": [
#     [
#       "",
#       [
#         "align-center"
#       ],
#       [
#         [
#           "width",
#           <width>
#         ]
#       ]
#     ],
#     ...
#   ]
# }
# ```
#
# To:
# ```json
# {
#   "t": "Image",
#   "c": [
#     [
#       "",
#       [
#       ],
#       [
#       ]
#     ],
#     ...
#   ]
# }
# ```

| walk(
  if type == "object" and .t? == "Image" then
    .c[0][1] = []
    | .c[0][2] = []
  else
    .
  end)


# Simplify Pandoc markdown subst kind refs.
| walk(
  if type == "object" and .t? == "Link" and
    .c?[1]?[0]?.t? == "Str" and (.c?[1]?[0]?.c? | startswith("|")) and (.c?[1]?[0]?.c? | endswith("|")) and
    (.c?[2]?[0]? | startswith("##SUBST##|")) then
    {
      t: "Str",
      c: (.c[1][0].c | gsub("\\|"; "") | ascii_upcase)
    }
  else
    .
  end)
