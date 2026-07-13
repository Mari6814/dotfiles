# Odin language: ODIN_ROOT + bash completion
# Auto-sourced by ~/.bashrc via the ~/.local/bash-plugins/*.sh loader.
#
# To use, define:
#   ODIN_ROOT
#
# In the your bashrc

_odin_complete() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    }

    local commands="build run bundle check strip-semicolon test doc version report root"

    # Flags shared by the compile-style subcommands.
    local build_flags="-file -out: -o: -debug -build-mode: -target: -subtarget: \
-microarch: -define: -collection: -vet -vet-cast -vet-packages -vet-semicolon \
-vet-shadowing -vet-style -vet-tabs -vet-unused -vet-unused-imports \
-vet-unused-procedures -vet-unused-variables -vet-using-param -vet-using-stmt \
-strict-style -disable-assert -no-bounds-check -no-crt -no-entry-point -lto \
-linker: -sanitize: -reloc-mode: -show-timings -show-more-timings -keep-temp-files \
-keep-executable -warnings-as-errors -json-errors -terse-errors -thread-count: \
-max-error-count: -use-separate-modules -use-single-module -ignore-warnings \
-extra-linker-flags: -extra-assembler-flags: -print-linker-flags -help"

    # First word: complete the subcommand.
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    local subcmd="${COMP_WORDS[1]}"
    case "$subcmd" in
        build|run|check|test|doc|strip-semicolon|bundle)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$build_flags" -- "$cur") )
                compopt -o nospace 2>/dev/null
            else
                # Package directory or, with -file, a single .odin file.
                COMPREPLY=( $(compgen -d -- "$cur") $(compgen -f -X '!*.odin' -- "$cur") )
            fi
            ;;
        version|report|root)
            ;;
        *)
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            ;;
    esac
    return 0
}

complete -F _odin_complete odin
