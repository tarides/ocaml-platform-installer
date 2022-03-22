# OCaml Platform

The OCaml Platform represents the best way for developers, both new and old, to write software in OCaml. It combines the core OCaml compiler with a coherent set of tools, documentation, libraries and testing resources.

This repository contains the OCaml Platform. The OCaml Platform bundles the projects of the Platform in a single binary and offers a unified workflow to work with the different Platform tools.

## Status

The following Platform tools are currently distributed in the OCaml Platform:

- Package manager: [`opam`](https://github.com/ocaml/opam)
- Build system: [`dune`](https://github.com/ocaml/dune)
- Documentation generator: [`odoc`](https://github.com/ocaml/odoc)
- Code formatter: [`ocamlformat`](https://github.com/ocaml/ocamlformat)
- Release helper: [`dune-release`](https://github.com/ocaml/dune-release)
- LSP server: [`ocaml-lsp`](https://github.com/ocaml/ocaml-lsp)
- REPL: [`utop`](https://github.com/ocaml/utop)
- Editor helper: [`merlin`](https://github.com/ocaml/merlin)
- Markdown code execution: [`mdx`](https://github.com/ocaml/mdx)

## Getting started

To clone the project, you can run:

```
git clone --recurse-submodules git@github.com:tarides/ocaml-platform.git 
```

You can then setup the project with:

```
make switch
```

And run ocaml-platform with:

```
dune exec ocaml-platform -- <args>
```
