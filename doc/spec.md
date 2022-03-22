# OCaml Platform: 2022 plan

Status: draft
Owner: @samoht

## Executive Summary

Tarides' main goal for the platform group is to remove possible adoption barriers for experienced developers in other languages and make them as efficient and productive in OCaml as fast as possible. Starting with the release of OCaml 5.00, We want to release a set of developer tools and documentation, dubbed the "platform", in locksteps with new compiler releases.

It's essential to remember that while Tarides and Community platform goals align very well, the target audience is slightly different. The ultimate goal is to get commercial users to adopt OCaml more widely: most pain points are similar for (experienced) commercial users than for the larger community (including students and beginners), but the journey we want to optimise is not the same. Finally, we (Tarides) really want the platform to be the community standard, to benefits from open-source leverage.

## Why do we need a platform

Tarides' plans for 2022 are focused on making Multicore OCaml a success. Our goal is to attract and retain many new users to the language by being the "first mainstream language to have effects" and showing very competitive performance results. This strategy is already working. We see a lot of interest for OCaml 5.0: today, mostly from old-timers who used OCaml decade(s) ago (during the 2005-2010 boom) and forgot about it since then, or people who already heard about OCaml but never had the opportunity nor sufficient reasons to try it.

**We need to get proactively ready to welcome this influx of users.** Unfortunately, today, being productive in OCaml is a long and complicated task for anyone not profoundly familiar with the existing tooling. We have seen this first-hand whilst participating in Outreachy internships, interacting on OCaml Discuss posts and analysing the results of the OCaml survey. These interactions highlighted a few issues, detailed below.

#### Developers do not know what tools to use to be productive in OCaml

It is not obvious for new users what the ideal project setup is and how to make it compatible with platform tools:
- What tools should be installed?
- How do these tools interact?
- What commands to run for a specific task?

The fragmentation of the OCaml Platform in at least ten different tools is a barrier for new users. Thus, a simple task (like adding a new dependency to a project) might involve multiple steps and tools, introducing new potential points of failure and adding extra work for the user.

#### The installation of the OCaml Platform is not unified

Of all the OCaml Platform tools, Opam is a special case. Developers can install it from pre-compiled binaries, and the rest of the tools depend on Opam to be present. Hence, this splits the initial setup into two parts: Opam installation and the other tools installation. Then, some tools need to be installed in the current switch (`dune`, `utop`), while others can be global.

#### The installation of the Platform tools is not the same on all platforms

For instance: Opam is not installable on Windows (without Cygwin that is), hence the setup of OCaml Platform is not the same depending on the platform.

#### Some tools depend on the project or environment

For instance: Ocamlformat's version depends on the user's project version. That dependency causes users to have multiple `ocamlformat` installed, typically, one per opam switch.

Another example: `Ocamllsp` depends on `merlin`, which will depend on the OCaml compiler version. That dependency to the OCaml compiler will cause users to have multiple versions of `merlin` and `ocamllsp` installed, typically, one per opam switch.

#### Some tools can conflict with the project dependencies

Developers can only install the tools from Opam for now. They also have a lot of dependencies. These dependencies cause the tools to conflict with users' projects in some cases, and some of the tools conflict with each other (e.g. some versions of `ocamlformat` and `mdx` are not compatible)

#### The Platform installation is too long

Between the installation of Opam, the compilation of the compiler, the installation and compilation of all of the tools, the setup can take 15 minutes. This duration is not acceptable in the context of VSCode, for instance, where we want to install everything for the user. 

Creating new projects with a local sandbox (local opam switch) takes 2 to 5 minutes.

#### Workflows

Here we list some common painful developer workflows.

##### Installing OCaml (Linux)

```
add-apt-repository ppa:avsm/ppa
apt update
apt install opam
opam init -a
eval `opam env`
opam switch create 4.13.1
opam install dune utop ocaml-lsp-server ocamlformat ocamlformat-rpc dune-release mdx
```


##### Installing OCaml (macOS)

```
brew install opam
opam init -a
eval `opam env`
opam switch create 4.13.1
opam install dune utop ocaml-lsp-server ocamlformat ocamlformat-rpc dune-release mdx
```

##### Installing OCaml (Windows)

- Download and run https://github.com/fdopen/opam-repository-mingw/releases/download/0.0.0.2/OCaml64.exe
- And then:
  ```
  opam init -a
  eval `opam env`
  opam switch create 4.13.1
  opam install dune utop ocaml-lsp-server ocamlformat ocamlformat-rpc dune-release mdx
  ```

##### Start a new project

```
# install OCaml
dune init project hello my-project
cd hello
dune exec bin/main.exe
```

##### Start hacking on an existing project

```
# install OCaml
# clone the project and cd into it
opam switch create . --empty
# check the project VERSION (for instance by looking in CHANGES.md)
opam install --deps-only --with-test --with-doc --with-version VERSION .
```

