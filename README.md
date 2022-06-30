# OCaml Platform Installer

> :bangbang: Disclaimer: This repository is very much a work in progress. Use at your own risk. :wrench:

The OCaml Platform represents the best way for developers, both new and old, to write software in OCaml. It combines the core OCaml compiler with a coherent set of tools, documentation, libraries and testing resources.

This repository contains an installer for the OCaml Platform tools named `ocaml-platform`.
This installer installs all the tools of the Platform in a switch and aims at offering a simplified workflow to work with the different Platform tools.

## Trying the Platform

To install the `ocaml-platform` binary, run the installer script as `root`:

```sh
sudo bash < <(curl -sL https://github.com/tarides/ocaml-platform-installer/releases/latest/download/installer.sh)
```

Don't hesitate to have a look at what the script does.
In a nutshell, the script will install a static binary into `/usr/local/bin/ocaml-platform` as well as the `opam` binary if it isn't already installed.
Currently, only Linux (both amd64 and arm64) and macOS (only amd64) are supported. macOS arm64 requires Rosetta to be installed. We plan on adding more targets soon.

Then, to install the Platform tools inside your opam switch:

```
ocaml-platform
```

If the tools aren't cached yet, this needs to build OCaml itself and the Platform tools, which takes a few minutes. To understand how `ocaml-platform` works under the hood, go directly to the [Under the hood](#whats-under-the-hood) section.

### The advantages of using `ocaml-platform`

The advantages are the following:

- The dependencies of the Platform tools, which are only needed for the development, are not mixed with the dependencies of your project.
- Installing the Platform tools is very fast if you have already installed them for the same version of OCaml in another switch.

## Status

The OCaml Platform tools are defined by the "Active" and "Incubate" projects listed [here](https://ocaml.org/docs/platform). Each element of the platform lives at a different point in the lifecycle of being a Platform tool. Some "Incubate" projects might duplicate features that are provided by "Active" projects. The aim of the platform is to limit these duplications as much as possible and to document the one blessed way to be productive in OCaml.

To be more specific, for the first iteration of the OCaml Platform we are considering the following tools (to be revisited later, when the policies for governing how projects can go in and out the platform are ready):

- Package manager: [`opam`](https://github.com/ocaml/opam)
- Build system: [`dune`](https://github.com/ocaml/dune)
- Documentation generator: [`odoc`](https://github.com/ocaml/odoc)
- Code formatter: [`ocamlformat`](https://github.com/ocaml/ocamlformat)
- Release helper: [`dune-release`](https://github.com/ocaml/dune-release)
- LSP server: [`ocaml-lsp`](https://github.com/ocaml/ocaml-lsp)
- Editor helper: [`merlin`](https://github.com/ocaml/merlin)

Note that the following is not yet distributed but is still in the Platform:

- REPL: [`utop`](https://github.com/ocaml/utop)

## Getting started

To clone the project, you can run:

```
git clone git@github.com:tarides/ocaml-platform-installer.git
```

To run the test, see the [README](https://github.com/tarides/ocaml-platform-installer/blob/main/test/README.md).

## What's under the hood

Another disclaimer: the current implementation is a WIP, so what's under the hood may (or may not) change in the future.

Under the hood, `ocaml-platform` uses several mechanisms to install and cache the platform tools.

### The sandbox switch

The sandbox switch is a switch in which the tools will be compiled. The idea of having a separate switch is that the dependencies of the development tools should not interfere with the dependencies of your project.

The platform tools are normally installed into the sandbox switch. Then, the installed files, except for the libraries, are grouped into new opam packages in the local binary repository (see below).

The libraries are left out to get rid of transitive dependencies, which would defeat the goal of not interfering with the dependencies of the project.

### The local binary opam repository

As setting up a switch and building all platform tools there is costly in time, they are cached in a local opam repository. This also allows to install the platform tools purely through `opam`.

The packages in this repository consists of pre-compiled packages with no libraries, so they don't have to be built and their installation consists only of copying files.

When the original package contains libraries, it differs from the binary package. In this case, the name of the binary package is suffixed with `+bin+platform`, and installing the original package (eg to have the library) will replace the platform one. In any case, the version of a package in the local repository contains both the original version and the ocaml version they were compiled with, as this may be important for some tools.

Note that the repository is enabled by `ocaml-platform` only when it is needed, and disabled afterward, so using `ocaml-platform` should not alter the behaviour of `opam`.

### The pipeline

When prompted to install the platform tools, for a given switch, `ocaml-platform` does the following:
- First, it finds for each tool the latest version compatible with the `ocaml` version of the switch
- Then, it checks which tools have their version already available in the local binary repo, and which tools need to be built,
- If needed, it creates the sandbox switch, to builds the tools it needs to build, and add to the local repository the new packages.
- Finally, it installs all tools from the local binary repository.

Note that this mechanism makes `opam` fully aware of `ocaml-platform`'s installed package.

## Roadmap

You can read a high-level specification for the OCaml Platform [here](./doc/spec.md).
Our current plan is to release an installer for the Platform tools in sync with OCaml 5.
