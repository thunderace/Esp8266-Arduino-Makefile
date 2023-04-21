#!/bin/sh
# Get Arduino core for ESP32 chip
git clone --depth 1 https://github.com/espressif/arduino-esp32 esp32-git
cd esp32-git && git submodule update --init --recursive
cd tools
if [ "$OSTYPE" = "cygwin" ] || [ "$OSTYPE" = "msys" ]; then
	chmod +x get.exe
	chmod +x espota.exe
	chmod +x gen_esp32part.exe
	./get.exe
else
	chmod +x *.py
	./get.py
	chmod +x esptool/esptool.py
fi
cd ../..
