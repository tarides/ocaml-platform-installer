# OCaml Platform: 2022 plan

Status: Stable (version 1.0)
Owner: @samoht
Lead maintainers: @tmattio

## Executive Summary

Tarides' main goal for the platform group is to remove possible adoption barriers for experienced developers in other languages and make them as efficient and productive in OCaml as fast as possible. Starting with the release of OCaml 5.0, We want to release a set of developer tools and documentation, dubbed the "OCaml 5.0 Platform", in lockstep with new compiler releases. **Tarides is initially leading the platform project but the goal is to align and involve the OCaml community to turn it into a community-led project.**

It's essential to remember that while Tarides and Community platform goals align very well, the target audience is slightly different (at least initially). The ultimate goal is to get commercial users to adopt OCaml more widely: most pain points are similar for (experienced) commercial users than for the larger community (including students and beginners), but the journey we want to optimize is not the same. 

## Why do we need a platform

Tarides' plans for 2022 are focused on making OCaml 5 a success. Our goal is to attract and retain many new users to the language by being the "first mainstream language to have effects" and showing very competitive performance results. This strategy is already working. We see a lot of interest for OCaml 5: today, mostly from old-timers who used OCaml decades ago (during the 2005-2010 boom) and forgot about it since then, or people who already heard about OCaml but never had the opportunity or sufficient reasons to try it.

**We need to be proactive to welcome this influx of users.** Unfortunately, today, being productive in OCaml is a long and complicated task for anyone not profoundly familiar with the existing tooling. We have seen this first-hand whilst participating in Outreachy internships, interacting on OCaml Discuss posts and analyzing the results of the OCaml survey. These interactions highlighted a few issues, detailed below.

Below are some common pain points we identified with users using the Platform.

#### Developers do not know what tools to use to be productive in OCaml

It is not obvious to new users what the ideal project setup is and how to make it compatible with Platform tools:
- What tools should be installed?
- How do these tools interact?
- What commands to run for a specific task?

The fragmentation of the OCaml Platform in at least ten different tools is a barrier for new users. Thus, a simple task (like adding a new dependency to a project) might involve multiple steps and tools, introducing new potential points of failure and adding extra work for the user.

#### The installation of the developer tools is not unified

Of all the developer tools, opam is a special case. Developers can install it from pre-compiled binaries, and the rest of the tools depend on opam to be present. Hence, this splits the initial setup into two parts: opam installation and the other tools installation.

Some tools also depend on others (like `ocaml-lsp-server`) depends on `ocamlformat` and `ocamlformat-rpc`, and users only learn about it once they have installed `ocaml-lsp-server` and get an error from it asking users to install the missing dependencies.

#### The installation of Platform tools is not the same on all platforms

For instance: opam is not installable on Windows (without Cygwin that is), hence the setup of the OCaml Platform is not the same depending on the platform.

#### Some tools depend on the project or environment

For instance: OCamlFormat's version depends on the user's project version. That dependency causes users to have multiple `ocamlformat` installed, typically, one per opam switch.

Another example: OCaml-LSP depends on Merlin, which will depend on the OCaml compiler version. That dependency on the OCaml compiler will cause users to have multiple versions of Merlin and OCaml-LSP installed, typically, one per opam switch.

As it's not realistic for these tools to keep compatibility with multiple versions of OCaml, this also means that users who have to use an older version of OCaml won't benefit from the new features and bug fixes for these tools.

#### Some tools can conflict with the project dependencies

At present, developers can only easily install the tools from opam. They also have a lot of dependencies. These dependencies cause the tools to conflict with users' projects in some cases, and some of the tools conflict with each other (e.g. some versions of `ocamlformat` and `mdx` are not compatible)

Some users work around this limitation by creating global switches and manually copying the tools binaries in their projects' switches, but this is not an obvious workaround and adds multiple steps in the already involved project setup workflow.

#### The Platform installation time is too long

Between the installation of opam, the compilation of the compiler, and the installation and compilation of all of the tools, the setup can take 15 minutes. This duration is not acceptable in the context of VSCode, for instance, where we want to install everything for the user. 

Creating new projects with a local sandbox (local opam switch) takes 2 to 5 minutes.

#### There's no clear update workflow for the developer tools

