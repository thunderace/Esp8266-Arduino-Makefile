#!/bin/bash
ESP8266_VER=2.4.2

DOWNLOAD_CACHE=/cygdrive/d/6_TMP/downloads
mkdir $DOWNLOAD_CACHE

# Get Arduino core for ESP8266 chip
wget --no-clobber https://github.com/esp8266/Arduino/releases/download/$ESP8266_VER/esp8266-$ESP8266_VER.zip -P $DOWNLOAD_CACHE
unzip -o $DOWNLOAD_CACHE/esp8266-$ESP8266_VER.zip
mkdir esp8266-$ESP8266_VER/package
wget --no-clobber http://arduino.esp8266.com/versions/$ESP8266_VER/package_esp8266com_index.json -O esp8266-$ESP8266_VER/package/package_esp8266com_index.template.json
cd esp8266-$ESP8266_VER/tools && ./get.py && cd ../..
if [ "$OSTYPE" == "cygwin" ] || [ "$OSTYPE" == "msys" ]; then
	chmod +x ./esp8266-$ESP8266_VER/tools/esptool/esptool.exe
	chmod +x ./esp8266-$ESP8266_VER/tools/mkspiffs/mkspiffs.exe
fi
#cleanup
rm -fr $DOWNLOAD_CACHE

