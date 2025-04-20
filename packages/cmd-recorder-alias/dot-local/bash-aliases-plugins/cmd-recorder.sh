#!/bin/bash

cmd() {
    # Create executable bash script and edit it
    # The first argument as the path to the script file that will be created
    local NAME="${1:?'Usage: cmd <cmdname>'}"
    if [ -e "$NAME" ]; then
        echo "Command already exists: $NAME" >&2
        return 1
    fi
    echo "Creating command: $NAME"
    echo '#!/bin/bash' >> "$NAME"
    echo '' >> "$NAME"
    chmod +x "$NAME"
    vim "$NAME" -c '$'
}

