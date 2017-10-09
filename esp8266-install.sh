declare ESP8266_VER=2.3.0

declare DOWNLOAD_CACHE=./download
mkdir $DOWNLOAD_CACHE

# Get Arduino core for ESP8266 chip
wget --no-clobber https://github.com/esp8266/Arduino/releases/download/$ESP8266_VER/esp8266-$ESP8266_VER.zip -P $DOWNLOAD_CACHE
unzip $DOWNLOAD_CACHE/esp8266-$ESP8266_VER.zip
if [ "$OSTYPE" == "cygwin" ] || [ "$OSTYPE" == "msys" ]; then
	rm -fr esp8266
	mv Esp8266-$ESP8266_VER esp8266
else
	rm -f esp8266
	ln -s esp8266-$ESP8266_VER esp8266
fi
cp -R bin/package esp8266
cd esp8266/tools && ./get.py && cd ../..
if [ "$OSTYPE" == "cygwin" ] || [ "$OSTYPE" == "msys" ]; then
	chmod +x ./esp8266/tools/esptool/esptool.exe
	chmod +x ./esp8266/tools/mkspiffs/mkspiffs.exe
fi
#cleanup
rm -fr $DOWNLOAD_CACHE

