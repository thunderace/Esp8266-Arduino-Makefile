#!/bin/sh
# Get Arduino core for ESP32 chip
git clone https://github.com/espressif/arduino-esp32 esp32-git
cd esp32-git && git submodule update --init --recursive
if [ "$OSTYPE" == "cygwin" ] || [ "$OSTYPE" == "msys" ]; then
	chmod +x esp32-git/tools/get.exe
	chmod +x esp32-git/tools/espota.exe
	chmod +x esp32-git/tools/gen_esp32part.exe
	cd esp32-git/tools && ./get.exe
else
	chmod +x esp32-git/tools/get.py
	cd esp32-git/tools && ./get.py
fi
