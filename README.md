# Esp8266/Esp32-Arduino-Makefile for Linux and Cygwin/Windows
Makefile to build arduino code for ESP8266 under linux and Cygwin (tested on debian X64, raspberry, CYGWIN_NT-10.0).
Based on Martin Oldfield arduino makefile : http://www.mjoldfield.com/atelier/2009/02/arduino-cli.html

## Changelog

04/21/2023
- ESP32 : 2.0.9 support

04/21/2023
- ALL : makefile splitted : one for ESP8266 and another for ESP32x
- ESP8266 : 3.1.2
- ESP32 : 2.0.8 + support for S2, S3 and C3 variants (binaries not yet tested on board)

10/15/2021-2
- ESP32 : fix incorrect installation of gcc 5 dependencies

10/15/2021
- ALL  : perl and ard-parse-board are deprecated (faster compilation)
- ESP8266 : define ARDUINO_ESP8266_MAJOR, ARDUINO_ESP8266_MINOR, ARDUINO_ESP8266_REVISION, ARDUINO_ESP8266_RELEASE_X_X_X and ARDUINO_ESP8266_RELEASE (not in the git repo)
- ESP8266 : 3.0.2 (last release) support
- ESP32 : 2.0.0 (last release) support

05/27/2021
- ESP8266 : fixes for 3.X support
- ESP8266 : upgrade to support last stable release (3.0.1)

05/27/2021
- ESP8266 : drop support for version < 2.5.2
- ESP8266 : upgrade to support last stable release (3.0.0)
- ESP8266 : minor fixes for last stable release (2.7.4)

01/02/2020
- ESP8266 : upgrade to last stable release (2.6.3)

11/28/2019
- ESP8266 : upgrade to last stable release (2.6.2)

11/27/2019
- ESP8266 : fix fs_upload

11/13/2019
- ESP8266 : upgrade to last stable release (2.6.1) - fix upload command
 
11/13/2019
- ESP32 : default version is 1.0.4

11/12/2019
- ESP8266 : default version is 2.6.0
- ESP32 : default version is 1.0.4

06/21/2019
- ESP8266 : set default upload speed to 115200 if none found

06/20/2019
- ESP8266 : cleaner #28 fix : tested only on linux with 2.4.2, 2.5.2 and last git versions

06/19/2019
- ESP8266 : new stable installation script
- ESP8266 : fast and dirty #28 fix : use new elf2bin/upload python scripts

05/23/2019
- TODO removed

05/22/2019
- ESP8266 : default version is 2.5.2
- ESP32 : default version is 1.0.2

04/11/2019
- ESP8266 : default version is 2.5.0 - fix LED buitin

03/28/2019
- ESP8266-git : last git support
- ESP8266 : 2.5.0 support
- ESP8266 : lwip v2 lower memory as default lwip variant

03/26/2019
- ESP32 : Update for ESP32 arduino last git
- ESP32 : Update for ESP32 arduino last stable release
- ESP32 : Fix install scripts

03/13/2019
- Change Shebang from #!/bin/sh to #!/bin/bash in all install scripts in order to work on recent debian releases

01/29/2019
- ESP8266-git : Update for last git

12/20/2018
- ESP8266-git : Update for last git (change in boards.txt and plateform.txt)

12/06/2018
- ESP32 : Update for ESP32 arduino last git

12/05/2018
- ALL : add EXCLUDE_USER_LIBS entry to exclude libs from auto dependencies (usefull with libraies with conditionnal includes)
- ESP32 : Fix for mbedtls config file and add example (BasicHttpClient)

10/16/2018
- ESP32 : Add support for 1.0.0 version
- ESP32 : Update for git version
- 
08/30/2018
- ESP8266 : Add support for version 2.4.2 (thanks to wintersandroid for is PR)
- ESP8266 : standardization of release directories naming (.git -> -git)

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
  - sudo apt-get install unzip sed
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


