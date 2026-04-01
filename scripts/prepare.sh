#!/bin/sh

dnf install git zstd docker -y

#git clone https://github.com/thanusiak/ollama.git
#cd ollama
#git fetch origin 
#git switch upgrade-go-to-1.24.6
#git pull

docker login docker.io
./scripts/build_linux.sh

#Ignore: tar: ./lib/ollama/rocm: Cannot stat: No such file or directory

cp -R ./dist/usr/lib/ollama/ /tmp/ollama/
cp ./dist/bin/ollama /tmp/ollama/

tar -czvf /tmp/ollama.tar.gz --dereference -C /tmp ollama