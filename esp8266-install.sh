#!/bin/bash
#!/bin/bash
ESP8266_VER=2.7.4
git clone --depth 1 --single-branch --branch $ESP8266_VER https://github.com/esp8266/Arduino.git esp8266-$ESP8266_VER
cd esp8266-$ESP8266_VER && git submodule update --init && cd ..
cd esp8266-$ESP8266_VER/tools && ./get.py && cd ../..


