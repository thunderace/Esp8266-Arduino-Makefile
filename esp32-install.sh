# Get Arduino core for ESP32 chip
git clone https://github.com/espressif/arduino-esp32 esp32
if [[ "$OSTYPE" == "cygwin" ]]; then
	chmod +x esp32/tools/get.exe
	chmod +x esp32/tools/espota.exe
	chmod +x esp32/tools/gen_esp32part.exe
	cd esp32/tools && ./get.exe
else
	cd esp32/tools && ./get.py
fi
