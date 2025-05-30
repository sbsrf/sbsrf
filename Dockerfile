FROM ubuntu:mantic

RUN apt update && apt install -y zip librime-bin
