#!/bin/bash

RP_CONTAINERS=$(docker container ls | grep rapidpro_ | awk '{printf $2"\n" }' | sort | uniq | awk -F ':' '{print $1":"$2" "}')
echo "Stopping Rapidpro docker containers..."
if ! docker-compose down; then
  echo "Failed docker-compose down"
fi

echo "Removing Rapidpro docker images..."

for items in $RP_CONTAINERS; do
  REPO=$(echo $items | awk -F ':' '{print $1}')
  TAG=$(echo $items | awk -F ':' '{print $2}')
  IMAGE_ID=$(docker images | grep $REPO | grep $TAG | awk '{print $3}')
  echo "  Removing Image ID $IMAGE_ID, Repository:: $REPO, TAG: $TAG"
  if ! docker image rm ${IMAGE_ID} -f; then
    echo "Failed docker image rm ${IMAGE_ID} -f"
  fi
done
