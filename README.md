# OCaml Platform

> :bangbang: Disclaimer: This repository is very much a work in progress. Use at your own risk. :wrench:

The OCaml Platform represents the best way for developers, both new and old, to write software in OCaml. It combines the core OCaml compiler with a coherent set of tools, documentation, libraries and testing resources.

This repository contains the `ocaml-platform` tool. This tool allows to easily install all the projects of the Platform in a switch and aims at offering a unified workflow to work with the different Platform tools.

## Trying the platform

Just download and execute the [install script](https://github.com/tarides/ocaml-platform/releases/download/0.0.1-alpha/installer.sh) of the latest release.

The install script simply downloads and installs the suitable version of `ocaml-platform` for your system, as well as `opam` if needed.

You are then able to run `ocaml-platform`. It will install the platform tools in the current switch. Note that the first time the command is run for a given version of ocaml, installing the tools for the switch takes a few minutes.

### The advantages of using `ocaml-platform`

The advantages are the following:

- The dependencies of the platform tools, which are only needed for the development, are not mixed with the dependencies of your project.
- Installing the platform tools is very fast if you have already installed them for the same version of OCaml in another switch.

## Status

The following Platform tools are currently distributed in the OCaml Platform:

- Package manager: [`opam`](https://github.com/ocaml/opam)
- Build system: [`dune`](https://github.com/ocaml/dune)
- Documentation generator: [`odoc`](https://github.com/ocaml/odoc)
- Code formatter: [`ocamlformat`](https://github.com/ocaml/ocamlformat)
- Release helper: [`dune-release`](https://github.com/ocaml/dune-release)
- LSP server: [`ocaml-lsp`](https://github.com/ocaml/ocaml-lsp)
- Editor helper: [`merlin`](https://github.com/ocaml/merlin)

Note that the following is not yet distributed but is still in the platform:

- REPL: [`utop`](https://github.com/ocaml/utop)

## Getting started

To clone the project, you can run:

```
git clone git@github.com:tarides/ocaml-platform.git
```

To run the test, see the [README](https://github.com/tarides/ocaml-platform/blob/main/test/README.md).
