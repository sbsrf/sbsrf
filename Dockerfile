FROM ubuntu:mantic

RUN apt update && apt install -y zip rime-prelude librime-bin
