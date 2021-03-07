#!/bin/bash

# please run this on a fresh user account
# this is a complete test suite run locally
# it requires sudo priv
# it install rootless docker (security) and starts docker service as non root user
# it then starts a demo registry to push/pull images 
# appropriate sleep times are put in to ensure any delays are compensated for
# this script builds the docker image with timestamp tag, pushes it to registry
# it then create mkdocs tar archive via produce 
# the created archive then piped to serve which copies the binstream to a local file and runs mkdocs serve
# we use timeout to start the server and then kill it with sigint
# once started a basic test of response on localhost:8000 is run
# then we cleanup everything

sudo apt-get install -y uidmap
dockerd-rootless-setuptool.sh install
systemctl --user start docker
systemctl --user enable docker
sudo loginctl enable-linger $(whoami)
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

#start a registry 
docker run --name demoregistry -d -p 5000:5000 --restart=always registry:2
sleep 5

image="vjain/mkdocs"
registry="localhost:5000"

timestamp=$(date +%Y%m%d%H%M%S)

tag=$image:$timestamp
remoteTag=${registry}/${tag}

#build image
docker build -t ${tag} .

docker tag ${tag} ${remoteTag}

docker push ${remoteTag}

docker run ${remoteTag} produce /tmp/produce > /tmp/example.tar.gz
# start a test server that would be killed by a timeout after 10s with sigint which will stop the container and cleanup
timeout -s SIGINT 10s bash -c "cat /tmp/example.tar.gz | WWWDIR=/var/mkdocs/www docker run -i -p 8000:8000 ${remoteTag} serve" &
pid=$! # capture the pid to wait for

sleep 5
curl -i localhost:8000
wait $pid

echo "All done"

docker rmi ${tag}
docker stop demoregistry
sleep 5
docker rm demoregistry
docker system prune -a -f


#get current hash and see if it already has a tag
commitsha=`git rev-parse HEAD`
checktag=`git describe --contains $commitsha 2>/dev/null`

#only tag if no tag already
if [ -z "$checktag" ]; then
    git tag $timestamp
    echo "Tagged with $timestamp"
    #git push --tags origin main
else
    echo "Already a tag on this commit"
fi

systemctl --user stop docker.service
dockerd-rootless-setuptool.sh uninstall
