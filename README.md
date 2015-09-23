# Esp8266-Arduino-Makefile
Makefile to build arduino code for ESP8266 under linux (tested on debian X64)

## Changelog
23/09/2015 : 
- working dependencies
- multiple ino files allowed
- core & spiffs objects build in there own directories
- autodetect system and user libs used by the sketch
- Makefile renamed to esp8266Arduino.mk

## Installation
- Clone this repository : `git clone --recursive https://github.com/thunderace/Esp8266-Arduino-Makefile.git`
- Install third party tools : `cd Esp8266-Arduino-Makefile && make install && cd ..` 
- In your sketch directory place a Makefile that defines anything that is project specific and follow that with a line `include /path/to/this/directory/Makefile` (see example)
- `make upload` should build your sketch and upload it...
 


