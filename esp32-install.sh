#!/bin/sh
# Get Arduino core for ESP32 chip
ESP32_VER=2.0.0

DOWNLOAD_CACHE=./download
mkdir $DOWNLOAD_CACHE

# Get Arduino core for ESP32 chip
wget --no-clobber https://github.com/espressif/arduino-esp32/releases/download/$ESP32_VER/esp32-$ESP32_VER.zip -P $DOWNLOAD_CACHE
unzip -o $DOWNLOAD_CACHE/esp32-$ESP32_VER.zip
mkdir esp32-$ESP32_VER/package
#wget --no-clobber https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json -O esp32-$ESP32_VER/package/package_esp32_index.template.json
cp ./bin/package_esp32_index.template.json esp32-$ESP32_VER/package/
if [ "$OSTYPE" == "cygwin" ] || [ "$OSTYPE" == "msys" ]; then
	cp ./bin/esp32/get.exe esp32-$ESP32_VER/tools
	chmod +x esp32-$ESP32_VER/tools/get.exe
	cd esp32-$ESP32_VER/tools && ./get.exe
	chmod +x esp32-$ESP32_VER/tools/espota.exe
	chmod +x esp32-$ESP32_VER/tools/gen_esp32part.exe
else
	cp ./bin/esp32/get.py esp32-$ESP32_VER/tools
	chmod +x esp32-$ESP32_VER/tools/get.py
	cd esp32-$ESP32_VER/tools && ./get.py
	rm -fr esp32-$ESP32_VER/tools/xtensa-esp32-elf/libexec/gcc/xtensa-esp32-elf/5.2.0 
	rm -fr esp32-$ESP32_VER/tools/xtensa-esp32-elf/share/gcc-5.2.0 
#	chmod +x esp32-$ESP32_VER/tools/espota.py
#	chmod +x esp32-$ESP32_VER/tools/esptool.py
#	chmod +x esp32-$ESP32_VER/tools/gen_esp32part.py
fi
#cleanup
rm -fr $DOWNLOAD_CACHE


