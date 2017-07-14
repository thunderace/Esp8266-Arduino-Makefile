declare DOWNLOAD_CACHE=./download
mkdir -p $DOWNLOAD_CACHE

# Get Xtensa GCC Compiler
wget --no-clobber https://dl.espressif.com/dl/xtensa-esp32-elf-linux32-1.22.0-61-gab8375a-5.2.0.tar.gz -P $DOWNLOAD_CACHE
tar xvfz $DOWNLOAD_CACHE/xtensa-esp32-elf-linux32-1.22.0-61-gab8375a-5.2.0.tar.gz


# Get Arduino core for ESP32 chip
git clone https://github.com/espressif/arduino-esp32
ln -s arduino-esp32 esp32

#cleanup
#rm -fr $DOWNLOAD_CACHE