The Platform can be updated by updating opam and the tools currently installed in an opam switch.

Updating opam can be simple if it has been installed with the user's package manager, but lots of users install opam from a pre-built binary or a separate installer on Windows. These users are left alone to know that an update of opam is available, and how to update it.

As for the other tools, the update is done through an `opam upgrade` of the current switch, which often introduces dependency conflicts, and is needed for every switch on the user's system.

### Performing common developer workflows is involved

Consider the workflow to add a new dependency to a project:

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

Or the command to format a codebase:

```
dune build @fmt --auto-promote
```

Both the overall workflows and the individual commands are rather complex and long and when put together, create a frustrating user experience, especially for users coming from other ecosystems who are used to typing single command to perform common tasks.

## OCaml 5.0 Platform Roadmap

To solve the pain points above, we wish to integrate all the existing developer tools better and offer a consistent experience for all the workflows supported by the different Platform tools. These tools will be distributed on all the supported operating systems, architectures and package managers and will integrate with popular IDEs like VSCode.

Tarides will initially lead the platform project, but we want to turn it into a community-led very early. To do so, key parts of the platform will also be to standardize and document both the developer workflows and the contents of the platform itself.

### Scope

Be the community-recommended tools for developing, building, documenting, testing and publishing OCaml code.

### Requirements

- **Define** the recommended tools to be used to be productive in OCaml.
    - Desired output: a clear document on ocaml.org explaining what are these tools, how new tools can become part of the platform and who decides this.
    - Metrics:
        - The number of requests for incubation in the Platform.
        - The number of requests for promotion/demotion.
        - Community engagement in the incubation, promotion or demotion process.
- **Document** the recommended workflow using the new tool.
    - Desired output: a specification of the existing workflows, using the current Platform tools.
    - Metrics:
        - The number of new users that ask questions about the best tools on public forums.
        - The number of visitors to the workflow documentation on OCaml.org.
- **Unify** installation of Platform tools.
    - Desired outputs: a single installer for all the supported platforms is available on ocaml.org.
    - Metrics: 
        - The time it takes to start contributing to an OCaml project from scratch.
        - The time it takes to try out OCaml 5.0.
- **Simplify** configuration of Platform tools.
    - Desired outputs: converging the configuration mechanism for tools to rely on explicit and consistent metadata 
    - Metrics: 
        - How many metadata files for an OCaml project
        - How much metadata is not stored out of the .git folder
- **Release** regularly in sync with the OCaml compiler, starting with 5.0.
    - Desired output: regular releases of the OCaml Platform, in sync with the compiler releases.
    - Metrics:
        - The number of manual steps required to release the OCaml Platform.
        - The time between the release of OCaml 5.0 RC and the release of OCaml Platform.
- **Migrate** existing workflows like ocamldoc plugins, ocamlbuild rules, remaining camlp4 extensions, and cross-compilation hacks.
    - Desired output: the community converges to a well-defined, well-maintained, blessed set of tools.
    - Metrics:
        - The number of opam projects that use older tools.
        - The number of projects in the incubation stage that aim to replace existing tools.
- **Deprecate** the older tools (ocamlbuild, ocamldoc, camlp4) to reduce our long-term support envelope.
    - Desired output: reduce maintenance costs and focus effort on new tools.
    - Metrics: 
        - The number of projects in the Sustained Platform stage.
        - The number of projects which tries to solve the same problems

#### Risks

- unable to migrate users to new tools
  - do our build, test and doc in particular cover all bases for major users?
  - are new tools fit for purpose?
- does odoc have sufficient feature coverage
- b0/dune split
- difficulty to keep the workflow up-to-date on ocaml.org with the release of new tools
- OCaml development team does not leave enough time between RC/release
- unable to edit ocaml.org

#### Support Envelope

Our goal is to release an OCaml 5.0 Platform preview before OCaml 5 itself is released. Our focus will be on ensuring that the installer is available and works on every supported system. As such, packaging the OCaml Platform for the different package managers is a stretch goal.

See the [supported platforms](https://hackmd.io/VcoUSFMYSiiO50Bo0ksQww).

#### Release Timeline

Release Manager: @samoht
- Alpha: June 2022
- Release: Q2 2022 in sync with OCaml 5.0.0
