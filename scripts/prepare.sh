#!/bin/sh

dnf install git zstd docker -y

#git clone https://github.com/thanusiak/ollama.git
#cd ollama
#git fetch origin 
#git switch upgrade-go-to-1.24.6
#git pull

docker login docker.io
./scripts/build_linux.sh

cp -R ./dist/usr/lib/ollama/ /tmp/ollama/
cp ./dist/bin/ollama /tmp/ollama/

