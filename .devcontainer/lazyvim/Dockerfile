FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    git \
    make \
    neovim \
    ripgrep \
    zsh

RUN useradd --create-home --shell /bin/zsh lean
USER lean
WORKDIR /home/lean

RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain none
ENV PATH="/home/lean/.elan/bin:${PATH}"

RUN git clone --filter=blob:none https://github.com/LazyVim/starter ~/.config/nvim
COPY lean.lua .config/nvim/lua/plugins/lean.lua
