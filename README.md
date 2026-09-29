<div align="center">
  <h1 align="center">Instalog.nvim</h1>
  <h6>WIP: Instantaneous context aware logging</h6>

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/ellisonleao/nvim-plugin-template/default.yml?branch=main&style=for-the-badge)

</div>

## Requirements

Neovim 0.10+. `vim.treesitter.get_node()` needs to return `nil` for a
buffer with no available parser rather than throwing — relied on to
gracefully warn instead of crash. Install the parser for a language
before using it: `:TSInstall typescript javascript lua go python`
(requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)).

## Usage

Call `:InstalogInsert` with the cursor on an identifier to insert a
context-aware log statement at the nearest syntactically valid position:

```lua
require('instalog').setup({})
```

```ts
const value = "hello"
//     ^ cursor here, run :InstalogInsert
console.log("~/dir/test.ts (Line 2): ", value)
```

## Supported languages

Out of the box: `typescript`, `javascript`, `lua`, `go`, `python`.

## Configuration

```lua
require('instalog').setup({
  format = '%file (Line %line): ',  -- global default; %file, %line, %var
  print_definitions = {
    go = {
      log_statement = 'fmt.Println',
      format = '%file:%line ',       -- optional per-language override
      block_types = { 'source_file', 'block' },
      container_types = { 'function_declaration', 'method_declaration', 'for_statement' },
    },
  },
})
```

To add or extend a language, add an entry under `print_definitions` with:
- `log_statement` — the function to call (e.g. `console.log`, `fmt.Println`).
- `block_types` — Tree-sitter node types whose children form a statement sequence.
- `container_types` — Tree-sitter node types with a body (functions, loops, etc.) where the cursor may be in a header/signature.

Use `:InspectTree` (built into Neovim) on a sample buffer to find the exact node type names for your language.
