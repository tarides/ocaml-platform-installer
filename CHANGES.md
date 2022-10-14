# Changelog

## unreleased

- Fix OCamlformat is not installed to the right version if it was already
  installed. (#127)

## 0.6.0 (2022-10-05)

- Pull packages that are independent of the ocaml version from the global cache
  (#117)

## 0.5.0 (2022-09-29)

- Avoid adding packages built with a pinned compiler into the cache. (#115)
- Force the installed version to match the best version available for a compiler
  version. (#112)
- Separate between packages that depends or not on the ocaml version used to
  compile them. When they do not depend on it, use a single entry per package
  version in the cache (#110).

## 0.4.0 (2022-09-26)

- `ocaml-platform` will now work with all common compiler packages, skipping the
  cache for pinned one. it will fail with a friendly error message for very
  uncommon one. (#106)
- Display version to be installed and whether a package needs to be built in the
  logs (#103)
- Fix opam detection in installer script (#102)
- Log before initialising Opam (#93)
- Use OPAMCLI environment variable set to "2.0" to force the CLI version of
  future opam version. (#92)
- Continue installing if a tool is not available (#90)
  Instead of stopping for complaining.

## 0.3.0 (2022-09-05)

- Add support for versions of ocaml where an `ocaml-system` package is not
  provided in the default repo, such as for instance, OCaml 5! (#83)
- Export the internal library `platform.binary_repo` (#82)
  The library manages the cache repository.
- Fix the fact that man pages files were not included (#82)
- Fix error line appearing in reverse order, and show error in exection even in
  `-v` verbose mode (#84).

## 0.2.0 (2022-09-01)

- Add an `available` field with `arch` and `os-distribution` in the opam files
  of the binary package (#74)
- Improve logging behaviour in case of user interrupt (#80)
- Use an install file instead of install instruction in binary package (#73)
- Better logs, including few sliding lines of opam output when necessary (#57)
- Fix duplicate files in binary package archive (#71)
- Fix the installer script not working on macos (#77)

## 0.1.0 (2022-06-15)

- Better handling of user interruption (#69)
- Fix crash while parsing version constraints (#70)
- Speed-up creating the sandbox switch (#56)
- Improve the installer script's output (#62)
- Add a `DETAILS` section to the man page (#54)
- Add guard to prevent partial script from being run (#53)

## 0.0.1-alpha (2022-05-25)

Initial release.
