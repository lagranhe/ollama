#!/bin/sh

#git clone https://github.com/thanusiak/ollama.git
#cd ollama
#git fetch origin 
#git switch upgrade-go-to-1.24.6
#git pull

dnf install git zstd docker -y
docker login docker.io
./scripts/build_linux.sh