#!/bin/sh
git clone https://github.com/esp8266/Arduino.git esp8266.git

cd esp8266.git/tools && ./get.py && cd ../..
if [ "$OSTYPE" = "cygwin" ]
then
	chmod +x ./esp8266.git/tools/esptool/esptool.exe
	chmod +x ./esp8266.git/tools/mkspiffs/mkspiffs.exe
fi


