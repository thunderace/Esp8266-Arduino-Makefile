declare ESP8266_VER=2.3.0

declare DOWNLOAD_CACHE=./download
mkdir $DOWNLOAD_CACHE

# Get Arduino core for ESP8266 chip
wget --no-clobber https://github.com/esp8266/Arduino/releases/download/$ESP8266_VER/esp8266-$ESP8266_VER.zip -P $DOWNLOAD_CACHE
unzip $DOWNLOAD_CACHE/esp8266-$ESP8266_VER.zip
rm -f esp8266
ln -s esp8266-$ESP8266_VER esp8266
cd esp8266/tools && ./get.py

#cleanup
rm -fr $DOWNLOAD_CACHE

