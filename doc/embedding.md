# Integration Upstreaming

This document details the blockers and the upstream work needed to embed the Platform tools in a single binary.
The current plan for the Platform 2.0 is to gradually embed the tools in the installer so they don't have to be downloaded/installed separately, hence saving user's time and removing point of failures.

This document should be an exhausive list of what needs to be done to embed each Platform tool.

## `ocaml-lsp`

See fork here: https://github.com/tmattio/ocaml-lsp-server/tree/vendorable

Blockers:
- Forks merlin, which will conflict with the upstream version if we want to integrate it.
  - One solution would be to upstream the changes to merlin. Even if they are specific to LSP, it seems like Merlin should support LSP use cases.
  - If that's not possible, we could name it differently (and possibly move the fork to the OCaml organisation if that's a long term fork)
- Forks dune, which will conflict with the upstream version
  - Hopefully, this is only temporary, what is blocking to use the upstream dune?
- Vendors multiple dependencies used in other Platform tools
  - Unvendoring them does not seem problematic.
- Dune has a lot of non-public libraries.
  - They should be made public under the `dune-private-libs` package.
- Need a hook to replace the formatting using ocamlformat's library instead of the binary
- Need a hook to replace the dune files formatting using dune's library instead of the binary
- The changes on Dune to make it work with RPC need to be upstreamed

Upstream:
- Merge https://github.com/ocaml/ocaml-lsp/pull/632
- Merge https://github.com/ocaml/ocaml-lsp/pull/631
- Remove fork of merlin (see Merlin upstreaming plan)

## `ocamlformat`

See fork here: https://github.com/mattio/ocamlformat/tree/vendorable

Blockers:
- Some libraries are not public
  - We can create a package ocamlformat-lib to expose these (see https://github.com/patricoferris/ocamlformat/commit/b7372d58c29225eebac940dee55268fef20e4763)
- Different projects might need different versions of OCamlformat. OCamlformat versions are always breaking and known by users (written down in `.ocamlformat` files).
  - This would be solved if ocamlformat supported previous versions (0.20 supports 0.19)
- OCamlformat can work with any version of OCaml lower or equal to the version is has been built with.

Upstreaming:
- [X] https://github.com/ocaml-ppx/ocamlformat/pull/2022
- [X] https://github.com/ocaml-ppx/ocamlformat/pull/2023

## `dune-release`

Blockers:
- The opam binary dependency needs to be replaced with the opam library
- We need to add hooks to replace calls to dune with the library.

## `merlin`

See fork here: https://github.com/tmattio/merlin/tree/vendorable

Blockers:
- Needs to be updated to work with 4.14
- Merlin is only compatible with one version of OCaml at a time. It must be built once for each version of OCaml.
  - https://github.com/ocaml/merlin/pull/1431 will remove the dependency on the Typedtree.
  - We can also provide a compatibility layer for the Type AST (similarly to what Astlib does for the AST migrations).
  - With the shapes and the Type AST migrations, merlin (and ocaml-lsp) should be able to support OCaml 4.14 and up.
- The client is implemented in C.
  - We need to port it to OCaml to be able to have a merlin subcommand.
- Merlin uses `(wrapped false)` which makes some module conflict with the compiler-libs used in ocamlformat. We need to wrap the public libraries.

Upstream:
- Merge https://github.com/ocaml/merlin/pull/1286
- Rebase https://github.com/ocaml/merlin/pull/1172 on top of master once the upgrade to 4.14 is done
- Upstream https://github.com/rgrinberg/merlin/commit/9bae20bb14b3bbcf56797c08044e247de6cd6e13
- Upstream https://github.com/rgrinberg/merlin/commit/e871e3a71d6fab92b7fad2d35a240445906f070d
- Upstream https://github.com/rgrinberg/merlin/commit/c5c4e9ccac15bbb3bf17e128bc28cdf932e66ced
- Upstream https://github.com/rgrinberg/merlin/commit/c485131aa5be1720b0456ff4eef032b055c6a60c

## `dune`

See fork here: https://github.com/tmattio/dune/tree/vendorable

Blockers:
- Vendors csexp, which conflicts with csexp from Opam that we depend on (the library is removed in release mode, this is only to vendor dune)
- Vendors opam-file-format, which conflicts with opam
  - We can wrap the modules of opam-file-format in another to avoid the conflict (https://github.com/Julow/dune/commit/37bf1f4bce572494a055cec5a3a5138a560c51b2)
- Lots of libraries are not public
  - We can expose them in dune-private-libs (https://github.com/Julow/dune/commit/6d6e83558f4ba5f85dcb107acf8c6a3bc15e7157)
- The environment is initialized at startup time, we need to delay it to allow us to set the opam env variables
- We need some kind of mechanism to extend the dune rules to add new rules and aliases for `fmt` and `doc` that use the libraries instead of the binaries.
- Add new actions for ocamlformat and odoc which can be overrided (the implementation is a Fdecl, and we can provide our own implementation)

Upstream:
- Merge https://github.com/tmattio/dune/tree/expose-libs
- Upstream https://github.com/tmattio/dune/tree/current-env
- Upstream https://github.com/tmattio/dune/tree/ocamlformat-action
- Upstream https://github.com/tmattio/dune/tree/compiler-libs-compat
- Upstream https://github.com/tmattio/dune/tree/expose-encode

## `odoc`

Not explored yet.

## `utop`

See forks here:

- https://github.com/patricoferris/utop/tree/native+lazy
- https://github.com/tmattio/zed/tree/master
- https://github.com/tmattio/lambda-term/tree/master
- https://github.com/patricoferris/ocamlfind/tree/lazy

Blockers:
- The dependency on Camomille needs to be removed because it installs shared files
- Need to provide an interface that doesn't use global CLI arguments
- Make sure utop can compile to a native binary in OCaml 4.14
- ocamlfind makes assumption on the presence of the OCaml standard library.
  This needs to be made lazy so that we can run other commands without having an opam switch ready.

Upstream:
- Release https://github.com/NathanReb/compiler-libs-either-toplevel
- Merge https://github.com/ocaml-community/zed/pull/43
- Merge https://github.com/ocaml/ocamlfind/pull/39
- Upstream https://github.com/kandu/utop/tree/uu
- Upstream https://github.com/tmattio/lambda-term/tree/master
- Upstream https://github.com/patricoferris/utop/commit/c427a87bedcceffafe2faf2ebd87245f5e131ef6
- Upstream https://github.com/patricoferris/utop/commit/06b881bbcfb48bd2b2e9f061100f7ea6c6b5bf52
