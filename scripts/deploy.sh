#!/bin/sh

docker build -t covfefe-x -f prod.Dockerfile .
docker tag covfefe-x asia.gcr.io/jadiunr/covfefe-x
docker push asia.gcr.io/jadiunr/covfefe-x