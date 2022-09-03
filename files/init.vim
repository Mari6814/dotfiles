source ~/.vimrc

lua <<EOF
  -- Setup nvim-cmp.
  local cmp = require'cmp'

  cmp.setup({
    sources = {
        { name = 'nvim_lsp' },
        { name = 'buffer' },
    },

    mapping = cmp.mapping.preset.insert({
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.close(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
    }),
  })

  require'lspconfig'.pyright.setup{}
  require'lspconfig'.rust_analyzer.setup{}
  require'lspconfig'.tsserver.setup{}
EOF
