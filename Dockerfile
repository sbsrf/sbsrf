FROM ubuntu:mantic

RUN apt update && apt install -y sudo zip rime-prelude librime-bin
