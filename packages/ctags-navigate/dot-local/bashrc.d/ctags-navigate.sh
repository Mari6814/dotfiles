export SOURCED="$BASH_SOURCE@`date +%H%m%S`:$SOURCED"

if [[ $- == *i* ]]; then
    # Resolve single-command aliases (e.g. e='vim'), but not aliases that
    # expand to a command plus arguments (e.g. evim='e ~/.vimrc').
    _ctags_navigate_resolve_alias() {
        local cmd=$1 value i

        [[ -n $cmd ]] || return

        for ((i = 0; i < 10; i++)); do
            cmd=${cmd##*/}
            value=$(alias -- "$cmd" 2>/dev/null) || break
            value=${value#*=}

            case $value in
                \'*\') value=${value:1:${#value}-2} ;;
                \"*\") value=${value:1:${#value}-2} ;;
            esac

            [[ $value != *[[:space:]]* ]] || break
            [[ -n $value && $value != "$cmd" ]] || break
            cmd=$value
        done

        printf '%s\n' "$cmd"
    }

    # Extract the command being typed before the cursor.
    _ctags_navigate_command() {
        local line=$1 segment cmd sep

        segment=$line
        for sep in ';' '|' '&'; do
            segment=${segment##*"$sep"}
        done
        segment=${segment#"${segment%%[![:space:]]*}"}

        while [[ $segment =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
            segment=${BASH_REMATCH[1]}
            segment=${segment#"${segment%%[![:space:]]*}"}
        done

        cmd=${segment%%[[:space:]]*}
        case $cmd in
            \'*\') cmd=${cmd:1:${#cmd}-2} ;;
            \"*\") cmd=${cmd:1:${#cmd}-2} ;;
        esac

        _ctags_navigate_resolve_alias "$cmd"
    }

    # Build the text to insert at the prompt.
    _ctags_navigate_text() {
        local cmd=$1 format=$2 file=$3 line=$4 name=$5 dir

        case $format in
            path)
                printf '%q' "$file"
                return
                ;;
            filename)
                printf '%q' "${file##*/}"
                return
                ;;
            dirname)
                dir=${file%/*}
                [[ $dir == "$file" ]] && dir=.
                printf '%q' "$dir"
                return
                ;;
            symbol)
                printf '%q' "$name"
                return
                ;;
        esac

        case $cmd in
            vim|nvim|vi)
                printf '+%s %q' "$line" "$file"
                ;;
            code|codium)
                printf -- '-g %q:%s' "$file" "$line"
                ;;
            cd)
                dir=${file%/*}
                [[ $dir == "$file" ]] && dir=.
                printf '%q' "$dir"
                ;;
            *)
                printf '%q:%s' "$file" "$line"
                ;;
        esac
    }

    _ctags_navigate_insert() {
        local line cmd raw format file line_no name text
        local query start

        line=${READLINE_LINE:0:READLINE_POINT}
        cmd=$(_ctags_navigate_command "$line")

        # The token immediately before the cursor is the symbol being typed:
        # use it as the initial fzf query and replace it with the selection.
        if [[ $line =~ (^|[[:space:]])([^[:space:]]*)$ ]]; then
            query=${BASH_REMATCH[2]}
            start=$(( ${#line} - ${#query} ))
        else
            query=
            start=${#line}
        fi

        # Do not treat the command itself as the symbol to replace.
        if (( start == 0 )); then
            query=
            start=${#line}
        fi

        if [[ -n $query ]]; then
            raw=$(ctags-navigate --raw -- "$query") || return
        else
            raw=$(ctags-navigate --raw) || return
        fi
        [[ -n $raw ]] || return

        IFS=$'\x1f' read -r format file line_no name <<<"$raw"
        text=$(_ctags_navigate_text "$cmd" "$format" "$file" "$line_no" "$name")
        [[ -n $text ]] || return

        READLINE_LINE="${READLINE_LINE:0:start}${text}${READLINE_LINE:READLINE_POINT}"
        READLINE_POINT=$((start + ${#text}))
    }

    bind -x '"\C-x\C-t": _ctags_navigate_insert'
fi
