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

    # Actions offered for the command currently being edited.
    _ctags_navigate_actions() {
        local cmd=$1

        case $cmd in
            cd)
                printf '%s' 'enter=dirname'
                ;;
            vim|nvim|vi)
                printf '%s' 'enter=location-vim,alt-p=path,alt-d=dirname'
                ;;
            code|codium)
                printf '%s' 'enter=location-code,alt-p=path,alt-d=dirname'
                ;;
            *)
                printf '%s' 'enter=location-generic,alt-p=path,alt-f=filename,alt-d=dirname,alt-s=symbol'
                ;;
        esac
    }

    # Build the text to insert at the prompt.
    _ctags_navigate_text() {
        local action=$1 file=$2 line=$3 name=$4 dir

        case $action in
            location-vim)
                printf '+%s %q' "$line" "$file"
                ;;
            location-code)
                printf -- '-g %q:%s' "$file" "$line"
                ;;
            location-generic)
                printf '%q:%s' "$file" "$line"
                ;;
            path)
                printf '%q' "$file"
                ;;
            filename)
                printf '%q' "${file##*/}"
                ;;
            dirname)
                dir=${file%/*}
                [[ $dir == "$file" ]] && dir=.
                printf '%q' "$dir"
                ;;
            symbol)
                printf '%q' "$name"
                ;;
            *)
                return 1
                ;;
        esac
    }

    # True when the invocation has no options and can change the shell's cwd.
    _ctags_navigate_bare() {
        local arg seen_end=0

        for arg in "$@"; do
            (( seen_end )) && continue
            case $arg in
                --) seen_end=1 ;;
                -*) return 1 ;;
            esac
        done
    }

    # Direct invocation: cd to the search root; Alt-o opens the selection.
    # A child process cannot change the parent shell's directory, so this has
    # to be a shell function. Internal calls use `command ctags-navigate`.
    ctags-navigate() {
        local -a query_args=()
        local -a editor=()
        local arg raw action file line_no name root seen_end=0

        if ! _ctags_navigate_bare "$@"; then
            command ctags-navigate "$@"
            return
        fi

        for arg in "$@"; do
            if (( seen_end )); then
                query_args+=("$arg")
                continue
            fi
            case $arg in
                --) seen_end=1 ;;
                *) query_args+=("$arg") ;;
            esac
        done

        raw=$(command ctags-navigate --raw --absolute \
            --actions 'enter=cd-root,alt-o=open-editor' -- "${query_args[@]}") || return
        [[ -n $raw ]] || return

        IFS=$'\x1f' read -r action file line_no name root <<<"$raw"
        [[ -n $root ]] || return

        cd -- "$root" || return

        if [[ $action == open-editor ]]; then
            read -r -a editor <<<"${EDITOR:-vi}"
            "${editor[@]}" "+$line_no" "$file"
        fi
    }

    _ctags_navigate_insert() {
        local line cmd raw action file line_no name root text
        local query start actions

        line=${READLINE_LINE:0:READLINE_POINT}
        cmd=$(_ctags_navigate_command "$line")
        actions=$(_ctags_navigate_actions "$cmd")

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
            raw=$(command ctags-navigate --raw --actions "$actions" -- "$query") || return
        else
            raw=$(command ctags-navigate --raw --actions "$actions") || return
        fi
        [[ -n $raw ]] || return

        IFS=$'\x1f' read -r action file line_no name root <<<"$raw"
        text=$(_ctags_navigate_text "$action" "$file" "$line_no" "$name") || return
        [[ -n $text ]] || return

        READLINE_LINE="${READLINE_LINE:0:start}${text}${READLINE_LINE:READLINE_POINT}"
        READLINE_POINT=$((start + ${#text}))
    }

    bind -x '"\C-x\C-t": _ctags_navigate_insert'
fi
