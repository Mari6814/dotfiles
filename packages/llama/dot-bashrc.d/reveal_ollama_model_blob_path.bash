# Resolve an Ollama model name/tag to the model blob path.
# Usage:
#   ollama_model_blob <name>[:<tag>]   # print blob path for a model
#   ollama_model_blob list             # list all models with their blob paths
#   ollama_model_blob --help           # show this help
ollama_model_blob() {
    local BASE="${OLLAMA_MODELS:-/usr/share/ollama/.ollama/models}"

    _omb_help() {
        cat <<'EOF'
ollama_model_blob - resolve Ollama models to their blob paths

USAGE
  ollama_model_blob <name>[:<tag>]   Print the model blob path for a model.
  ollama_model_blob list             List all models and their blob paths.
  ollama_model_blob --help           Show this help.

ARGUMENTS
  <name>[:<tag>]   Model name with optional tag (default tag: latest).
                   Namespaced names like "user/repo" are supported.
  list             Walk manifests under the Ollama store and print
                   "<name>:<tag> <blob-path>" for each model.

ENVIRONMENT
  OLLAMA_MODELS    Override the model store root.
                   Default: /usr/share/ollama/.ollama/models
                   (rootless installs often use ~/.ollama/models)

EXAMPLES
  # Print the blob path for a model
  ollama_model_blob qwen3:0.6b

  # Use it directly with llama.cpp's CLI
  MODEL=$(ollama_model_blob qwen3:0.6b) llama-cli -m "$MODEL"

  # List every model with its blob
  ollama_model_blob list

  # Show sizes of all model blobs
  ollama_model_blob list | awk '{print $2}' | xargs -r ls -lh

NOTES
  Blobs are stored by content digest (sha256-<hex>); the only mapping
  from a human name to a blob is the manifest JSON, which this reads.
  The model layer is the one whose mediaType contains "model".
EOF
    }

    _omb_manifest_to_blob() {
        # $1 = manifest file path; prints blob path or fails
        local manifest="$1" hash blob
        hash="$(jq -r '.layers[] | select(.mediaType | contains("model")) | .digest' "$manifest" 2>/dev/null | head -1)"
        [[ -z "$hash" || "$hash" == "null" ]] && return 1
        blob="$BASE/blobs/${hash/:/-}"
        [[ -f "$blob" ]] || return 1
        printf '%s\n' "$blob"
    }

    # no argument -> print help (usage error, exit non-zero)
    if [[ $# -eq 0 ]]; then
        _omb_help >&2
        return 2
    fi

    case "$1" in
        -h|--help|help)
            _omb_help
            return 0
            ;;
    esac

    if [[ "$1" == "list" ]]; then
        local mdir="$BASE/manifests/registry.ollama.ai"
        if [[ ! -d "$mdir" ]]; then
            echo "ollama_model_blob: no manifests dir: $mdir" >&2
            return 1
        fi
        local manifest rel name tag blob
        while IFS= read -r -d '' manifest; do
            rel="${manifest#"$mdir"/}"
            tag="${rel##*/}"
            name="${rel%/*}"
            name="${name#library/}"
            if blob="$(_omb_manifest_to_blob "$manifest")"; then
                printf '%-40s %s\n' "${name}:${tag}" "$blob"
            else
                printf '%-40s %s\n' "${name}:${tag}" "(no model blob)"
            fi
        done < <(find "$mdir" -type f -print0 | sort -z)
        return 0
    fi

    local spec="$1"
    local name tag manifest hash blob

    if [[ "$spec" == *:* ]]; then
        name="${spec%%:*}"
        tag="${spec##*:}"
    else
        name="$spec"
        tag="latest"
    fi

    local reg_path="registry.ollama.ai/library/${name}"
    [[ "$name" == */* ]] && reg_path="registry.ollama.ai/${name}"

    manifest="$BASE/manifests/${reg_path}/${tag}"

    if [[ ! -f "$manifest" ]]; then
        echo "ollama_model_blob: manifest not found: $manifest" >&2
        local dir; dir="$(dirname "$manifest")"
        [[ -d "$dir" ]] && { echo "available tags for $name:" >&2; ls -1 "$dir" >&2; }
        return 1
    fi

    hash="$(jq -r '.layers[] | select(.mediaType | contains("model")) | .digest' "$manifest" | head -1)"
    if [[ -z "$hash" || "$hash" == "null" ]]; then
        echo "ollama_model_blob: no model layer in $manifest" >&2
        return 1
    fi

    blob="$BASE/blobs/${hash/:/-}"
    if [[ ! -f "$blob" ]]; then
        echo "ollama_model_blob: blob missing: $blob" >&2
        return 1
    fi

    printf '%s\n' "$blob"
}
