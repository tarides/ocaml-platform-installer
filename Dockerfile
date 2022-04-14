# syntax=docker/dockerfile:1
FROM ubuntu
RUN apt update
RUN apt install -y gcc make patch unzip bubblewrap curl
COPY _build/default/bin/main.exe /usr/local/bin/ocaml-platform
RUN printf "\n" | ocaml-platform
RUN opam -v
