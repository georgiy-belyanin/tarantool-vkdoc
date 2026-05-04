#!/usr/bin/env -S jq --args -f

.blocks = [first(.blocks[] | select(.t == "Header" and .c[0] == 1)) | .t = "Para" | .c = .c[2]]

