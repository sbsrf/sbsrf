FROM ubuntu:24.04

RUN apt update && apt install -y zip rime-prelude librime-bin
