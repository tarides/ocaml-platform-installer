# OCaml Platform

> :bangbang: Disclaimer: This repository is very much a work in progress. Use at your own risk. :wrench:

The OCaml Platform represents the best way for developers, both new and old, to write software in OCaml. It combines the core OCaml compiler with a coherent set of tools, documentation, libraries and testing resources.

This repository contains the `ocaml-platform` tool. This tool allows to easily install all the projects of the Platform in a switch and aims at offering a unified workflow to work with the different Platform tools.

## Trying the platform

Just download and execute the [install script](https://github.com/tarides/ocaml-platform/releases/download/0.0.1-alpha/installer.sh) of the latest release.

The install script simply downloads and installs the suitable version of `ocaml-platform` for your system, as well as `opam` if needed.

You are then able to run `ocaml-platform`. It will install the platform tools in the current switch. Note that the first time the command is run for a given version of ocaml, installing the tools for the switch takes a few minutes.

If you are an advanced user and want to understand how `ocaml-platform` works under the hood, go directly to the [Under the hood](#whats-under-the-hood) section.

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

## What’s under the hood

Another disclaimer: the current implementation is a WIP, so what’s under the hood may (or may not) change in the future.

Under the hood, `ocaml-platform` tool uses several mechanisms to install and cache the platform tools.

### The sandbox switch

The sandbox switch is a switch in which the tools will be compiled. The idea of having a separate switch is that the dependencies of development tools should not interfere with the dependencies of your project.

When all tools have been built, every file related to the tools except for the libraries will be grouped in an opam package to be installed in the current switch.

The opam package is put in a local "binary" switch.

### The local binary switch

As setting up a switch and building all platform tools there is costly in time, they are cached in a local opam repository.

The packages in this repository consists of pre-compiled packages with no libraries, so they don’t have to be built and their installation consists only of copying files.

The packages that miss the library compared to the original package have their name suffixed with `+bin+platform` to indicate where they come from, and installing the original package (eg to have the library) will replace the platform one. Their version contains the original version as well as the ocaml version they were compiled with, as this may be important for some tools.

### The pipeline

When prompted to install the platform tools, for a given switch, `ocaml-platform` does the following:
- First, it checks which tools are already available in the local binary repo, and which needs to be built
- Then, if needed, it creates the sandbox switch, builds the tools it needs to build, and create a package in the local binary repository for each of them.
- Finally, it installs all tools from the local binary repository.

Note that this mechanism makes `ocaml-platform` fully integrated with `opam`.
