ARDUINO_VARIANT    = nodemcuv2
SERIAL_PORT = /dev/ttyUSB0
TAG = V1.01
NODENAME = ArDomo23
#ESP8266_VERSION=git
GLOBAL_USER_LIBDIR=~/repo.git/domo.mqtt/ESP8266/libraries
USER_DEFINE=-DRELAY -DMQTT_KEEPALIVE=120 -DMQTT_MAX_PACKET_SIZE=1024 -D_NODENAME_=\"$(NODENAME)\" -DMAX_SSID=2 -D_SSID1_=\"main\" -D_WIFI_PASSWORD1_=\"Delphine_Marie_Quentin_Arnaud\" -D_SSID2_=\"speedtouch\" -D_WIFI_PASSWORD2_=\"Delphine_Marie_Quentin_Arnaud\"
include ../../espXArduino.mk
myota: $(BUILD_OUT)/$(TARGET).bin
	node $(HOME)/repo.git/domo.mqtt/utils/sendOTA.js -n $(NODENAME)  -b $(BUILD_OUT)/$(TARGET).bin


