declare ESP8266_VER=2.0.0
declare MKSPIFFS_VER=0.1.2
declare ESPTOOL_VER=0.4.6

declare DOWNLOAD_CACHE=./download
mkdir $DOWNLOAD_CACHE

# Get MKSPIFFS Tool
wget --no-clobber https://github.com/igrr/mkspiffs/releases/download/$MKSPIFFS_VER/mkspiffs-$MKSPIFFS_VER-linux32.tar.gz -P $DOWNLOAD_CACHE
tar xvfz $DOWNLOAD_CACHE/mkspiffs-$MKSPIFFS_VER-linux32.tar.gz -C ./bin -C --strip=1   
chmod +x bin/mkspiffs

# Get ESPTOOL
wget --no-clobber https://github.com/igrr/esptool-ck/releases/download/$ESPTOOL_VER/esptool-$ESPTOOL_VER-linux32.tar.gz -P $DOWNLOAD_CACHE
tar xvfv $DOWNLOAD_CACHE/esptool-$ESPTOOL_VER-linux32.tar.gz -C ./bin --strip=1 
chmod +x bin/esptool

# Get Xtensa GCC Compiler
wget --no-clobber http://arduino.esp8266.com/linux32-xtensa-lx106-elf.tar.gz -P $DOWNLOAD_CACHE
tar xvfz $DOWNLOAD_CACHE/linux32-xtensa-lx106-elf.tar.gz


# Get Arduino core for ESP8266 chip
wget --no-clobber https://github.com/esp8266/Arduino/releases/download/$ESP8266_VER/esp8266-$ESP8266_VER.zip -P $DOWNLOAD_CACHE
unzip $DOWNLOAD_CACHE/esp8266-$ESP8266_VER.zip
rm esp8266
ln -s esp8266-$ESP8266_VER esp8266


#cleanup
rm -fr $DOWNLOAD_CACHE

