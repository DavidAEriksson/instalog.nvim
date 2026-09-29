return {
  typescript = {
    log_statement = 'console.log',
    block_types = { 'program', 'statement_block', 'class_body' },
    container_types = {
      'function_declaration',
      'method_definition',
      'arrow_function',
      'function_expression',
      'if_statement',
      'for_statement',
      'for_in_statement',
      'while_statement',
    },
  },
  javascript = {
    log_statement = 'console.log',
    block_types = { 'program', 'statement_block', 'class_body' },
    container_types = {
      'function_declaration',
      'method_definition',
      'arrow_function',
      'function_expression',
      'if_statement',
      'for_statement',
      'for_in_statement',
      'while_statement',
    },
  },
  lua = {
    log_statement = 'print',
    block_types = { 'chunk', 'block' },
    container_types = { 'function_declaration', 'local_function' },
  },
  go = {
    log_statement = 'fmt.Println',
    block_types = { 'source_file', 'block' },
    container_types = { 'function_declaration', 'method_declaration', 'for_statement' },
  },
  python = {
    log_statement = 'print',
    block_types = { 'module', 'block' },
    container_types = {
      'function_definition',
      'if_statement',
      'for_statement',
      'while_statement',
      'class_definition',
    },
  },
}