##### Adding dependencies to an existing project

- If dune-project uses `(generate_opam_file true)`
    - Add the library dependency in the `dune` file
    - Add the opam dependency in `dune-project`
    - Call `opam install <pkg>` to use a released version of that package
    - Or call `opam pin add <pkg> --dev` to use a development version of that package
- If dune-project DOES NOT use `(generate_opam_file true)`
    - Add the library dependency in the `dune` file
    - Add the opam dependency in `*.opam`
    - Call `opam install <pkg>` to use a released version of that package
    - Or call `opam pin add <pkg> --dev` to use a development version of that package

##### Setting up VSCode

- Install "VSCode OCaml Platform"
- Create a switch
- Install `ocaml-lsp-server`, `ocamlformat`, `utop`, `ocamlformat-rpc`

##### Testing Multicore OCaml

```
# install OCaml
opam switch 5.0.0+trunk # can take a long time if you use a local switch
dune build
```
TODO: is this enough? do we have to add an opam overlay?

##### Formatting the codebase

Need to not forget the `--auto-promote` arg:
```
dune build @fmt --auto-promote
```

## What is the platform

The OCaml platform is a set of developer documentation, workflows and tools that is the recommended way to develop OCaml code. The full list is available here: https://ocaml.org/platform/

### OCaml Platform 1.0

#### Scope

Be the community-recommended tools for developing, building, documenting, testing and publishing OCaml code.

#### Goals

- **Define** the recommended tools to be using to be productive in OCaml. *Desired output: a clear document on ocaml.org explaining what are these tools, how new tools can become part of the platform and who decide this.*
- **Unify** installation of platform tools. *Desired output: a single binary for all the supported platforms is available on ocaml.org.*
- **Document** the recommended workflow using the new tools, and escape hatches for advanced users. *Desired output: a specification of the existing workflows, using the current platform tools.*
- **Release** regularly in sync with the OCaml compiler, starting with 5.00. *Desired output: regular releases of the OCaml Platform, in sync with the compiler releases.*
- **Migrate** existing workflows like ocamldoc plugins, ocamlbuild rules, remaining camlp4 extensions, cross-compilation hacks. *Desired output: the community converges to a well-defined, well-maintained, blessed set of tools.*
- **Deprecate** the older tools (ocamlbuild, ocamldoc, camlp4, opam1) to reduce our long-term support envelope. *Desired output: reduce maintenace cost and focalise effort on new tools.*


#### Requirements

- The components of the OCaml Platform are clearly defined on ocaml.org.
- The workflows that the OCaml Platform enabled are well documented on ocaml.org.
- The components of the OCaml Platform have stable releases on all the supported platforms (including Windows) and established sustainable community maintainership (license, individuals, organisations).
- The OCaml Platform is distributed as single CLI installer working on all the the supported platform:
    - The installation should be fast, in a single step and all the latest versions of the platform tools should be usable at the same time.
    - The installation should be independent of the users' projets or environment.
- The OCaml Platform is available as a one-click installation step for VSCode.
- The OCaml Platform distribution has a clear upgrade/update story.
- Once the OCaml Platform is installed, the creation of new projects with local sandboxes should be fast and straightforward.
- The release of the OCaml Platform should be coordinated with OCaml release-readiness team regarding release preparation.

#### Metrics

**TODO: define more metrics**

- how long does it take to start contributing to an OCaml project from scratch?
- how liong does it take to try out OCaml 5.0?
- how many of the projects Tarides develop are Stable Platform projects?
- how many opam projects are still using old tools or no tools?
  - how many have switched over themselves
  - how many have switched over with help from us
- release:
  - how automated is the release
  - how close to 5.00-rc did the platform release arrive.

#### Risks

- unable to migrate users to new tools
  - do our build, test and doc in particular cover all bases for major users?
  - are new tools fit for purpose?
- does odoc have sufficient feature coverage
- b0/dune split
- difficulty to keep the workflow up-to-date on ocaml.org with the release of new tools
- ocaml development team does not leave enough time between rc/release
- unable to edit ocaml.org

#### Support Enveloppe

See the [supported platforms](https://hackmd.io/VcoUSFMYSiiO50Bo0ksQww).

#### Release Timeline

Release Manager: @samoht
- Beta: TODO
- Release: Q2 2022 in sync with OCaml 5.0.0

## How do we do this

- Create CI that outputs binaries of the Platform tools, triggered by the Platform tools releases
- Integrate end-to-end tests in the CI
- Create an installer that can install the Platform binaries on the user's system
- Document governance of the Platform
- Document RFC process to be promoted/demoted
- Document developer workflows supported by the Platform (first draft at https://v3.ocaml.org/learn/best-practices)
- Update the state of the Platform according to [`state.md`](state.md)
