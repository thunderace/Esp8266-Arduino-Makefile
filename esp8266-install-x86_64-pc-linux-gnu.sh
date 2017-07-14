declare ESP8266_VER=2.3.0
declare MKSPIFFS_VER=0.1.2
declare ESPTOOL_VER=0.4.9

declare DOWNLOAD_CACHE=./download
mkdir $DOWNLOAD_CACHE

# Get MKSPIFFS Tool
wget --no-clobber https://github.com/igrr/mkspiffs/releases/download/$MKSPIFFS_VER/mkspiffs-$MKSPIFFS_VER-linux64.tar.gz -P $DOWNLOAD_CACHE
tar xvfz $DOWNLOAD_CACHE/mkspiffs-$MKSPIFFS_VER-linux64.tar.gz -C ./bin --strip=1   
chmod +x bin/mkspiffs

# Get ESPTOOL
wget --no-clobber https://github.com/igrr/esptool-ck/releases/download/$ESPTOOL_VER/esptool-$ESPTOOL_VER-linux64.tar.gz -P $DOWNLOAD_CACHE
tar xvfv $DOWNLOAD_CACHE/esptool-$ESPTOOL_VER-linux64.tar.gz -C ./bin --strip=1 
chmod +x bin/esptool

# Get Xtensa GCC Compiler
wget --no-clobber http://arduino.esp8266.com/linux64-xtensa-lx106-elf-gb404fb9.tar.gz -P $DOWNLOAD_CACHE
tar xvfz $DOWNLOAD_CACHE/linux64-xtensa-lx106-elf-gb404fb9.tar.gz


# Get Arduino core for ESP8266 chip
wget --no-clobber https://github.com/esp8266/Arduino/releases/download/$ESP8266_VER/esp8266-$ESP8266_VER.zip -P $DOWNLOAD_CACHE
unzip $DOWNLOAD_CACHE/esp8266-$ESP8266_VER.zip
rm -f esp8266
ln -s esp8266-$ESP8266_VER esp8266


#cleanup
rm -fr $DOWNLOAD_CACHE

