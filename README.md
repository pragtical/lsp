# (WIP) LSP Plugin for Lite XL editor

This is a work in progress LSP plugin for the __Lite XL__ code editor.
It requires the __dev__ branch of __Lite XL__ which includes the new lua
__process__ functionality in order to communicate with lsp servers.

To test, clone this project, place the __lsp__ directory in your plugins
directory, then replace the __autocomplete.lua__ plugin with the version
on this repository which should later be merged into upstream.

To add an lsp server in your user init.lua file you can see the
__serverlist.lua__ as an example or:

```lua
local lsp = require "plugins.lsp"

lsp.add_server {
  name = "intelephense",
  language = "php",
  file_patterns = {"%.php$"},
  command = {
    "intelephense",
    "--stdio"
  },
  verbose = true
}

lsp.add_server {
  name = "css-languageserver",
  language = "css",
  file_patterns = {"%.css$"},
  command = {
    "css-languageserver",
    "--stdio"
  },
  verbose = true
}

lsp.add_server {
  name = "clangd",
  language = "c/cpp",
  file_patterns = {
    "%.c$", "%.h$", "%.inl$", "%.cpp$", "%.hpp$",
    "%.cc$", "%.C$", "%.cxx$", "%.c++$", "%.hh$",
    "%.H$", "%.hxx$", "%.h++$", "%.objc$", "%.objcpp$"
  },
  command = {
    "clangd",
    "-background-index"
  },
  verbose = true
}
```

## TODO

* Exit LSP server if no open document needs it.
* Fix issues when parsing stdout from some lsp servers (eg: css-languageserver).
* Detect if lsp server hangs and restart it (eg: clangd)
* More improvements to autocomplete.lua plugin
* Add hover support for function arguments and symbols
* Generate list of current document symbols for easy document navigation
* Goto definition (Partially)
  * Display select box when more than one result

## Screenshots

![Completion](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/completion01.png)

![Completion](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/completion02.png)
