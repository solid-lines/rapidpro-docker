#!/bin/bash

echo "Stopping Rapidpro docker containers..."
if ! docker-compose down; then
  echo "Failed docker-compose down"
  exit 1
fi

echo "Building and starting Rapidpro docker containers"
if ! docker-compose up --build -d; then
  echo "Failed docker-compose" 1>&2
fi
