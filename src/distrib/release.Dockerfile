FROM ocaml/opam:alpine-ocaml-4.14
WORKDIR ocaml-platform/

COPY --chown=opam *.opam .
RUN opam install -y --deps-only --with-test --with-doc .

COPY --chown=opam . .
