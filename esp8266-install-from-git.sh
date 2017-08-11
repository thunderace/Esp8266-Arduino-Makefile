git clone https://github.com/esp8266/Arduino.git esp8266.git
rm -f esp8266
ln -s esp8266.git esp8266
cd esp8266/tools && ./get.py && cd ../..
if [[ "$OSTYPE" == "cygwin" ]]; then
	chmod +x ./esp8266/tools/esptool/esptool.exe
	chmod +x ./esp8266/tools/mkspiffs/mkspiffs.exe
fi


