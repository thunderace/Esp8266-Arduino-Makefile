# Esp8266-Arduino-Makefile
Makefile to build arduino code for ESP8266 under linux (tested on debian X64)

## Changelog
23/09/2015 : 
- working dependencies
- multiple ino files allowed
- core & spiffs objects build in there own directories


## Installation
- Clone this repository : `git clone --recursive https://github.com/thunderace/Esp8266-Arduino-Makefile.git`
- Install third party tools : `cd Esp8266-Arduino-Makefile && make install && cd ..` 
- In the directory with your sketch place a Makefile that defines the libraries you need (USER_LIBS) and anything else that is project specific and follow that with a line `include /path/to/this/directory/Makefile` (see example)
- `make upload` should build your sketch and upload it...
 


