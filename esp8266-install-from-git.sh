declare ESP8266_VER=2.3.0

declare DOWNLOAD_CACHE=./download
mkdir $DOWNLOAD_CACHE

# Get Arduino core for ESP8266 chip
git clone https://github.com/esp8266/Arduino esp8266-$ESP8266_VER
rm -f esp8266
ln -s esp8266-$ESP8266_VER esp8266
cd esp8266/tools && ./get.py

#cleanup
rm -fr $DOWNLOAD_CACHE

