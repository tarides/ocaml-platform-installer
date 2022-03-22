# State of the Platform

> This documentation can be found online at https://v3.ocaml.org/learn/platform.

Each element of the platform lives at a different point in the lifecycle of being a Platform tool.

## Active

The work-horse tools that are used daily with strong backwards compatibility guarantees from the community.

- Opam - A source-based OCaml package manager
- Dune - A build tool that has been widely adopted in the OCaml ecosystem
- Ppxlib - A collection of useful tools for writing PPX libraries
- UTOP - OCaml's Universal Top Level
- Opam-publish - A tool for publishing packages to the opam repository
- Merlin - Context sensitive completion for OCaml in Vim and Emacs

## Incubate

New tools that fill a gap in the ecosystem but are not quite ready for wide-scale release and adoption.

- Odoc - Documentation generator for OCaml
- Mdx - Executable code blocks in your markdown
- Lsp-server - an OCaml implementation of the Language Server Protocol (LSP)
- OCamlformat - Enforcing styles on an OCaml project
- Dune-release - A CLI tool for easier packaging and publishing with opam, dune and Github
- Bun - A CLI tool making fuzz testing easier

## Sustain

Tools that will not likely see any major feature added but can be used reliably even if not being actively developed.

- Ocp-indent - An indentation tool for OCaml
- Omp - A conversion tool for major version of the OCaml parsetree
- OCamlbuild - A build tool for OCaml programs
- OCamlfind - A library manager for OCaml packages

## Deprecated

Tools that are gradually being phased out of use with clear paths to better workflows.

- Oasis - A build tool for OCaml programs
- Camlp4 - A tool for writing extensible parsers

## Proposed changes

- Remove ppxlib from the Platform
- Remove Bun from the Platform
- Promote ocaml-lsp to Active
- Promote odoc to Active
- Promote mdx to Active
- Promote ocamlformat to Active
- Promote opam-publish to Sustain
- Promote dune-release to Active
