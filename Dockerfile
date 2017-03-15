FROM node:5-slim
MAINTAINER Wenxuan Zhao <viz@linux.com>

COPY package.json /app/
WORKDIR /app

ENV DEPS='build-essential python git-all pkg-config libncurses5-dev \
          libssl-dev libnss3-dev libexpat-dev'

RUN useradd -m -s /bin/bash -u 1000 -U app \
 && apt-get update \
 && apt-get install -y $DEPS \
 && npm -g install coffee-script \
 && npm install \
 && apt-get purge -y $DEPS \
 && apt-get --purge autoremove -y \
 && rm -rf /var/lib/apt/lists/*
USER app

COPY . /app

CMD ["npm", "start"]
