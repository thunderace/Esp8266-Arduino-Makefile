#!/bin/sh
# Get Arduino core for ESP32 chip
ESP32_VER=2.0.7

git clone --depth 1 --branch $ESP32_VER https://github.com/espressif/arduino-esp32 esp32-$ESP32_VER
#git clone --depth 1 https://github.com/espressif/arduino-esp32 esp32-git
cd esp32-$ESP32_VER && git submodule update --init --recursive
cd tools
if [ "$OSTYPE" = "cygwin" ] || [ "$OSTYPE" = "msys" ]; then
	./get.exe
else
	chmod +x *.py
	./get.py
	chmod +x esptool/esptool.py
fi
cd ../..
