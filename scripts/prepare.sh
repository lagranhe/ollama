#!/bin/sh

mkdir ollama
cd ollama
dnf install git zstd docker -y
git clone https://github.com/thanusiak/ollama.git
cd ollama
git fetch origin 
git switch upgrade-go-to-1.24.6
git pull
./scripts/build_linux.sh