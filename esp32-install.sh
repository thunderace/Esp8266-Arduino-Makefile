#!/bin/sh
# Get Arduino core for ESP32 chip
git clone https://github.com/espressif/arduino-esp32 esp32
cd esp32 && git submodule update --init --recursive
if [ "$OSTYPE" == "cygwin" ] || [ "$OSTYPE" == "msys" ]; then
	chmod +x esp32/tools/get.exe
	chmod +x esp32/tools/espota.exe
	chmod +x esp32/tools/gen_esp32part.exe
	cd esp32/tools && ./get.exe
else
	chmod +x esp32/tools/get.py
	cd esp32/tools && ./get.py
fi
