tmux pane-completion samples

Reload once:
  source ~/.local/bashrc.d/tmux-autocomplete-from-pane.sh

How to test:
  1. cat one of these files so the output is visible above the prompt
  2. type the query at the prompt (do NOT press Enter)
  3. press Ctrl-G

Only lines visible above the prompt are captured. If output scrolls off,
cat the file again (or use tail). Long lines wrap and are joined.

------------------------------------------------------------------------
Chaotic / realistic transcripts

01-deploy.log
  Registry/CI logs: image refs, timestamps, assignment RHS, URLs,
  host:port, hashes, rollback filenames. Try:
    echo registry.example.com:5000   -> full image ref (colon-heavy run)
    echo postgres://payments         -> DATABASE_URL value
    echo vault.internal:8200         -> URL and host:port candidates
    echo 10.0.14.23:8443             -> host:port from the error
    echo sha256:                     -> full digest
    echo payments-api-7d9f8c6b5      -> rollback filename component
    echo ip-10-0-14-23               -> node name

02-http-trace.txt
  curl -v plus a JSON API response. Try:
    echo eyJhbGci                   -> the bearer JWT
    echo ord_01HZ                   -> JSON id(s)
    echo x-request-id               -> header/key token
    echo 8f14e45f                   -> request UUID
    echo hooks.example.com          -> URL / path component
    echo credentials.json           -> path component
    echo s3cr3t-with-dash_and.dot   -> secret value token

03-build-and-test.txt
  npm/vite/pytest/docker output. Try:
    echo production                 -> RHS of --mode= / NODE_ENV=
    echo D8f3kL2m                   -> hashed asset filename
    echo test_checkout              -> test name
    echo X-Request-Id               -> token from the KeyError
    echo 2.14.0-rc.1                -> image tag
    echo NODE_ENV                   -> normal token next to the assignment

04-shell-commands.txt
  A messy shell session: export/ssh/tar/grep/mysql/jq. Try:
    echo SOME:                      -> SOME:TOKEN from APP_KEY=
    echo "Zx9!                      -> quoted password (opening double quote)
    echo Zx9!                       -> quoted password without starting a quote
    echo bastion.prod               -> ssh/scp remote
    echo redis-0                    -> docker ps row
    echo prod.env                   -> grep path component
    echo users?status               -> URL with query string
    echo '.items                     -> whole jq expression (inside quote)
    echo --exclude-dir              -> flag token

05-git-and-k8s.txt
  git log/diff plus kubectl tables and JSON. Try:
    echo origin/main                -> path/component
    echo 8f14e45                    -> commit hash
    echo src/api/orders             -> path components
    echo api-7d9f8c6b5              -> pod name
    echo 10.0.14.23                 -> pod IP
    echo 127.0.0.1:8443             -> host:port
    echo ip-10-0-14-23              -> node name
    echo "commit                     -> quoted JSON key (opening quote)

06-secrets-and-escapes.txt
  kubectl/vault/heredoc/sed/docker with nested quoting. Try:
    echo APP_KEY=                   -> RHS of --from-literal=
    echo SIGNING_KEY                -> quoted JSON key / normal key
    echo SGVsbG8                    -> base64 secret
    echo ProxyJump                  -> token next to the quoted value
    echo request_id                 -> quoted sed/JSON key
    echo 8f14e45f                   -> UUID
    echo REDIS_URL                  -> quoted env assignment
    echo cache.internal:6379        -> host:port / URL component
    echo Zx9!                       -> quoted DB_PASSWORD

07-colored-output.log
  Real ANSI colors; capture-pane strips them before tokenizing. Try:
    echo registry.example.com:5000  -> image ref
    echo 10.0.14.23:8443            -> host:port
    echo SGVsbG8                    -> base64 token
    echo healthz                    -> URL

------------------------------------------------------------------------
clean/ - rule-by-rule files (no noise)

  clean/paths.txt             path raw/trimmed/components
  clean/assignments.txt       APP_KEY=, --flag=, DATABASE_URL=
  clean/quotes.txt            quoted strings, spaces, escaped quotes
  clean/long-and-remote.txt   base64, JWT, digest, scp, URL, host:port
  clean/vars-and-short.txt    ${VAR}, $VAR, short-token filtering
