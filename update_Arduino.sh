#! /bin/bash

git submodule foreach --recursive git pull origin esp8266
git add -A
git commit -m 'Pull down update for ESP8266 Arduino IDE'
git push
echo "Done"
