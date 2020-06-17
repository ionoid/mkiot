#!/bin/sh

rm -fr /var/cache/apk/* && rm -fr /tmp/*
rm -fr /usr/share/man/* /usr/share/doc /root/.npm /root/.node-gyp /root/.config \
        /usr/lib/node_modules/npm/man /usr/lib/node_modules/npm/doc /usr/lib/node_modules/npm/docs \
        /usr/lib/node_modules/npm/html

# rm -fr /usr/lib/node_modules/npm/scripts
