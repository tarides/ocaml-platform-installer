(lang dune 3.0)

(name platform)

(generate_opam_files true)

(source
 (github tarides/ocaml-platform))

(authors
 "Jules Aguillon"
 "Paul-Elliot Anglès d'Auriac"
 "Sonja Heinze"
 "Thibaut Mattio"
 "Patrick Ferris")

(maintainers
 "Jules Aguillon"
 "Paul-Elliot Anglès d'Auriac"
 "Sonja Heinze"
 "Thibaut Mattio"
 "Patrick Ferris")

(license ISC)

(package
 (name platform)
 (synopsis "The best way for developers to write software in OCaml")
 (description
  "The OCaml Platform represents the best way for developers, both new and old, to write software in OCaml. It combines a coherent set of tools, documentation and resources to be productive with OCaml.")
 (depends
  (ocaml
   (>= 4.10.0))
  ocaml-version
  angstrom
  (cmdliner
   (>= 1.1.0))
  base64
  astring
  bos
  ANSITerminal
  lwt
  opam-file-format
  ppxlib))
