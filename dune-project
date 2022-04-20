(lang dune 3.0)

(name platform)

(generate_opam_files true)

(source
 (github tarides/ocaml-platform))

(authors
 "Jules Aguillon"
 "Paul-Elliot Anglès d'Auriac"
 "Sonja Heinze"
 "Thibaut Mattio")

(maintainers
 "Jules Aguillon"
 "Paul-Elliot Angl\195\168s d'Auriac"
 "Sonja Heinze"
 "Thibaut Mattio")

(license LICENSE)

(package
 (name platform)
 (allow_empty)
 (synopsis "Set-up an OCaml environment")
 (description "")
 (depends
  ocaml
  dune
  (cmdliner
   (>= 1.1.0))))
