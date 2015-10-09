# Esp8266-Arduino-Makefile
Makefile to build arduino code for ESP8266 under linux (tested on debian X64).
Based on Martin Oldfield arduino makefile : http://www.mjoldfield.com/atelier/2009/02/arduino-cli.html

## Changelog
08/10/2015 : 
- add $(ARDUINO_CORE)/variants/$(VARIANT) to include path for nodemcuv2
29/09/2015 : 
- fix README for third party tools installation
- move post-installation out of the makefile

23/09/2015 : 
- working dependencies
- multiple ino files allowed
- core & spiffs objects build in their own directories
- autodetect system and user libs used by the sketch
- Makefile renamed to esp8266Arduino.mk

## Installation
- Clone this repository : `git clone --recursive https://github.com/thunderace/Esp8266-Arduino-Makefile.git`
- Install third party tools : `cd Esp8266-Arduino-Makefile && chmod+x install.sh && ./install.sh && cd ..` 
- In your sketch directory place a Makefile that defines anything that is project specific and follow that with a line `include /path_to_Esp8266-Arduino-Makefile_directory/esp8266Arduino.mk` (see example)
- `make upload` should build your sketch and upload it...

#dependencies
- this project use the last esp8266/Arduino repository (not stable) and the last stagging esptool and xtensa-lx106 toolchain

## TODO
- build user libs in their own directory to avoid problems with multiple files with same name.


