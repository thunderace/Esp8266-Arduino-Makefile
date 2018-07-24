# Esp8266/Esp32-Arduino-Makefile for Linux and Cygwin/Windows
Makefile to build arduino code for ESP8266 under linux and Cygwin (tested on debian X64, raspberry, CYGWIN_NT-10.0).
Based on Martin Oldfield arduino makefile : http://www.mjoldfield.com/atelier/2009/02/arduino-cli.html

## Changelog
07/24/2018
- ALL : add Shebang to all sh files
- ESP8266 : Add support for libraries/user assembly (.S) compilation (tested with gdbstub)

06/01/2018
- ESP8266-git version : Workaround for SD.h not found -> add 'ARDUINO_LIBS=SD SPI' to your Makefile
- ESP8266-git version : Generation of the eagle.app.v6.common.ld file
 
04/17/2018
- Add option to log serial outputs to file (set LOG_SERIAL_TO_FILE=yes in your makefile. The out file is serial.log)
- ESP8266 : Swicth to lwip V2 low memory by default
- ESP32 : update for last git commit

02/12/2018
- Add reset target
- ESP8266 : update for the last git commit (use lwip_gcc)

12/06/2017
- ESP8266 : fix 'section .text will not fit in region iram1_0_seg' with big sketches
12/01/2017:
- ESP32 : update for 46d1b17 git commit
- ESP32 : update installation script
- ESP32 & ESP8266 : 
  - auto detect core esp libraries used by user libraries
  - auto detect user libraries used by user libraries
  - fix ArduinoJson user lib no detection
  - many enhancements
- ESP8266 : add mkspiffs support (create and upload)
- ESP8266 : new option to use 2.3.0 stable version  (default) or git esp8266 arduino version : set ESP8266_VERSION=.git in the calling makefile (see AdvancedWebServer makefile)
- ESP8266 : update for last git commit

10/05/2017:
- ESP32 : UPDATE FOR LAST esp32 Git commit
- ESP32 : use esptool.exe on windows platforms

08/11/2017:
- fix cygwin support for both esp8266 and esp32
- ESP32 : update compiler flags and libs

07/20/2017:
- Replace cat by $(CAT)

07/19/2017:
- Use generic installers (with embedded tool get)
- support for ESP8266 arduino core version 2.4.0 (not released yet) with autodetection

07/14/2017:
- ESP32 support : (no arm support) see below

01/24/2017:
- add linux armhf install script (raspberry and others)

12/28/2016:
- compile c files with gcc not g++ 

12/27/2016:
- README update 
- fix for non conventional libraries (Servo for example)
- add servo test

06/22/2016:
- TAG fix
- add test sketch for ino concatenation
- Arduino.h is automatically included during compilation
- c files are compiled as cpp files (is it really a good thing?)
 
06/21/2016:
- new SPIFFS_SIZE param (default to 4M3M mapping) : set it to 1 in your Makefile to use the 4M1M mapping (see Makefile in included example)
- new SERIAL_BAUD param (default to 115200) : for use with the term command 
- some change in variables names

05/09/2016 :
- update to esp8266-2.2.0
- new OTA params : OTA_IP OTA_PORT OTA_AUTH (see example)

03/08/2016 :
- Handle subdirectories of core uniformly : pull request from surr. Thank you
 
02/29/2016
- Cygwin support (from intrepidor not tested)
- update to esp8266-2.1.0
- user can install specific libraries in libraries dir
 
02/21/2016 :
- fix mkspiffs install

02/18/2016 :
- new x86 and x64 linux install
- cleanup

08/12/2015 :
- add install script for 32 bit linux
- update to esp8266-2.0.0-rc2

04/11/2015 :
- use zip file from official link (http://arduino.esp8266.com/staging/package_esp8266com_index.json)
- ESP8266 git submodule removed
- remove $(ARDUINO_CORE)/variants/$(VARIANT) to include path (not needed)

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

## Installation and test
- Clone this repository : `git clone https://github.com/thunderace/Esp8266-Arduino-Makefile.git`
- install required tools : 
  - sudo apt-get update
  - sudo apt-get install libconfig-yaml-perl unzip sed
  - for ESP32 : 
    -  apt-get install git python
- cd ESP8266-Arduino-Makefile
- Install third party tools : for esp8266 `chmod +x esp8266-install.sh && ./esp8266-install.sh` 
                              for esp32   `chmod +x esp32-install.sh && ./esp32-install.sh` 
- for esp8266 : 
  - cd example/AdvancedWebServer
  - make
- for esp32 : 
  - cd example/SimpleWiFiServer
  - make
- update esp32 arduino core :
  `cd esp32 && git pull`

## General Usage
- In your sketch directory place a Makefile that defines anything that is project specific and follow that with a line `include /path_to_Esp8266-Arduino-Makefile_directory/espXArduino.mk` (see example)
- set the target : 
  - ARDUINO_ARCH=esp32 for ESP32
  - nothing or ARDUINO_ARCH=esp8266 for ESP8266
- `make upload` should build your sketch and upload it...

#dependencies
- For esp8266, this project install the lastest stable esp8266/Arduino repository (2.3.0)
- For esp32, this project install the master of espressif/arduino-esp32

## TODO
- build user libs in their own directory to avoid problems with multiple files with same name.


