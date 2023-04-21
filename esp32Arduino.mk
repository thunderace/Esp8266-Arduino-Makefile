SHELL=/bin/bash
TARGET = $(notdir $(realpath .))
ARCH = $(shell uname)
ifneq ($(findstring CYGWIN,$(shell uname -s)),)
	# The extensa tools cannot use cygwin paths, so convert /cygdrive/c/abc/... to c:/cygwin64/abc/...
	ROOT_DIR_RAW := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
	ROOT_DIR := $(shell cygpath -m $(ROOT_DIR_RAW))
	EXEC_EXT = .exe
else
	ROOT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
endif

CAT	:= cat$(EXEC_EXT)
SED := sed$(EXEC_EXT)
GREP := grep$(EXEC_EXT)
PYTHON = python3
#DUMMY := $(shell $(ROOT_DIR)/bin/generate_platform.sh $(ARDUINO_HOME)/platform.txt $(ROOT_DIR)/bin/$(ARDUINO_ARCH)/platform.txt)
#runtime.platform.path = $(ARDUINO_HOME)
#include $(ROOT_DIR)/bin/$(ARDUINO_ARCH)/platform.txt

SERIAL_PORT ?= /dev/tty.nodemcu
ESP32_VERSION ?= 2.0.8
OTA_PORT ?= 8266
word-dot = $(word $2,$(subst ., ,$1))
ARDUINO_HOME ?=  $(ROOT_DIR)/esp32-$(ESP32_VERSION)
ARDUINO_VARIANT ?= nodemcu
ARDUINO_ARCH ?= $($(ARDUINO_VARIANT).build.target)
ARDUINO_VERSION ?= 10607
BOARDS_TXT  = $(ARDUINO_HOME)/boards.txt
PLATFORM_TXT  = $(ARDUINO_HOME)/platform.txt
include $(BOARDS_TXT)
ARDUINO_BOARD = $($(ARDUINO_VARIANT).build.board)
VARIANT = $($(ARDUINO_VARIANT).build.variant)
CONCATENATE_USER_FILES ?= no
FLASH_PARTITION ?= 4M1M
MCU = $($(ARDUINO_VARIANT).build.mcu)
SERIAL_BAUD   ?= 115200
CPU_FREQ ?= $($(ARDUINO_VARIANT).build.f_cpu)
FLASH_FREQ ?= 80m#$($(ARDUINO_VARIANT).menu.FlashFreq.$(CPU_FREQ).build.flash_freq)
MEMORY_TYPE = $($(ARDUINO_VARIANT).build.memory_type)
ifeq ($(MEMORY_TYPE),)
	MEMORY_TYPE = $($(ARDUINO_VARIANT).build.boot)_qspi
endif

FLASH_MODE ?= $($(ARDUINO_VARIANT).build.flash_mode)
ifeq ($(FLASH_MODE),)
	FLASH_MODE = dio
endif

UPLOAD_RESETMETHOD ?= $($(ARDUINO_VARIANT).upload.resetmethod)
UPLOAD_SPEED ?= $($(ARDUINO_VARIANT).upload.speed)
ifeq ($(UPLOAD_SPEED),)
	UPLOAD_SPEED = 115200
endif


SSL ?= basic
SSL_FLAGS = $($(ARDUINO_VARIANT).menu.ssl.$(SSL).build.sslflags)
PARTITIONS = $($(ARDUINO_VARIANT).build.partitions)
F_CPU = $($(ARDUINO_VARIANT).build.f_cpu)
FLASH_SIZE ?= $($(ARDUINO_VARIANT).build.flash_size)
BOOT ?= $($(ARDUINO_VARIANT).build.boot)
UPLOAD_MAXIMUM_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_size) 
UPLOAD_MAXIMUM_DATA_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_data_size) 
ESPRESSIF_SDK = $(ARDUINO_HOME)/tools/sdk/$(MCU)
FS_DIR ?= ./data
FS_IMAGE=$(BUILD_OUT)/spiffs/spiffs.bin
FS_FILES=$(wildcard $(FS_DIR)/*)

MKSPIFFS=$(ARDUINO_HOME)/tools/mkspiffs/mkspiffs$(EXEC_EXT)
ESPOTA ?= $(ARDUINO_HOME)/tools/espota.py
XTENSA_TOOLCHAIN ?= $(ARDUINO_HOME)/tools/$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf/bin/
ESPTOOL ?= $(ARDUINO_HOME)/tools/esptool/esptool.py

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))
get_library_files  = $(if $(and $(wildcard $(1)/src), $(wildcard $(1)/library.properties)), \
                        $(call rwildcard,$(1)/src/,*.$(2)), \
                        $(wildcard $(1)/*.$(2) $(1)/utility/*.$(2)))

LOCAL_USER_LIBDIR ?= ./libraries
GLOBAL_USER_LIBDIR ?= $(ROOT_DIR)/libraries

ifeq ($(origin TAG), undefined)
	TAG := $(shell date +'%Y-%m-%dT%H:%M:%S%z' | $(SED) -E 's/(..)$$/:\1/')
endif


ifdef NODENAME
	BUILD_OUT ?= ./build.$(ARDUINO_VARIANT).$(NODENAME)-$(ESP32_VERSION)
else
	BUILD_OUT ?= ./build.$(ARDUINO_VARIANT)-$(ESP32_VERSION)
endif

### ESP8266 CORE
CORE_SSRC = $(wildcard $(ARDUINO_HOME)/cores/esp32/*.S)
CORE_SRC = $(wildcard $(ARDUINO_HOME)/cores/esp32/*.c)
CORE_SRC += $(wildcard $(ARDUINO_HOME)/cores/esp32/*/*.c)
CORE_CXXSRC = $(wildcard $(ARDUINO_HOME)/cores/esp32/*.cpp)
CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/esp32/libb64/*.cpp)
CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/esp32/spiffs/*.cpp)
CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/esp32/umm_malloc/*.cpp)

CORE_OBJS = $(addprefix $(BUILD_OUT)/core/, \
	$(notdir $(CORE_SSRC:.S=.S.o) )) \
	$(addprefix $(BUILD_OUT)/core/, $(patsubst $(ARDUINO_HOME)/cores/esp32/%.c,%.c.o,$(CORE_SRC))) \
	$(addprefix $(BUILD_OUT)/core/, $(patsubst $(ARDUINO_HOME)/cores/esp32/%.cpp,%.cpp.o,$(CORE_CXXSRC))) 
#	$(addprefix $(BUILD_OUT)/core/libb64/, $(patsubst $(ARDUINO_HOME)/cores/esp32/libb64/%.cpp,%.cpp.o,$(CORE_CXXSRC))) \
#	$(addprefix $(BUILD_OUT)/core/spiffs/, $(patsubst $(ARDUINO_HOME)/cores/esp32/spiffs/%.cpp,%.cpp.o,$(CORE_CXXSRC))) \
#	$(addprefix $(BUILD_OUT)/core/umm_malloc/, $(patsubst $(ARDUINO_HOME)/cores/esp32/umm_malloc/%.cpp,%.cpp.o,$(CORE_CXXSRC)))
CORE_DIRS = $(sort $(dir $(CORE_OBJS)))

USRCDIRS = .
USER_SRC := $(wildcard $(addsuffix /*.c,$(USRCDIRS)))
USER_CXXSRC := $(wildcard $(addsuffix /*.cpp,$(USRCDIRS)))
USER_HSRC := $(wildcard $(addsuffix /*.h,$(USRCDIRS)))
USER_HPPSRC := $(wildcard $(addsuffix /*.hpp,$(USRCDIRS)))
USER_INOSRC := $(wildcard $(addsuffix /*.ino,$(USRCDIRS)))
LOCAL_SRCS = $(USER_INOSRC)$(USER_SRC) $(USER_CXXSRC) $(USER_HSRC) $(USER_HPPSRC)

# automatically determine included user libraries
USER_LIBS += $(sort $(filter $(notdir $(wildcard $(LOCAL_USER_LIBDIR)/*)), \
    $(shell $(SED) -ne 's/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p' $(LOCAL_SRCS))))
USER_LIBS += $(sort $(filter $(notdir $(wildcard $(GLOBAL_USER_LIBDIR)/*)), \
    $(shell $(SED)  -ne 's/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p' $(LOCAL_SRCS))))

# user libraries and sketch code
ULIBDIRS = $(sort $(dir $(wildcard \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/*.h) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/*.cpp) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*.cpp) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*.cpp) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.h) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.h) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*/*.cpp))))

ULIB_CSRC := $(wildcard $(addsuffix *.c,$(ULIBDIRS)))
ULIB_CXXSRC := $(wildcard $(addsuffix *.cpp,$(ULIBDIRS)))
ULIB_HSRC := $(wildcard $(addsuffix *.h,$(ULIBDIRS)))
ULIB_HPPSRC := $(wildcard $(addsuffix *.hpp,$(ULIBDIRS)))

ifneq ($(ULIBDIRS),)
	UALIB := $(sort $(filter $(notdir $(wildcard $(ARDUINO_HOME)/libraries/*)), \
		$(shell $(SED) -ne 's/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p' $(ULIB_CSRC) $(ULIB_CXXSRC) $(ULIB_HSRC) $(ULIB_HPPSRC))))
	UGLIB := $(sort $(filter $(notdir $(wildcard $(GLOBAL_USER_LIBDIR)/*)), \
		$(shell $(SED) -ne 's/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p' $(ULIB_CSRC) $(ULIB_CXXSRC) $(ULIB_HSRC) $(ULIB_HPPSRC))))
	ULLIB := $(sort $(filter $(notdir $(wildcard $(LOCAL_USER_LIBDIR)/*)), \
		$(shell $(SED) -ne 's/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p' $(ULIB_CSRC) $(ULIB_CXXSRC) $(ULIB_HSRC) $(ULIB_HPPSRC))))
endif

#remove duplicate Arduino libs
USER_LIBS := $(sort $(USER_LIBS) $(UGLIB) $(ULLIB))

USER_LIBS := $(filter-out $(EXCLUDE_USER_LIBS),$(USER_LIBS))

#and again
ULIBDIRS = $(sort $(dir $(wildcard \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/*.h) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*/*.c) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/*.cpp) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*.cpp) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*.cpp) \
	$(USER_LIBS:%=$(LOCAL_USER_LIBDIR)/%/src/*/*/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.h) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*/*.c) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.h) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*.cpp) \
	$(USER_LIBS:%=$(GLOBAL_USER_LIBDIR)/%/src/*/*/*.cpp))))

ULIB_CSRC := $(wildcard $(addsuffix *.c,$(ULIBDIRS)))
ULIB_CXXSRC := $(wildcard $(addsuffix *.cpp,$(ULIBDIRS)))

#autodetect arduino libs
ARDUINO_LIBS += $(sort $(filter $(notdir $(wildcard $(ARDUINO_HOME)/libraries/*)), \
	$(shell $(SED) -ne 's/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p' $(LOCAL_SRCS))))

#remove duplicate Arduino libs
ARDUINO_LIBS := $(sort $(ARDUINO_LIBS) $(UALIB))

# arduino libraries
ALIBDIRS = $(sort $(dir $(wildcard \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/*.c) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/*.S) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/*.cpp) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*/*.c) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*/*.S) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*/*.cpp) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*.h) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*.c) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*.S) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/libraries/%/src/*.cpp))))
ALIB_CSRC := $(wildcard $(addsuffix /*.c,$(ALIBDIRS)))
ALIB_SSRC := $(wildcard $(addsuffix /*.S,$(ALIBDIRS)))
ALIB_CXXSRC := $(wildcard $(addsuffix /*.cpp,$(ALIBDIRS)))


# object files
OBJ_FILES = $(addprefix $(BUILD_OUT)/,$(notdir $(TARGET).ino.cpp.o $(USER_SRC:.c=.c.o) $(USER_CXXSRC:.cpp=.cpp.o) ))
LIB_OBJ_FILES = $(addprefix $(BUILD_OUT)/libraries/,$(notdir $(ULIB_CSRC:.c=.c.o) $(ALIB_CSRC:.c=.c.o) $(ALIB_SSRC:.S=.S.o) $(ULIB_CXXSRC:.cpp=.cpp.o) $(ALIB_CXXSRC:.cpp=.cpp.o) ))


DEFINES = -DF_CPU=$(F_CPU) -DARDUINO=$(ARDUINO_VERSION) \
	-DARDUINO_$(ARDUINO_BOARD) -DARDUINO_ARCH_$(shell echo "$(ARDUINO_ARCH)" | tr '[:lower:]' '[:upper:]') \
	-DARDUINO_BOARD=\"$(ARDUINO_BOARD)\" -DARDUINO_VARIANT=\"$(ARDUINO_VARIANT)\" -DARDUINO_PARTITION_$($(ARDUINO_VARIANT).build.partitions) -DESP32

CORE_INC = $(ARDUINO_HOME)/cores/esp32 \
	$(ARDUINO_HOME)/variants/$(VARIANT)

INCLUDE_ARDUINO_H = -include Arduino.h
INCLUDES =  $(CORE_INC:%=-I%) $(ALIBDIRS:%=-I%) $(ULIBDIRS:%=-I%)  $(USRCDIRS:%=-I%)

VPATH = . $(CORE_INC) $(ALIBDIRS) $(ULIBDIRS)

WARNING_FLAGS ?= -w

COMPILER_OPT_FLAGS=-Os
COMPILER_OPT_FLAGS_RELEASE=-Os
COMPILER_OPT_FLAGS_DEBUG=-Og -g3

BUILD_EXTRA_FLAGS ?= -DESP32 -DCORE_DEBUG_LEVEL=$($(ARDUINO_VARIANT).build.code_debug) $($(ARDUINO_VARIANT).build.loop_core) $($(ARDUINO_VARIANT).build.event_core) \
						$($(ARDUINO_VARIANT).build.defines) $($(ARDUINO_VARIANT).build.extra_flags.$(MCU))


ifeq ($(MCU),esp32)
	CPREPROCESSOR_FLAGS = -DHAVE_CONFIG_H -DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\" -DUNITY_INCLUDE_CONFIG_H -DWITH_POSIX -D_GNU_SOURCE \
						-DIDF_VER=\"v4.4-4\" -DESP_PLATFORM -D_POSIX_READER_WRITER_LOCKS \
						-I$(ESPRESSIF_SDK)/include/config -I$(ESPRESSIF_SDK)/include/newlib/platform_include \
						-I$(ESPRESSIF_SDK)/include/freertos/include \
						-I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions/freertos -I$(ESPRESSIF_SDK)/include/freertos/port/xtensa/include \
						-I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions -I$(ESPRESSIF_SDK)/include/esp_hw_support/include \
						-I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc -I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc/esp32 \
						-I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32 -I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32/private_include \
						-I$(ESPRESSIF_SDK)/include/heap/include -I$(ESPRESSIF_SDK)/include/log/include -I$(ESPRESSIF_SDK)/include/lwip/include/apps \
						-I$(ESPRESSIF_SDK)/include/lwip/include/apps/sntp -I$(ESPRESSIF_SDK)/include/lwip/lwip/src/include \
						-I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include -I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include/arch \
						-I$(ESPRESSIF_SDK)/include/soc/include -I$(ESPRESSIF_SDK)/include/soc/esp32 -I$(ESPRESSIF_SDK)/include/soc/esp32/include \
						-I$(ESPRESSIF_SDK)/include/hal/esp32/include -I$(ESPRESSIF_SDK)/include/hal/include -I$(ESPRESSIF_SDK)/include/hal/platform_port/include \
						-I$(ESPRESSIF_SDK)/include/esp_rom/include -I$(ESPRESSIF_SDK)/include/esp_rom/include/esp32 -I$(ESPRESSIF_SDK)/include/esp_rom/esp32 \
						-I$(ESPRESSIF_SDK)/include/esp_common/include -I$(ESPRESSIF_SDK)/include/esp_system/include -I$(ESPRESSIF_SDK)/include/esp_system/port/soc \
						-I$(ESPRESSIF_SDK)/include/esp_system/port/public_compat -I$(ESPRESSIF_SDK)/include/esp32/include -I$(ESPRESSIF_SDK)/include/xtensa/include \
						-I$(ESPRESSIF_SDK)/include/xtensa/esp32/include -I$(ESPRESSIF_SDK)/include/driver/include -I$(ESPRESSIF_SDK)/include/driver/esp32/include \
						-I$(ESPRESSIF_SDK)/include/esp_pm/include -I$(ESPRESSIF_SDK)/include/esp_ringbuf/include -I$(ESPRESSIF_SDK)/include/efuse/include \
						-I$(ESPRESSIF_SDK)/include/efuse/esp32/include -I$(ESPRESSIF_SDK)/include/vfs/include -I$(ESPRESSIF_SDK)/include/esp_wifi/include \
						-I$(ESPRESSIF_SDK)/include/esp_event/include -I$(ESPRESSIF_SDK)/include/esp_netif/include -I$(ESPRESSIF_SDK)/include/esp_eth/include \
						-I$(ESPRESSIF_SDK)/include/tcpip_adapter/include -I$(ESPRESSIF_SDK)/include/esp_phy/include -I$(ESPRESSIF_SDK)/include/esp_phy/esp32/include \
						-I$(ESPRESSIF_SDK)/include/esp_ipc/include -I$(ESPRESSIF_SDK)/include/app_trace/include -I$(ESPRESSIF_SDK)/include/esp_timer/include \
						-I$(ESPRESSIF_SDK)/include/mbedtls/port/include -I$(ESPRESSIF_SDK)/include/mbedtls/mbedtls/include \
						-I$(ESPRESSIF_SDK)/include/mbedtls/esp_crt_bundle/include -I$(ESPRESSIF_SDK)/include/app_update/include \
						-I$(ESPRESSIF_SDK)/include/spi_flash/include -I$(ESPRESSIF_SDK)/include/bootloader_support/include \
						-I$(ESPRESSIF_SDK)/include/nvs_flash/include -I$(ESPRESSIF_SDK)/include/pthread/include -I$(ESPRESSIF_SDK)/include/esp_gdbstub/include \
						-I$(ESPRESSIF_SDK)/include/esp_gdbstub/xtensa -I$(ESPRESSIF_SDK)/include/esp_gdbstub/esp32 -I$(ESPRESSIF_SDK)/include/espcoredump/include \
						-I$(ESPRESSIF_SDK)/include/espcoredump/include/port/xtensa -I$(ESPRESSIF_SDK)/include/wpa_supplicant/include \
						-I$(ESPRESSIF_SDK)/include/wpa_supplicant/port/include -I$(ESPRESSIF_SDK)/include/wpa_supplicant/esp_supplicant/include \
						-I$(ESPRESSIF_SDK)/include/ieee802154/include -I$(ESPRESSIF_SDK)/include/console -I$(ESPRESSIF_SDK)/include/asio/asio/asio/include \
						-I$(ESPRESSIF_SDK)/include/asio/port/include -I$(ESPRESSIF_SDK)/include/bt/common/osi/include -I$(ESPRESSIF_SDK)/include/bt/include/esp32/include \
						-I$(ESPRESSIF_SDK)/include/bt/common/api/include/api -I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/blufi/include \
						-I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/include -I$(ESPRESSIF_SDK)/include/bt/host/bluedroid/api/include/api \
						-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_common/include -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_common/tinycrypt/include \
						-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core/include \
						-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core/storage -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/btc/include \
						-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/common/include -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/client/include \
						-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/server/include -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api/core/include \
						-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api/models/include -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api \
						-I$(ESPRESSIF_SDK)/include/cbor/port/include -I$(ESPRESSIF_SDK)/include/unity/include -I$(ESPRESSIF_SDK)/include/unity/unity/src \
						-I$(ESPRESSIF_SDK)/include/cmock/CMock/src -I$(ESPRESSIF_SDK)/include/coap/port/include -I$(ESPRESSIF_SDK)/include/coap/libcoap/include \
						-I$(ESPRESSIF_SDK)/include/nghttp/port/include -I$(ESPRESSIF_SDK)/include/nghttp/nghttp2/lib/includes -I$(ESPRESSIF_SDK)/include/esp-tls \
						-I$(ESPRESSIF_SDK)/include/esp-tls/esp-tls-crypto -I$(ESPRESSIF_SDK)/include/esp_adc_cal/include -I$(ESPRESSIF_SDK)/include/esp_hid/include \
						-I$(ESPRESSIF_SDK)/include/tcp_transport/include -I$(ESPRESSIF_SDK)/include/esp_http_client/include \
						-I$(ESPRESSIF_SDK)/include/esp_http_server/include -I$(ESPRESSIF_SDK)/include/esp_https_ota/include \
						-I$(ESPRESSIF_SDK)/include/esp_https_server/include -I$(ESPRESSIF_SDK)/include/esp_lcd/include -I$(ESPRESSIF_SDK)/include/esp_lcd/interface \
						-I$(ESPRESSIF_SDK)/include/protobuf-c/protobuf-c -I$(ESPRESSIF_SDK)/include/protocomm/include/common \
						-I$(ESPRESSIF_SDK)/include/protocomm/include/security -I$(ESPRESSIF_SDK)/include/protocomm/include/transports \
						-I$(ESPRESSIF_SDK)/include/mdns/include -I$(ESPRESSIF_SDK)/include/esp_local_ctrl/include -I$(ESPRESSIF_SDK)/include/sdmmc/include \
						-I$(ESPRESSIF_SDK)/include/esp_serial_slave_link/include -I$(ESPRESSIF_SDK)/include/esp_websocket_client/include \
						-I$(ESPRESSIF_SDK)/include/expat/expat/expat/lib -I$(ESPRESSIF_SDK)/include/expat/port/include \
						-I$(ESPRESSIF_SDK)/include/wear_levelling/include -I$(ESPRESSIF_SDK)/include/fatfs/diskio -I$(ESPRESSIF_SDK)/include/fatfs/vfs \
						-I$(ESPRESSIF_SDK)/include/fatfs/src -I$(ESPRESSIF_SDK)/include/freemodbus/freemodbus/common/include \
						-I$(ESPRESSIF_SDK)/include/idf_test/include -I$(ESPRESSIF_SDK)/include/idf_test/include/esp32 -I$(ESPRESSIF_SDK)/include/jsmn/include \
						-I$(ESPRESSIF_SDK)/include/json/cJSON -I$(ESPRESSIF_SDK)/include/libsodium/libsodium/src/libsodium/include \
						-I$(ESPRESSIF_SDK)/include/libsodium/port_include -I$(ESPRESSIF_SDK)/include/mqtt/esp-mqtt/include \
						-I$(ESPRESSIF_SDK)/include/openssl/include -I$(ESPRESSIF_SDK)/include/perfmon/include -I$(ESPRESSIF_SDK)/include/spiffs/include \
						-I$(ESPRESSIF_SDK)/include/ulp/include -I$(ESPRESSIF_SDK)/include/wifi_provisioning/include -I$(ESPRESSIF_SDK)/include/rmaker_common/include \
						-I$(ESPRESSIF_SDK)/include/json_parser/upstream/include -I$(ESPRESSIF_SDK)/include/json_parser/upstream \
						-I$(ESPRESSIF_SDK)/include/json_generator/upstream -I$(ESPRESSIF_SDK)/include/esp_schedule/include \
						-I$(ESPRESSIF_SDK)/include/esp_rainmaker/include -I$(ESPRESSIF_SDK)/include/gpio_button/button/include \
						-I$(ESPRESSIF_SDK)/include/qrcode/include -I$(ESPRESSIF_SDK)/include/ws2812_led -I$(ESPRESSIF_SDK)/include/esp_diagnostics/include \
						-I$(ESPRESSIF_SDK)/include/rtc_store/include -I$(ESPRESSIF_SDK)/include/esp_insights/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/dotprod/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/support/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/hann/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/blackman/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/blackman_harris/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/blackman_nuttall/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/nuttall/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/flat_top/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/iir/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/fir/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/add/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/sub/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/mul/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/addc/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/mulc/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/sqrt/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/matrix/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/fft/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/dct/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/conv/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/common/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/kalman/ekf/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/kalman/ekf_imu13states/include -I$(ESPRESSIF_SDK)/include/esp_littlefs/include \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include -I$(ESPRESSIF_SDK)/include/esp-dl/include/tool -I$(ESPRESSIF_SDK)/include/esp-dl/include/typedef \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/image -I$(ESPRESSIF_SDK)/include/esp-dl/include/math -I$(ESPRESSIF_SDK)/include/esp-dl/include/nn \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/layer -I$(ESPRESSIF_SDK)/include/esp-dl/include/detect \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/model_zoo -I$(ESPRESSIF_SDK)/include/esp-sr/src/include \
						-I$(ESPRESSIF_SDK)/include/esp-sr/esp-tts/esp_tts_chinese/include -I$(ESPRESSIF_SDK)/include/esp-sr/include/esp32 \
						-I$(ESPRESSIF_SDK)/include/esp32-camera/driver/include -I$(ESPRESSIF_SDK)/include/esp32-camera/conversions/include \
						-I$(ESPRESSIF_SDK)/include/fb_gfx/include \
						-I$(ESPRESSIF_SDK)/$(MEMORY_TYPE)/include

	ASFLAGS =	-mlongcalls -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable -Wno-error=deprecated-declarations \
				-Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings -fstack-protector -fstrict-volatile-bitfields \
				-Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion  -x assembler-with-cpp -MMD -c -w $(COMPILER_OPT_FLAGS)
	
	CFLAGS = -mlongcalls -Wno-frame-address -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
			 -Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings -fstack-protector \
			 -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion -std=gnu99 \
			 -Wno-old-style-declaration  -MMD -c -w $(COMPILER_OPT_FLAGS)
			 
	CXXFLAGS =	-mlongcalls -Wno-frame-address -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings -fstack-protector \
				-fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion -std=gnu++11 \
				-fexceptions -fno-rtti  -MMD -c -w $(COMPILER_OPT_FLAGS) 

	ELFLIBS =	-lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash \
				-lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth \
				-ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc \
				-lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lasio -lbt -lcbor \
				-lunity -lcmock -lcoap -lnghttp -lesp-tls -lesp_adc_cal -lesp_hid -ltcp_transport -lesp_http_client \
				-lesp_http_server -lesp_https_ota -lesp_https_server -lesp_lcd -lprotobuf-c -lprotocomm -lmdns -lesp_local_ctrl \
				-lsdmmc -lesp_serial_slave_link -lesp_websocket_client -lexpat -lwear_levelling -lfatfs -lfreemodbus -ljsmn \
				-ljson -llibsodium -lmqtt -lopenssl -lperfmon -lspiffs -lulp -lwifi_provisioning -lrmaker_common \
				-lesp_diagnostics -lrtc_store -lesp_insights -ljson_parser -ljson_generator -lesp_schedule \
				-lespressif__esp_secure_cert_mgr -lesp_rainmaker -lgpio_button -lqrcode -lws2812_led -lesp-sr -lesp32-camera \
				-lesp_littlefs -lespressif__esp-dsp -lfb_gfx -lasio -lcmock -lunity -lcoap -lesp_lcd -lesp_websocket_client \
				-lexpat -lfreemodbus -ljsmn -llibsodium -lperfmon -lesp_adc_cal -lesp_hid -lfatfs -lwear_levelling -lopenssl \
				-lesp_insights -lcbor -lesp_diagnostics -lrtc_store -lesp_rainmaker -lesp_local_ctrl -lesp_https_server \
				-lwifi_provisioning -lprotocomm -lbt -lbtdm_app -lprotobuf-c -lmdns -ljson_parser -ljson_generator -lesp_schedule \
				-lespressif__esp_secure_cert_mgr -lqrcode -lrmaker_common -lmqtt -lcat_face_detect -lhuman_face_detect \
				-lcolor_detect -lmfn -ldl -lmultinet -lesp_audio_processor -lesp_audio_front_end -lwakenet -lesp-sr \
				-lmultinet -lesp_audio_processor -lesp_audio_front_end -lwakenet -ljson -lspiffs -ldl_lib -lc_speech_features \
				-lwakeword_model -lmultinet2_ch -lesp_tts_chinese -lvoice_set_xiaole -lesp_ringbuf -lefuse -lesp_ipc -ldriver \
				-lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub \
				-lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event \
				-lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common \
				-lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client \
				-lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 \
				-lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc \
				-ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread \
				-lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter \
				-lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support\
				-lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport \
				-lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 \
				-lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf \
				-lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash \
				-lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter \
				-lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support \
				-lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport \
				-lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 \
				-lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi \
				-lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash \
				-lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth \
				-ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc \
				-lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls \
				-ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp \
				-lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi \
				-lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash \
				-lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth \
				-ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc \
				-lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls \
				-ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp \
				-lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi \
				-lphy -lrtc -lesp_phy -lphy -lrtc -lesp_phy -lphy -lrtc -lxt_hal -lm -lnewlib -lstdc++ -lpthread -lgcc \
				-lcxx -lapp_trace -lgcov -lapp_trace -lgcov -lc 

	ARFLAGS = cr
	
	ELFFLAGS =	-T esp32.rom.redefined.ld -T memory.ld -T sections.ld -T esp32.rom.ld -T esp32.rom.api.ld -T esp32.rom.libgcc.ld -T esp32.rom.newlib-data.ld \
				-T esp32.rom.syscalls.ld -T esp32.peripherals.ld  -mlongcalls -Wno-frame-address -Wl,--cref -Wl,--gc-sections -fno-rtti -fno-lto \
				-u ld_include_hli_vectors_bt -Wl,--wrap=esp_log_write -Wl,--wrap=esp_log_writev -Wl,--wrap=log_printf -u _Z5setupv -u _Z4loopv \
				-u esp_app_desc -u pthread_include_pthread_impl -u pthread_include_pthread_cond_impl -u pthread_include_pthread_local_storage_impl \
				-u pthread_include_pthread_rwlock_impl -u include_esp_phy_override -u ld_include_highint_hdl -u start_app -u start_app_other_cores \
				-u __ubsan_include -Wl,--wrap=longjmp -u __assert_func -u vfs_include_syscalls_impl -Wl,--undefined=uxTopUsedPriority -u app_main \
				-u newlib_include_heap_impl -u newlib_include_syscalls_impl -u newlib_include_pthread_impl -u newlib_include_assert_impl \
				-u __cxa_guard_dummy
				
	BUILD_EXTRA_FLAGS +=-DARDUINO_USB_CDC_ON_BOOT=0
endif #!ESP32

ifeq ($(MCU),esp32s2)
	CPREPROCESSOR_FLAGS = -DHAVE_CONFIG_H -DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\" -DUNITY_INCLUDE_CONFIG_H -DWITH_POSIX -D_GNU_SOURCE \
						-DIDF_VER=\"v4.4-4\" -DESP_PLATFORM -D_POSIX_READER_WRITER_LOCKS \
						-I$(ESPRESSIF_SDK)/include/config -I$(ESPRESSIF_SDK)/include/newlib/platform_include -I$(ESPRESSIF_SDK)/include/freertos/include \
						-I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions/freertos -I$(ESPRESSIF_SDK)/include/freertos/port/xtensa/include \
						-I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions -I$(ESPRESSIF_SDK)/include/esp_hw_support/include \
						-I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc -I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc/esp32s2 \
						-I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32s2 -I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32s2/private_include \
						-I$(ESPRESSIF_SDK)/include/heap/include -I$(ESPRESSIF_SDK)/include/log/include -I$(ESPRESSIF_SDK)/include/lwip/include/apps \
						-I$(ESPRESSIF_SDK)/include/lwip/include/apps/sntp -I$(ESPRESSIF_SDK)/include/lwip/lwip/src/include \
						-I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include -I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include/arch \
						-I$(ESPRESSIF_SDK)/include/soc/include -I$(ESPRESSIF_SDK)/include/soc/esp32s2 -I$(ESPRESSIF_SDK)/include/soc/esp32s2/include \
						-I$(ESPRESSIF_SDK)/include/hal/esp32s2/include -I$(ESPRESSIF_SDK)/include/hal/include -I$(ESPRESSIF_SDK)/include/hal/platform_port/include \
						-I$(ESPRESSIF_SDK)/include/esp_rom/include -I$(ESPRESSIF_SDK)/include/esp_rom/include/esp32s2 -I$(ESPRESSIF_SDK)/include/esp_rom/esp32s2 \
						-I$(ESPRESSIF_SDK)/include/esp_common/include -I$(ESPRESSIF_SDK)/include/esp_system/include -I$(ESPRESSIF_SDK)/include/esp_system/port/soc \
						-I$(ESPRESSIF_SDK)/include/esp_system/port/public_compat -I$(ESPRESSIF_SDK)/include/xtensa/include \
						-I$(ESPRESSIF_SDK)/include/xtensa/esp32s2/include -I$(ESPRESSIF_SDK)/include/driver/include \
						-I$(ESPRESSIF_SDK)/include/driver/esp32s2/include -I$(ESPRESSIF_SDK)/include/esp_pm/include -I$(ESPRESSIF_SDK)/include/esp_ringbuf/include \
						-I$(ESPRESSIF_SDK)/include/efuse/include -I$(ESPRESSIF_SDK)/include/efuse/esp32s2/include -I$(ESPRESSIF_SDK)/include/vfs/include \
						-I$(ESPRESSIF_SDK)/include/esp_wifi/include -I$(ESPRESSIF_SDK)/include/esp_event/include -I$(ESPRESSIF_SDK)/include/esp_netif/include \
						-I$(ESPRESSIF_SDK)/include/esp_eth/include -I$(ESPRESSIF_SDK)/include/tcpip_adapter/include \
						-I$(ESPRESSIF_SDK)/include/esp_phy/include -I$(ESPRESSIF_SDK)/include/esp_phy/esp32s2/include -I$(ESPRESSIF_SDK)/include/esp_ipc/include \
						-I$(ESPRESSIF_SDK)/include/app_trace/include -I$(ESPRESSIF_SDK)/include/esp_timer/include -I$(ESPRESSIF_SDK)/include/mbedtls/port/include \
						-I$(ESPRESSIF_SDK)/include/mbedtls/mbedtls/include -I$(ESPRESSIF_SDK)/include/mbedtls/esp_crt_bundle/include \
						-I$(ESPRESSIF_SDK)/include/app_update/include -I$(ESPRESSIF_SDK)/include/spi_flash/include \
						-I$(ESPRESSIF_SDK)/include/bootloader_support/include -I$(ESPRESSIF_SDK)/include/nvs_flash/include \
						-I$(ESPRESSIF_SDK)/include/pthread/include -I$(ESPRESSIF_SDK)/include/esp_gdbstub/include \
						-I$(ESPRESSIF_SDK)/include/esp_gdbstub/xtensa -I$(ESPRESSIF_SDK)/include/esp_gdbstub/esp32s2 \
						-I$(ESPRESSIF_SDK)/include/espcoredump/include -I$(ESPRESSIF_SDK)/include/espcoredump/include/port/xtensa \
						-I$(ESPRESSIF_SDK)/include/wpa_supplicant/include -I$(ESPRESSIF_SDK)/include/wpa_supplicant/port/include \
						-I$(ESPRESSIF_SDK)/include/wpa_supplicant/esp_supplicant/include -I$(ESPRESSIF_SDK)/include/ieee802154/include \
						-I$(ESPRESSIF_SDK)/include/console -I$(ESPRESSIF_SDK)/include/asio/asio/asio/include -I$(ESPRESSIF_SDK)/include/asio/port/include \
						-I$(ESPRESSIF_SDK)/include/cbor/port/include -I$(ESPRESSIF_SDK)/include/unity/include -I$(ESPRESSIF_SDK)/include/unity/unity/src \
						-I$(ESPRESSIF_SDK)/include/cmock/CMock/src -I$(ESPRESSIF_SDK)/include/coap/port/include -I$(ESPRESSIF_SDK)/include/coap/libcoap/include \
						-I$(ESPRESSIF_SDK)/include/nghttp/port/include -I$(ESPRESSIF_SDK)/include/nghttp/nghttp2/lib/includes -I$(ESPRESSIF_SDK)/include/esp-tls \
						-I$(ESPRESSIF_SDK)/include/esp-tls/esp-tls-crypto -I$(ESPRESSIF_SDK)/include/esp_adc_cal/include -I$(ESPRESSIF_SDK)/include/esp_hid/include \
						-I$(ESPRESSIF_SDK)/include/tcp_transport/include -I$(ESPRESSIF_SDK)/include/esp_http_client/include \
						-I$(ESPRESSIF_SDK)/include/esp_http_server/include -I$(ESPRESSIF_SDK)/include/esp_https_ota/include \
						-I$(ESPRESSIF_SDK)/include/esp_https_server/include -I$(ESPRESSIF_SDK)/include/esp_lcd/include -I$(ESPRESSIF_SDK)/include/esp_lcd/interface \
						-I$(ESPRESSIF_SDK)/include/protobuf-c/protobuf-c -I$(ESPRESSIF_SDK)/include/protocomm/include/common \
						-I$(ESPRESSIF_SDK)/include/protocomm/include/security -I$(ESPRESSIF_SDK)/include/protocomm/include/transports \
						-I$(ESPRESSIF_SDK)/include/mdns/include -I$(ESPRESSIF_SDK)/include/esp_local_ctrl/include -I$(ESPRESSIF_SDK)/include/sdmmc/include \
						-I$(ESPRESSIF_SDK)/include/esp_serial_slave_link/include -I$(ESPRESSIF_SDK)/include/esp_websocket_client/include \
						-I$(ESPRESSIF_SDK)/include/expat/expat/expat/lib -I$(ESPRESSIF_SDK)/include/expat/port/include\
						-I$(ESPRESSIF_SDK)/include/wear_levelling/include -I$(ESPRESSIF_SDK)/include/fatfs/diskio -I$(ESPRESSIF_SDK)/include/fatfs/vfs \
						-I$(ESPRESSIF_SDK)/include/fatfs/src -I$(ESPRESSIF_SDK)/include/freemodbus/freemodbus/common/include \
						-I$(ESPRESSIF_SDK)/include/idf_test/include -I$(ESPRESSIF_SDK)/include/idf_test/include/esp32s2 -I$(ESPRESSIF_SDK)/include/jsmn/include \
						-I$(ESPRESSIF_SDK)/include/json/cJSON -I$(ESPRESSIF_SDK)/include/libsodium/libsodium/src/libsodium/include \
						-I$(ESPRESSIF_SDK)/include/libsodium/port_include -I$(ESPRESSIF_SDK)/include/mqtt/esp-mqtt/include \
						-I$(ESPRESSIF_SDK)/include/openssl/include -I$(ESPRESSIF_SDK)/include/perfmon/include -I$(ESPRESSIF_SDK)/include/spiffs/include \
						-I$(ESPRESSIF_SDK)/include/usb/include -I$(ESPRESSIF_SDK)/include/touch_element/include -I$(ESPRESSIF_SDK)/include/ulp/include \
						-I$(ESPRESSIF_SDK)/include/wifi_provisioning/include -I$(ESPRESSIF_SDK)/include/rmaker_common/include \
						-I$(ESPRESSIF_SDK)/include/esp_diagnostics/include -I$(ESPRESSIF_SDK)/include/rtc_store/include \
						-I$(ESPRESSIF_SDK)/include/esp_insights/include -I$(ESPRESSIF_SDK)/include/json_parser/upstream/include \
						-I$(ESPRESSIF_SDK)/include/json_parser/upstream -I$(ESPRESSIF_SDK)/include/json_generator/upstream \
						-I$(ESPRESSIF_SDK)/include/esp_schedule/include -I$(ESPRESSIF_SDK)/include/espressif__esp_secure_cert_mgr/include \
						-I$(ESPRESSIF_SDK)/include/esp_rainmaker/include -I$(ESPRESSIF_SDK)/include/gpio_button/button/include \
						-I$(ESPRESSIF_SDK)/include/qrcode/include -I$(ESPRESSIF_SDK)/include/ws2812_led -I$(ESPRESSIF_SDK)/include/freertos/include/freertos \
						-I$(ESPRESSIF_SDK)/include/arduino_tinyusb/tinyusb/src -I$(ESPRESSIF_SDK)/include/arduino_tinyusb/include \
						-I$(ESPRESSIF_SDK)/include/esp_littlefs/include -I$(ESPRESSIF_SDK)/include/esp-dl/include -I$(ESPRESSIF_SDK)/include/esp-dl/include/tool \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/typedef -I$(ESPRESSIF_SDK)/include/esp-dl/include/image \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/math -I$(ESPRESSIF_SDK)/include/esp-dl/include/nn \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/layer -I$(ESPRESSIF_SDK)/include/esp-dl/include/detect \
						-I$(ESPRESSIF_SDK)/include/esp-dl/include/model_zoo -I$(ESPRESSIF_SDK)/include/esp-sr/esp-tts/esp_tts_chinese/include \
						-I$(ESPRESSIF_SDK)/include/esp32-camera/driver/include -I$(ESPRESSIF_SDK)/include/esp32-camera/conversions/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/dotprod/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/support/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/hann/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/blackman/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/blackman_harris/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/blackman_nuttall/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/nuttall/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/windows/flat_top/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/iir/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/fir/include -I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/add/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/sub/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/mul/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/addc/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/mulc/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/math/sqrt/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/matrix/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/fft/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/dct/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/conv/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/common/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/kalman/ekf/include \
						-I$(ESPRESSIF_SDK)/include/espressif__esp-dsp/modules/kalman/ekf_imu13states/include \
						-I$(ESPRESSIF_SDK)/include/fb_gfx/include \
						-I$(ESPRESSIF_SDK)/$(MEMORY_TYPE)/include

	ASFLAGS =	-mlongcalls -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable -Wno-error=deprecated-declarations \
				-Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings -fstack-protector -fstrict-volatile-bitfields \
				-Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion  -x assembler-with-cpp -MMD -c -w $(COMPILER_OPT_FLAGS)
	
	CFLAGS = -mlongcalls -Wno-frame-address -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
			 -Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings -fstack-protector \
			 -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion -std=gnu99 \
			 -Wno-old-style-declaration  -MMD -c -w $(COMPILER_OPT_FLAGS)
			 
	CXXFLAGS =	-mlongcalls -Wno-frame-address -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings -fstack-protector \
				-fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion -std=gnu++11 \
				-fexceptions -fno-rtti  -MMD -c -w $(COMPILER_OPT_FLAGS) 

	ELFLIBS =	-lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lasio -lcbor -lunity -lcmock -lcoap -lnghttp -lesp-tls -lesp_adc_cal -lesp_hid -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lesp_https_server -lesp_lcd -lprotobuf-c -lprotocomm -lmdns -lesp_local_ctrl -lsdmmc -lesp_serial_slave_link -lesp_websocket_client -lexpat -lwear_levelling -lfatfs -lfreemodbus -ljsmn -ljson -llibsodium -lmqtt -lopenssl -lperfmon -lspiffs -lusb -ltouch_element -lulp -lwifi_provisioning -lrmaker_common -lesp_diagnostics -lrtc_store -lesp_insights -ljson_parser -ljson_generator -lesp_schedule -lespressif__esp_secure_cert_mgr -lesp_rainmaker -lgpio_button -lqrcode -lws2812_led -lesp32-camera -lesp_littlefs -lespressif__esp-dsp -lfb_gfx -lasio -lcmock -lunity -lcoap -lesp_lcd -lesp_websocket_client -lexpat -lfreemodbus -ljsmn -llibsodium -lperfmon -lusb -ltouch_element -lesp_adc_cal -lesp_hid -lfatfs -lwear_levelling -lopenssl -lspiffs -lesp_insights -lcbor -lesp_diagnostics -lrtc_store -lesp_rainmaker -lesp_local_ctrl -lesp_https_server -lwifi_provisioning -lprotocomm -lprotobuf-c -lmdns -ljson -ljson_parser -ljson_generator -lesp_schedule -lespressif__esp_secure_cert_mgr -lqrcode -lrmaker_common -lmqtt -larduino_tinyusb -lcat_face_detect -lhuman_face_detect -lcolor_detect -lmfn -ldl -lesp_tts_chinese -lvoice_set_xiaole -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lphy -lesp_phy -lphy -lesp_phy -lphy -lxt_hal -lm -lnewlib -lstdc++ -lpthread -lgcc -lcxx -lapp_trace -lgcov -lapp_trace -lgcov -lc 

	ARFLAGS = cr
	
	ELFFLAGS =	-T memory.ld -T sections.ld -T esp32s2.rom.ld -T esp32s2.rom.api.ld -T esp32s2.rom.libgcc.ld -T esp32s2.rom.newlib-funcs.ld \
				-T esp32s2.rom.newlib-data.ld -T esp32s2.rom.spiflash.ld -T esp32s2.rom.newlib-time.ld -T esp32s2.peripherals.ld  -mlongcalls \
				-Wl,--cref -Wl,--gc-sections -fno-rtti -fno-lto -Wl,--wrap=esp_log_write -Wl,--wrap=esp_log_writev \
				-Wl,--wrap=log_printf -u _Z5setupv -u _Z4loopv -u esp_app_desc -u pthread_include_pthread_impl -u pthread_include_pthread_cond_impl \
				-u pthread_include_pthread_local_storage_impl -u pthread_include_pthread_rwlock_impl -u include_esp_phy_override \
				-u ld_include_highint_hdl -u start_app -u __ubsan_include -Wl,--wrap=longjmp -u __assert_func -u vfs_include_syscalls_impl \
				-Wl,--undefined=uxTopUsedPriority -u app_main -u newlib_include_heap_impl -u newlib_include_syscalls_impl \
				-u newlib_include_pthread_impl -u newlib_include_assert_impl -u __cxa_guard_dummy 
	BUILD_EXTRA_FLAGS +=-DARDUINO_USB_MODE=$($(ARDUINO_VARIANT).build.usb_mode) -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) \
						-DARDUINO_USB_MSC_ON_BOOT=$($(ARDUINO_VARIANT).build.msc_on_boot) -DARDUINO_USB_DFU_ON_BOOT=$($(ARDUINO_VARIANT).build.dfu_on_boot)
endif #end S2

ifeq ($(MCU),esp32s3)
	CPREPROCESSOR_FLAGS = -DHAVE_CONFIG_H -DMBEDTLS_CONFIG_FILE=mbedtls/esp_config.h -DUNITY_INCLUDE_CONFIG_H -DWITH_POSIX -D_GNU_SOURCE \
							-DIDF_VER=v4.4.4 -DESP_PLATFORM -D_POSIX_READER_WRITER_LOCKS  \
							-I$(ESPRESSIF_SDK)/include/config -I$(ESPRESSIF_SDK)/include/newlib/platform_include \
							-I$(ESPRESSIF_SDK)/include/freertos/include -I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions/freertos \
							-I$(ESPRESSIF_SDK)/include/freertos/port/xtensa/include -I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/include -I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc/esp32s3 -I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32s3 \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32s3/private_include -I$(ESPRESSIF_SDK)/include/heap/include \
							-I$(ESPRESSIF_SDK)/include/log/include -I$(ESPRESSIF_SDK)/include/lwip/include/apps -I$(ESPRESSIF_SDK)/include/lwip/include/apps/sntp \
							-I$(ESPRESSIF_SDK)/include/lwip/lwip/src/include -I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include \
							-I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include/arch -I$(ESPRESSIF_SDK)/include/soc/include \
							-I$(ESPRESSIF_SDK)/include/soc/esp32s3 -I$(ESPRESSIF_SDK)/include/soc/esp32s3/include \
							-I$(ESPRESSIF_SDK)/include/hal/esp32s3/include -I$(ESPRESSIF_SDK)/include/hal/include \
							-I$(ESPRESSIF_SDK)/include/hal/platform_port/include -I$(ESPRESSIF_SDK)/include/esp_rom/include \
							-I$(ESPRESSIF_SDK)/include/esp_rom/include/esp32s3 -I$(ESPRESSIF_SDK)/include/esp_rom/esp32s3 \
							-I$(ESPRESSIF_SDK)/include/esp_common/include -I$(ESPRESSIF_SDK)/include/esp_system/include \
							-I$(ESPRESSIF_SDK)/include/esp_system/port/soc -I$(ESPRESSIF_SDK)/include/esp_system/port/public_compat \
							-I$(ESPRESSIF_SDK)/include/xtensa/include -I$(ESPRESSIF_SDK)/include/xtensa/esp32s3/include \
							-I$(ESPRESSIF_SDK)/include/driver/include -I$(ESPRESSIF_SDK)/include/driver/esp32s3/include \
							-I$(ESPRESSIF_SDK)/include/esp_pm/include -I$(ESPRESSIF_SDK)/include/esp_ringbuf/include \
							-I$(ESPRESSIF_SDK)/include/efuse/include -I$(ESPRESSIF_SDK)/include/efuse/esp32s3/include \
							-I$(ESPRESSIF_SDK)/include/vfs/include -I$(ESPRESSIF_SDK)/include/esp_wifi/include \
							-I$(ESPRESSIF_SDK)/include/esp_event/include -I$(ESPRESSIF_SDK)/include/esp_netif/include \
							-I$(ESPRESSIF_SDK)/include/esp_eth/include -I$(ESPRESSIF_SDK)/include/tcpip_adapter/include \
							-I$(ESPRESSIF_SDK)/include/esp_phy/include -I$(ESPRESSIF_SDK)/include/esp_phy/esp32s3/include \
							-I$(ESPRESSIF_SDK)/include/esp_ipc/include -I$(ESPRESSIF_SDK)/include/app_trace/include \
							-I$(ESPRESSIF_SDK)/include/esp_timer/include -I$(ESPRESSIF_SDK)/include/mbedtls/port/include \
							-I$(ESPRESSIF_SDK)/include/mbedtls/mbedtls/include -I$(ESPRESSIF_SDK)/include/mbedtls/esp_crt_bundle/include \
							-I$(ESPRESSIF_SDK)/include/app_update/include -I$(ESPRESSIF_SDK)/include/spi_flash/include \
							-I$(ESPRESSIF_SDK)/include/bootloader_support/include -I$(ESPRESSIF_SDK)/include/nvs_flash/include \
							-I$(ESPRESSIF_SDK)/include/pthread/include -I$(ESPRESSIF_SDK)/include/esp_gdbstub/include \
							-I$(ESPRESSIF_SDK)/include/esp_gdbstub/xtensa -I$(ESPRESSIF_SDK)/include/esp_gdbstub/esp32s3 \
							-I$(ESPRESSIF_SDK)/include/espcoredump/include -I$(ESPRESSIF_SDK)/include/espcoredump/include/port/xtensa \
							-I$(ESPRESSIF_SDK)/include/wpa_supplicant/include -I$(ESPRESSIF_SDK)/include/wpa_supplicant/port/include \
							-I$(ESPRESSIF_SDK)/include/wpa_supplicant/esp_supplicant/include -I$(ESPRESSIF_SDK)/include/ieee802154/include \
							-I$(ESPRESSIF_SDK)/include/console -I$(ESPRESSIF_SDK)/include/asio/asio/asio/include \
							-I$(ESPRESSIF_SDK)/include/asio/port/include -I$(ESPRESSIF_SDK)/include/bt/common/osi/include \
							-I$(ESPRESSIF_SDK)/include/bt/include/esp32s3/include -I$(ESPRESSIF_SDK)/include/bt/common/api/include/api \
							-I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/blufi/include \
							-I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/include \
							-I$(ESPRESSIF_SDK)/include/bt/host/bluedroid/api/include/api \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_common/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_common/tinycrypt/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core/storage \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/btc/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/common/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/client/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/server/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api/core/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api/models/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api -I$(ESPRESSIF_SDK)/include/cbor/port/include \
							-I$(ESPRESSIF_SDK)/include/unity/include -I$(ESPRESSIF_SDK)/include/unity/unity/src \
							-I$(ESPRESSIF_SDK)/include/cmock/CMock/src -I$(ESPRESSIF_SDK)/include/coap/port/include \
							-I$(ESPRESSIF_SDK)/include/coap/libcoap/include -I$(ESPRESSIF_SDK)/include/nghttp/port/include \
							-I$(ESPRESSIF_SDK)/include/nghttp/nghttp2/lib/includes -I$(ESPRESSIF_SDK)/include/esp-tls \
							-I$(ESPRESSIF_SDK)/include/esp-tls/esp-tls-crypto -I$(ESPRESSIF_SDK)/include/esp_adc_cal/include \
							-I$(ESPRESSIF_SDK)/include/esp_hid/include -I$(ESPRESSIF_SDK)/include/tcp_transport/include \
							-I$(ESPRESSIF_SDK)/include/esp_http_client/include -I$(ESPRESSIF_SDK)/include/esp_http_server/include \
							-I$(ESPRESSIF_SDK)/include/esp_https_ota/include -I$(ESPRESSIF_SDK)/include/esp_https_server/include \
							-I$(ESPRESSIF_SDK)/include/esp_lcd/include -I$(ESPRESSIF_SDK)/include/esp_lcd/interface \
							-I$(ESPRESSIF_SDK)/include/protobuf-c/protobuf-c -I$(ESPRESSIF_SDK)/include/protocomm/include/common \
							-I$(ESPRESSIF_SDK)/include/protocomm/include/security -I$(ESPRESSIF_SDK)/include/protocomm/include/transports \
							-I$(ESPRESSIF_SDK)/include/mdns/include -I$(ESPRESSIF_SDK)/include/esp_local_ctrl/include \
							-I$(ESPRESSIF_SDK)/include/sdmmc/include -I$(ESPRESSIF_SDK)/include/esp_serial_slave_link/include \
							-I$(ESPRESSIF_SDK)/include/esp_websocket_client/include -I$(ESPRESSIF_SDK)/include/expat/expat/expat/lib \
							-I$(ESPRESSIF_SDK)/include/expat/port/include -I$(ESPRESSIF_SDK)/include/wear_levelling/include \
							-I$(ESPRESSIF_SDK)/include/fatfs/diskio -I$(ESPRESSIF_SDK)/include/fatfs/vfs \
							-I$(ESPRESSIF_SDK)/include/fatfs/src -I$(ESPRESSIF_SDK)/include/freemodbus/freemodbus/common/include \
							-I$(ESPRESSIF_SDK)/include/idf_test/include -I$(ESPRESSIF_SDK)/include/idf_test/include/esp32s3 \
							-I$(ESPRESSIF_SDK)/include/jsmn/include -I$(ESPRESSIF_SDK)/include/json/cJSON \
							-I$(ESPRESSIF_SDK)/include/libsodium/libsodium/src/libsodium/include \
							-I$(ESPRESSIF_SDK)/include/libsodium/port_include -I$(ESPRESSIF_SDK)/include/mqtt/esp-mqtt/include \
							-I$(ESPRESSIF_SDK)/include/openssl/include -I$(ESPRESSIF_SDK)/include/perfmon/include \
							-I$(ESPRESSIF_SDK)/include/spiffs/include -I$(ESPRESSIF_SDK)/include/usb/include \
							-I$(ESPRESSIF_SDK)/include/ulp/include -I$(ESPRESSIF_SDK)/include/wifi_provisioning/include \
							-I$(ESPRESSIF_SDK)/include/rmaker_common/include -I$(ESPRESSIF_SDK)/include/json_parser/upstream/include \
							-I$(ESPRESSIF_SDK)/include/json_parser/upstream -I$(ESPRESSIF_SDK)/include/json_generator/upstream \
							-I$(ESPRESSIF_SDK)/include/esp_schedule/include -I$(ESPRESSIF_SDK)/include/esp_rainmaker/include \
							-I$(ESPRESSIF_SDK)/include/gpio_button/button/include -I$(ESPRESSIF_SDK)/include/qrcode/include \
							-I$(ESPRESSIF_SDK)/include/ws2812_led -I$(ESPRESSIF_SDK)/include/esp_diagnostics/include \
							-I$(ESPRESSIF_SDK)/include/rtc_store/include -I$(ESPRESSIF_SDK)/include/esp_insights/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/dotprod/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/support/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/hann/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman_harris/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman_nuttall/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/nuttall/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/flat_top/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/iir/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/fir/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/add/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/sub/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/mul/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/addc/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/mulc/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/sqrt/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/matrix/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/fft/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/dct/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/conv/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/common/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/kalman/ekf/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/kalman/ekf_imu13states/include \
							-I$(ESPRESSIF_SDK)/include/freertos/include/freertos \
							-I$(ESPRESSIF_SDK)/include/arduino_tinyusb/tinyusb/src \
							-I$(ESPRESSIF_SDK)/include/arduino_tinyusb/include \
							-I$(ESPRESSIF_SDK)/include/esp_littlefs/include \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/tool \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/typedef \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/image \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/math \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/nn \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/layer \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/detect \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/model_zoo \
							-I$(ESPRESSIF_SDK)/include/esp-sr/src/include \
							-I$(ESPRESSIF_SDK)/include/esp-sr/esp-tts/esp_tts_chinese/include \
							-I$(ESPRESSIF_SDK)/include/esp-sr/include/esp32s3 \
							-I$(ESPRESSIF_SDK)/include/esp32-camera/driver/include \
							-I$(ESPRESSIF_SDK)/include/esp32-camera/conversions/include \
							-I$(ESPRESSIF_SDK)/include/fb_gfx/include \
							-I$(ESPRESSIF_SDK)/$(MEMORY_TYPE)/include

	ASFLAGS = -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable -Wno-error=deprecated-declarations \
				-Wno-unused-parameter -Wno-sign-compare -ggdb -O2 -Wwrite-strings -fstack-protector -fstrict-volatile-bitfields \
				-Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion  -x assembler-with-cpp -MMD -c	
	CFLAGS =	-mlongcalls -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings \
				-fstack-protector -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion \
				-std=gnu99 -Wno-old-style-declaration  -MMD -c
	
	CXXFLAGS =	-mlongcalls -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -freorder-blocks -Wwrite-strings \
				-fstack-protector -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion \
				-std=gnu++11 -fexceptions -fno-rtti  -MMD -c
				
	ELFLIBS =	-lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lasio -lbt -lcbor -lunity -lcmock -lcoap -lnghttp -lesp-tls -lesp_adc_cal -lesp_hid -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lesp_https_server -lesp_lcd -lprotobuf-c -lprotocomm -lmdns -lesp_local_ctrl -lsdmmc -lesp_serial_slave_link -lesp_websocket_client -lexpat -lwear_levelling -lfatfs -lfreemodbus -ljsmn -ljson -llibsodium -lmqtt -lopenssl -lperfmon -lspiffs -lusb -lulp -lwifi_provisioning -lrmaker_common -lesp_diagnostics -lrtc_store -lesp_insights -ljson_parser -ljson_generator -lesp_schedule -lespressif__esp_secure_cert_mgr -lesp_rainmaker -lgpio_button -lqrcode -lws2812_led -lesp-sr -lesp32-camera -lesp_littlefs -lespressif__esp-dsp -lfb_gfx -lasio -lcmock -lunity -lcoap -lesp_lcd -lesp_websocket_client -lexpat -lfreemodbus -ljsmn -llibsodium -lperfmon -lusb -lesp_adc_cal -lesp_hid -lfatfs -lwear_levelling -lopenssl -lesp_insights -lcbor -lesp_diagnostics -lrtc_store -lesp_rainmaker -lesp_local_ctrl -lesp_https_server -lwifi_provisioning -lprotocomm -lbt -lbtdm_app -lprotobuf-c -lmdns -ljson_parser -ljson_generator -lesp_schedule -lespressif__esp_secure_cert_mgr -lqrcode -lrmaker_common -lmqtt -larduino_tinyusb -lcat_face_detect -lhuman_face_detect -lcolor_detect -lmfn -ldl -lhufzip -lesp_audio_front_end -lesp_audio_processor -lmultinet -lwakenet -lesp-sr -lhufzip -lesp_audio_front_end -lesp_audio_processor -lmultinet -lwakenet -ljson -lspiffs -ldl_lib -lc_speech_features -lespressif__esp-dsp -lesp_tts_chinese -lvoice_set_xiaole -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lulp -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lphy -lbtbb -lesp_phy -lphy -lbtbb -lesp_phy -lphy -lbtbb -lxt_hal -lm -lnewlib -lstdc++ -lpthread -lgcc -lcxx -lapp_trace -lgcov -lapp_trace -lgcov -lc 

	ARFLAGS = cr
	
	ELFFLAGS = -T memory.ld -T sections.ld -T esp32s3.rom.ld -T esp32s3.rom.api.ld -T esp32s3.rom.libgcc.ld -T esp32s3.rom.newlib.ld \
				-T esp32s3.rom.version.ld -T esp32s3.rom.newlib-time.ld -T esp32s3.peripherals.ld  -mlongcalls -Wl,--cref -Wl,--gc-sections \
				-fno-rtti -fno-lto -Wl,--wrap=esp_log_write -Wl,--wrap=esp_log_writev -Wl,--wrap=log_printf -u _Z5setupv -u _Z4loopv -u esp_app_desc \
				-u pthread_include_pthread_impl -u pthread_include_pthread_cond_impl -u pthread_include_pthread_local_storage_impl \
				-u pthread_include_pthread_rwlock_impl -u include_esp_phy_override -u ld_include_highint_hdl -u start_app -u start_app_other_cores \
				-u __ubsan_include -Wl,--wrap=longjmp -u __assert_func -u vfs_include_syscalls_impl -Wl,--undefined=uxTopUsedPriority -u app_main \
				-u newlib_include_heap_impl -u newlib_include_syscalls_impl -u newlib_include_pthread_impl -u newlib_include_assert_impl -u __cxa_guard_dummy 

	BUILD_EXTRA_FLAGS +=-DARDUINO_USB_MODE=$($(ARDUINO_VARIANT).build.usb_mode) -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) \
						-DARDUINO_USB_MSC_ON_BOOT=$($(ARDUINO_VARIANT).build.msc_on_boot) -DARDUINO_USB_DFU_ON_BOOT=$($(ARDUINO_VARIANT).build.dfu_on_boot)
endif #!s3

ifeq ($(MCU),esp32c3)

	CPREPROCESSOR_FLAGS =	-DHAVE_CONFIG_H -DMBEDTLS_CONFIG_FILE=mbedtls/esp_config.h -DUNITY_INCLUDE_CONFIG_H \
							-DWITH_POSIX -D_GNU_SOURCE -DIDF_VER=v4.4.4 -DESP_PLATFORM -D_POSIX_READER_WRITER_LOCKS \
							-I$(ESPRESSIF_SDK)/include/config -I$(ESPRESSIF_SDK)/include/newlib/platform_include \
							-I$(ESPRESSIF_SDK)/include/freertos/include \
							-I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions/freertos \
							-I$(ESPRESSIF_SDK)/include/freertos/port/riscv/include -I$(ESPRESSIF_SDK)/include/freertos/include/esp_additions \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/include -I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc/esp32c3 -I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32c3 \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32c3/private_include -I$(ESPRESSIF_SDK)/include/heap/include \
							-I$(ESPRESSIF_SDK)/include/log/include -I$(ESPRESSIF_SDK)/include/lwip/include/apps \
							-I$(ESPRESSIF_SDK)/include/lwip/include/apps/sntp -I$(ESPRESSIF_SDK)/include/lwip/lwip/src/include \
							-I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include -I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include/arch \
							-I$(ESPRESSIF_SDK)/include/soc/include -I$(ESPRESSIF_SDK)/include/soc/esp32c3 \
							-I$(ESPRESSIF_SDK)/include/soc/esp32c3/include -I$(ESPRESSIF_SDK)/include/hal/esp32c3/include \
							-I$(ESPRESSIF_SDK)/include/hal/include -I$(ESPRESSIF_SDK)/include/hal/platform_port/include \
							-I$(ESPRESSIF_SDK)/include/esp_rom/include -I$(ESPRESSIF_SDK)/include/esp_rom/include/esp32c3 \
							-I$(ESPRESSIF_SDK)/include/esp_rom/esp32c3 -I$(ESPRESSIF_SDK)/include/esp_common/include \
							-I$(ESPRESSIF_SDK)/include/esp_system/include -I$(ESPRESSIF_SDK)/include/esp_system/port/soc \
							-I$(ESPRESSIF_SDK)/include/esp_system/port/include/riscv -I$(ESPRESSIF_SDK)/include/esp_system/port/public_compat \
							-I$(ESPRESSIF_SDK)/include/riscv/include -I$(ESPRESSIF_SDK)/include/driver/include \
							-I$(ESPRESSIF_SDK)/include/driver/esp32c3/include -I$(ESPRESSIF_SDK)/include/esp_pm/include \
							-I$(ESPRESSIF_SDK)/include/esp_ringbuf/include -I$(ESPRESSIF_SDK)/include/efuse/include \
							-I$(ESPRESSIF_SDK)/include/efuse/esp32c3/include -I$(ESPRESSIF_SDK)/include/vfs/include \
							-I$(ESPRESSIF_SDK)/include/esp_wifi/include -I$(ESPRESSIF_SDK)/include/esp_event/include \
							-I$(ESPRESSIF_SDK)/include/esp_netif/include -I$(ESPRESSIF_SDK)/include/esp_eth/include \
							-I$(ESPRESSIF_SDK)/include/tcpip_adapter/include -I$(ESPRESSIF_SDK)/include/esp_phy/include \
							-I$(ESPRESSIF_SDK)/include/esp_phy/esp32c3/include -I$(ESPRESSIF_SDK)/include/esp_ipc/include \
							-I$(ESPRESSIF_SDK)/include/app_trace/include -I$(ESPRESSIF_SDK)/include/esp_timer/include \
							-I$(ESPRESSIF_SDK)/include/mbedtls/port/include -I$(ESPRESSIF_SDK)/include/mbedtls/mbedtls/include \
							-I$(ESPRESSIF_SDK)/include/mbedtls/esp_crt_bundle/include -I$(ESPRESSIF_SDK)/include/app_update/include \
							-I$(ESPRESSIF_SDK)/include/spi_flash/include -I$(ESPRESSIF_SDK)/include/bootloader_support/include \
							-I$(ESPRESSIF_SDK)/include/nvs_flash/include -I$(ESPRESSIF_SDK)/include/pthread/include \
							-I$(ESPRESSIF_SDK)/include/esp_gdbstub/include -I$(ESPRESSIF_SDK)/include/esp_gdbstub/riscv \
							-I$(ESPRESSIF_SDK)/include/esp_gdbstub/esp32c3 -I$(ESPRESSIF_SDK)/include/espcoredump/include \
							-I$(ESPRESSIF_SDK)/include/espcoredump/include/port/riscv -I$(ESPRESSIF_SDK)/include/wpa_supplicant/include \
							-I$(ESPRESSIF_SDK)/include/wpa_supplicant/port/include -I$(ESPRESSIF_SDK)/include/wpa_supplicant/esp_supplicant/include \
							-I$(ESPRESSIF_SDK)/include/ieee802154/include -I$(ESPRESSIF_SDK)/include/console \
							-I$(ESPRESSIF_SDK)/include/asio/asio/asio/include -I$(ESPRESSIF_SDK)/include/asio/port/include \
							-I$(ESPRESSIF_SDK)/include/bt/common/osi/include -I$(ESPRESSIF_SDK)/include/bt/include/esp32c3/include \
							-I$(ESPRESSIF_SDK)/include/bt/common/api/include/api -I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/blufi/include \
							-I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/include -I$(ESPRESSIF_SDK)/include/bt/host/bluedroid/api/include/api \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_common/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_common/tinycrypt/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_core/storage -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/btc/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/common/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/client/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/mesh_models/server/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api/core/include -I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api/models/include \
							-I$(ESPRESSIF_SDK)/include/bt/esp_ble_mesh/api -I$(ESPRESSIF_SDK)/include/cbor/port/include \
							-I$(ESPRESSIF_SDK)/include/unity/include -I$(ESPRESSIF_SDK)/include/unity/unity/src\
							-I$(ESPRESSIF_SDK)/include/cmock/CMock/src -I$(ESPRESSIF_SDK)/include/coap/port/include \
							-I$(ESPRESSIF_SDK)/include/coap/libcoap/include -I$(ESPRESSIF_SDK)/include/nghttp/port/include \
							-I$(ESPRESSIF_SDK)/include/nghttp/nghttp2/lib/includes -I$(ESPRESSIF_SDK)/include/esp-tls \
							-I$(ESPRESSIF_SDK)/include/esp-tls/esp-tls-crypto -I$(ESPRESSIF_SDK)/include/esp_adc_cal/include \
							-I$(ESPRESSIF_SDK)/include/esp_hid/include -I$(ESPRESSIF_SDK)/include/tcp_transport/include \
							-I$(ESPRESSIF_SDK)/include/esp_http_client/include -I$(ESPRESSIF_SDK)/include/esp_http_server/include \
							-I$(ESPRESSIF_SDK)/include/esp_https_ota/include -I$(ESPRESSIF_SDK)/include/esp_https_server/include \
							-I$(ESPRESSIF_SDK)/include/esp_lcd/include -I$(ESPRESSIF_SDK)/include/esp_lcd/interface \
							-I$(ESPRESSIF_SDK)/include/protobuf-c/protobuf-c -I$(ESPRESSIF_SDK)/include/protocomm/include/common \
							-I$(ESPRESSIF_SDK)/include/protocomm/include/security -I$(ESPRESSIF_SDK)/include/protocomm/include/transports \
							-I$(ESPRESSIF_SDK)/include/mdns/include -I$(ESPRESSIF_SDK)/include/esp_local_ctrl/include \
							-I$(ESPRESSIF_SDK)/include/sdmmc/include -I$(ESPRESSIF_SDK)/include/esp_serial_slave_link/include \
							-I$(ESPRESSIF_SDK)/include/esp_websocket_client/include -I$(ESPRESSIF_SDK)/include/expat/expat/expat/lib \
							-I$(ESPRESSIF_SDK)/include/expat/port/include -I$(ESPRESSIF_SDK)/include/wear_levelling/include \
							-I$(ESPRESSIF_SDK)/include/fatfs/diskio -I$(ESPRESSIF_SDK)/include/fatfs/vfs \
							-I$(ESPRESSIF_SDK)/include/fatfs/src -I$(ESPRESSIF_SDK)/include/freemodbus/freemodbus/common/include \
							-I$(ESPRESSIF_SDK)/include/idf_test/include -I$(ESPRESSIF_SDK)/include/idf_test/include/esp32c3 \
							-I$(ESPRESSIF_SDK)/include/jsmn/include -I$(ESPRESSIF_SDK)/include/json/cJSON \
							-I$(ESPRESSIF_SDK)/include/libsodium/libsodium/src/libsodium/include \
							-I$(ESPRESSIF_SDK)/include/libsodium/port_include -I$(ESPRESSIF_SDK)/include/mqtt/esp-mqtt/include \
							-I$(ESPRESSIF_SDK)/include/openssl/include -I$(ESPRESSIF_SDK)/include/spiffs/include \
							-I$(ESPRESSIF_SDK)/include/wifi_provisioning/include -I$(ESPRESSIF_SDK)/include/rmaker_common/include \
							-I$(ESPRESSIF_SDK)/include/json_parser/upstream/include -I$(ESPRESSIF_SDK)/include/json_parser/upstream \
							-I$(ESPRESSIF_SDK)/include/json_generator/upstream -I$(ESPRESSIF_SDK)/include/esp_schedule/include \
							-I$(ESPRESSIF_SDK)/include/esp_rainmaker/include -I$(ESPRESSIF_SDK)/include/gpio_button/button/include \
							-I$(ESPRESSIF_SDK)/include/qrcode/include -I$(ESPRESSIF_SDK)/include/ws2812_led \
							-I$(ESPRESSIF_SDK)/include/esp_diagnostics/include -I$(ESPRESSIF_SDK)/include/rtc_store/include \
							-I$(ESPRESSIF_SDK)/include/esp_insights/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/dotprod/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/support/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/hann/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman_harris/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman_nuttall/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/nuttall/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/flat_top/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/iir/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/fir/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/add/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/sub/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/mul/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/addc/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/mulc/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/sqrt/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/matrix/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/fft/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/dct/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/conv/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/common/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/kalman/ekf/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/kalman/ekf_imu13states/include \
							-I$(ESPRESSIF_SDK)/include/esp_littlefs/include -I$(ESPRESSIF_SDK)/include/esp-dl/include \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/tool -I$(ESPRESSIF_SDK)/include/esp-dl/include/typedef \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/image -I$(ESPRESSIF_SDK)/include/esp-dl/include/math \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/nn -I$(ESPRESSIF_SDK)/include/esp-dl/include/layer \
							-I$(ESPRESSIF_SDK)/include/esp-dl/include/detect -I$(ESPRESSIF_SDK)/include/esp-dl/include/model_zoo \
							-I$(ESPRESSIF_SDK)/include/esp-sr/esp-tts/esp_tts_chinese/include \
							-I$(ESPRESSIF_SDK)/include/esp32-camera/driver/include -I$(ESPRESSIF_SDK)/include/esp32-camera/conversions/include \
							-I$(ESPRESSIF_SDK)/include/fb_gfx/include \
							-I$(ESPRESSIF_SDK)/$(MEMORY_TYPE)/include


	ASFLAGS =	-ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb \
				-Wno-error=format= -nostartfiles -Wno-format -freorder-blocks -Wwrite-strings \
				-fstack-protector -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables \
				-fno-tree-switch-conversion  -x assembler-with-cpp -MMD -c
	
	CFLAGS =	-march=rv32imc -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb \
				-Wno-error=format= -nostartfiles -Wno-format -freorder-blocks -Wwrite-strings \
				-fstack-protector -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables \
				-fno-tree-switch-conversion -std=gnu99 -Wno-old-style-declaration  -MMD -c
	
	CXXFLAGS =	-march=rv32imc -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb \
				-Wno-error=format= -nostartfiles -Wno-format -freorder-blocks -Wwrite-strings \
				-fstack-protector -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable \
				-fno-jump-tables -fno-tree-switch-conversion -std=gnu++11 -fexceptions -fno-rtti  -MMD -c

	ELFLIBS =	-lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lasio -lbt -lcbor -lunity -lcmock -lcoap -lnghttp -lesp-tls -lesp_adc_cal -lesp_hid -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lesp_https_server -lesp_lcd -lprotobuf-c -lprotocomm -lmdns -lesp_local_ctrl -lsdmmc -lesp_serial_slave_link -lesp_websocket_client -lexpat -lwear_levelling -lfatfs -lfreemodbus -ljsmn -ljson -llibsodium -lmqtt -lopenssl -lspiffs -lwifi_provisioning -lrmaker_common -lesp_diagnostics -lrtc_store -lesp_insights -ljson_parser -ljson_generator -lesp_schedule -lespressif__esp_secure_cert_mgr -lesp_rainmaker -lgpio_button -lqrcode -lws2812_led -lesp32-camera -lesp_littlefs -lespressif__esp-dsp -lfb_gfx -lasio -lcmock -lunity -lcoap -lesp_lcd -lesp_websocket_client -lexpat -lfreemodbus -ljsmn -llibsodium -lesp_adc_cal -lesp_hid -lfatfs -lwear_levelling -lopenssl -lspiffs -lesp_insights -lcbor -lesp_diagnostics -lrtc_store -lesp_rainmaker -lesp_local_ctrl -lesp_https_server -lwifi_provisioning -lprotocomm -lbt -lbtdm_app -lprotobuf-c -lmdns -ljson -ljson_parser -ljson_generator -lesp_schedule -lespressif__esp_secure_cert_mgr -lqrcode -lrmaker_common -lmqtt -lcat_face_detect -lhuman_face_detect -lcolor_detect -lmfn -ldl -lesp_tts_chinese -lvoice_set_xiaole -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -lconsole -llwip -llog -lheap -lsoc -lesp_hw_support -lriscv -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lnghttp -lesp-tls -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lsdmmc -lesp_serial_slave_link -lmbedtls_2 -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi -lphy -lbtbb -lesp_phy -lphy -lbtbb -lesp_phy -lphy -lbtbb -lm -lnewlib -lstdc++ -lpthread -lgcc -lcxx -lapp_trace -lgcov -lapp_trace -lgcov -lc 

	ARFLAGS = cr
	
	ELFFLAGS =	-T memory.ld -T sections.ld -T esp32c3.rom.ld -T esp32c3.rom.api.ld -T esp32c3.rom.libgcc.ld -T esp32c3.rom.newlib.ld \
				-T esp32c3.rom.version.ld -T esp32c3.rom.newlib-time.ld -T esp32c3.rom.eco3.ld -T esp32c3.peripherals.ld  -nostartfiles \
				-march=rv32imc --specs=nosys.specs -Wl,--cref -Wl,--gc-sections -fno-rtti -fno-lto -Wl,--wrap=esp_log_write \
				-Wl,--wrap=esp_log_writev -Wl,--wrap=log_printf -u _Z5setupv -u _Z4loopv -u esp_app_desc -u pthread_include_pthread_impl \
				-u pthread_include_pthread_cond_impl -u pthread_include_pthread_local_storage_impl -u pthread_include_pthread_rwlock_impl \
				-u include_esp_phy_override -u start_app -u __ubsan_include -u __assert_func -u vfs_include_syscalls_impl \
				-Wl,--undefined=uxTopUsedPriority -u app_main -u newlib_include_heap_impl -u newlib_include_syscalls_impl \
				-u newlib_include_pthread_impl -u newlib_include_assert_impl -u __cxa_guard_dummy

	BUILD_EXTRA_FLAGS +=-DARDUINO_USB_MODE=1 -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) 
endif #!s3



#-DARDUINO_USB_CDC_ON_BOOT=0

CC := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-gcc
CXX := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-g++
AR := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-ar
AS := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-as
LD := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-g++
OBJDUMP := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-objdump
SIZE := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-size

OBJCOPY_BIN_PATTERN = --chip $(MCU) elf2image --flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) --flash_size $(FLASH_SIZE) \
	--elf-sha256-offset 0xb0 -o $(BUILD_OUT)/$(TARGET).bin $(BUILD_OUT)/$(TARGET).elf


OBJCOPY_PARTITION_PATTERN = $(ARDUINO_HOME)/tools/gen_esp32part.py -q $(BUILD_OUT)/partitions.csv $(BUILD_OUT)/$(TARGET).partitions.bin
PREBUILD1_PATTERN = bash -c "[ ! -f ./partitions.csv ] || cp -f ./partitions.csv $(BUILD_OUT)/partitions.csv"
PREBUILD2_PATTERN = bash -c "[ -f $(BUILD_OUT)/partitions.csv ] || [ ! -f $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv ] || cp $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv $(BUILD_OUT)/partitions.csv"
PREBUILD3_PATTERN = bash -c "[ -f $(BUILD_OUT)/partitions.csv ] || cp $(ARDUINO_HOME)/tools/partitions/$(PARTITIONS).csv $(BUILD_OUT)/partitions.csv"

C_COMBINE_PATTERN = -Wl,--Map=$(BUILD_OUT)/map.map -L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/ld \
					-L$(ESPRESSIF_SDK)/$(MEMORY_TYPE) \
					$(ELFFLAGS) -D$(BUILD_EXTRA_FLAGS) \
					-Wl,--start-group $(OBJ_FILES) $(LIB_OBJ_FILES) $(BUILD_OUT)/core/core.a \
					$(ELFLIBS) -Wl,--end-group -Wl,-EL 

SIZE_REGEX_DATA =  '^(?:\.dram0\.data|\.dram0\.bss)\s+([0-9]+).*'
SIZE_REGEX = '^(?:\.iram0\.text|\.dram0\.text|\.flash\.text|\.dram0\.data|\.flash\.rodata)\s+([0-9]+).*'
UPLOAD_SPEED ?= 115200
UPLOAD_PATTERN = --chip $(MCU) --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED)  --before default_reset --after hard_reset write_flash -z \
	--flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) \
	--flash_size detect 0xe000 $(ARDUINO_HOME)/tools/partitions/boot_app0.bin 0x1000  \
	$(ARDUINO_HOME)/tools/sdk/bin/bootloader_$(BOOT)_$(FLASH_FREQ).bin 0x10000 \
	$(BUILD_OUT)/$(TARGET).bin 0X8000 $(BUILD_OUT)/$(TARGET).partitions.bin  
# WARNING : NOT TESTED TODO : TEST
RESET_PATTERN = --chip $(MCU) --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED)  --before default_reset 

.PHONY: all dirs clean upload fs upload_fs

all: dirs prebuild sketch libs core bin size

show_variables:
	$(info [ARDUINO_LIBS] : $(ARDUINO_LIBS))
	$(info [USER_LIBS] : $(USER_LIBS))

dirs:
	@mkdir -p $(CORE_DIRS)
	@mkdir -p $(BUILD_OUT)/libraries

clean:
	rm -rf $(BUILD_OUT)

uclean:
	@find $(BUILD_OUT) -maxdepth 1 -type f -exec rm -f {} \;

core: dirs $(BUILD_OUT)/core/core.a

sketch: show_variables dirs $(OBJ_FILES)

libs: dirs $(LIB_OBJ_FILES)

bin: $(BUILD_OUT)/$(TARGET).bin

VTABLE_FLAGS=-DVTABLES_IN_FLASH

$(BUILD_OUT)/core/%.S.o: $(ARDUINO_HOME)/cores/esp32/%.S
	$(CC) $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(DEFINES) $(CORE_INC:%=-I%) -o $@ $<

$(BUILD_OUT)/core/core.a: $(CORE_OBJS)
	@echo Creating core archive...
	$(AR) $(ARFLAGS) $@ $(CORE_OBJS)

$(BUILD_OUT)/core/%.c.o: %.c
	$(CC) $(CORE_DEFINE) $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(DEFINES) $(CORE_INC:%=-I%) -o $@ $<

$(BUILD_OUT)/core/%.cpp.o: %.cpp
	$(CXX) $(CORE_DEFINE) $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(DEFINES) $(CORE_INC:%=-I%)  $< -o $@

$(BUILD_OUT)/libraries/%.c.o: %.c
	$(CC) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(DEFINES)  $(INCLUDES) -o $@ $<

$(BUILD_OUT)/libraries/%.cpp.o: %.cpp
	$(CXX) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) $< -o $@	

$(BUILD_OUT)/libraries/%.S.o: %.S
	$(CC) $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(DEFINES) $(USER_DEFINE) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.c.o: %.c
	$(CC) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.cpp.o: %.cpp
	$(CXX) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) $< -o $@	

$(BUILD_OUT)/%.S.o: %.S
	$(CC) $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(DEFINES) $(USER_DEFINE) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.ino.cpp: $(USER_INOSRC)
ifeq ($(CONCATENATE_USER_FILES), yes)
	-$(CAT) $(TARGET).ino $(filter-out $(TARGET).ino,$^) > $@
else
	ln -s ../$(TARGET).ino $@
endif

$(BUILD_OUT)/%.ino.cpp.o: $(BUILD_OUT)/%.ino.cpp
	$(CXX) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) $< -o $@

$(BUILD_OUT)/$(TARGET).elf: sketch core libs
	$(LD) $(C_COMBINE_PATTERN) -o $@ 

size: $(BUILD_OUT)/$(TARGET).elf
	@$(SIZE) -A $(BUILD_OUT)/$(TARGET).elf | perl -e "$$MEM_USAGE" $(SIZE_REGEX) $(SIZE_REGEX_DATA)

$(BUILD_OUT)/$(TARGET).bin: $(BUILD_OUT)/$(TARGET).elf
	$(PYTHON) $(ESPTOOL) $(OBJCOPY_BIN_PATTERN)
	@sha256sum $(BUILD_OUT)/$(TARGET).bin > $(BUILD_OUT)/$(TARGET).sha

reset: 
	$(PYTHON) $(ESPTOOL) $(RESET_PATTERN)

upload: $(BUILD_OUT)/$(TARGET).bin size
	$(PYTHON) $(ESPTOOL) --chip $(MCU) --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) $(UPLOAD_FLAGS) --before default_reset --after hard_reset write_flash -z --flash_mode $(FLASH_MODE) \
		--flash_freq $(FLASH_FREQ) --flash_size detect 0xe000 $(ARDUINO_HOME)/tools/partitions/boot_app0.bin  $($(ARDUINO_VARIANT).build.bootloader_addr) $(BUILD_OUT)/$(TARGET).bootloader.bin 0x10000 $(BUILD_OUT)/$(TARGET).bin \
		0x8000 $(BUILD_OUT)/$(TARGET).partitions.bin $($(ARDUINO_VARIANT).upload.extra_flags)
erase:
	$(PYTHON) $(UPLOADTOOL) --chip $(MCU) --port $(SERIAL_PORT) erase_flash

fs:
ifneq ($(strip $(FS_FILES)),)
	@rm -f $(FS_IMAGE)
	@mkdir -p $(BUILD_OUT)/spiffs
	$(MKSPIFFS) $(MKSPIFFS_PATTERN)
endif

prebuild:
	@test ! -f $(USRCDIRS)/build_opt.h || cp  $(USRCDIRS)/build_opt.h $(BUILD_OUT)
	@test ! -f $(USRCDIRS)/partitions.csv || cp  $(USRCDIRS)/partitions.csv $(BUILD_OUT)
	@test -f $(BUILD_OUT)/partitions.csv || test ! -f $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv || cp $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv $(BUILD_OUT)
	@test -f $(BUILD_OUT)/partitions.csv || cp $(ARDUINO_HOME)/tools/partitions/default.csv $(BUILD_OUT)/partitions.csv
	@test ! -f $(USRCDIRS)/bootloader.bin || cp  $(USRCDIRS)/bootloader.bin $(BUILD_OUT)/$(TARGET).ino.bootloader.bin
	@test -f $(BUILD_OUT)/bootloader.bin || test ! -f $(ARDUINO_HOME)/variants/$(VARIANT)/bootloader.bin || cp $(ARDUINO_HOME)/variants/$(VARIANT)/bootloader.bin $(BUILD_OUT)/$(TARGET).ino.bootloader.bin
	@test -f $(BUILD_OUT)/bootloader.bin || $(PYTHON) $(ESPTOOL) --chip $(MCU) elf2image --flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) \
	--flash_size $(FLASH_SIZE) -o $(BUILD_OUT)/$(TARGET).ino.bootloader.bin $(ARDUINO_HOME)/tools/sdk/$(MCU)/bin/bootloader_$(FLASH_MODE)_$(FLASH_FREQ).elf  
	@test ! -f $(USRCDIRS)/build_opt.h || cp  $(USRCDIRS)/build_opt.h $(BUILD_OUT)
	@test -f $(USRCDIRS)/build_opt.h || touch $(BUILD_OUT)/build_opt.h

upload_fs: fs
	@echo TODO upload_fs : No SPIFFS function available for $(ARDUINO_ARCH)

ota_fs: fs
	$(ESPOTA) -i $(OTA_IP) -p $(OTA_PORT) -a $(OTA_AUTH) --spiffs -f $(FS_IMAGE)

ota: $(BUILD_OUT)/$(TARGET).bin
	$(ESPOTA) -i $(OTA_IP) -p $(OTA_PORT) -a $(OTA_AUTH) -f $(BUILD_OUT)/$(TARGET).bin

term:
ifeq ($(LOG_SERIAL_TO_FILE), yes)
	minicom -D $(SERIAL_PORT) -b $(SERIAL_BAUD) -C serial.log
else
	minicom -D $(SERIAL_PORT) -b $(SERIAL_BAUD)
endif

monitor:
ifeq ($(LOG_SERIAL_TO_FILE), yes)
	minicom -D $(SERIAL_PORT) -b $(SERIAL_BAUD) -C serial.log
else
	minicom -D $(SERIAL_PORT) -b $(SERIAL_BAUD)
endif

print-%: ; @echo $* = $($*)

help:
	@echo ""
	@echo "Makefile for building Arduino esp8266 and esp32 projects"
	@echo "This file must be included from anaothe Makefile (see README)"
	@echo ""
	@echo "Targets available:"
	@echo "  all                  (default) Build the application"
	@echo "  clean                Remove all intermediate build files"
	@echo "  uclean               Remove all intermediate build files except core"
	@echo "  sketch               Build sketch files"
	@echo "  fs                   Build SPIFFS file"
	@echo "  upload               Build and flash the project application"
	@echo "  upload_fs            Build and flash SPIFFS file"
	@echo "  ota                  Build and flash via OTA"
	@echo "                          Params: OAT_IP, OTA_PORT and OTA_AUTH"
	@echo "  ota_fs               Build and flash filesystem via OTA"
	@echo "                          Params: OAT_IP, OTA_PORT and OTA_AUTH"
	@echo "  term/monitor         Open a the serial console on ESP port"
	@echo "  reset                Reset the board"
	@echo "  print-VAR            Display the makefile VAR content. Replace VAR by the variable name"
	@echo ""

-include $(OBJ_FILES:.o=.d)
-include $(LIB_OBJ_FILES:.o=.d)

define MEM_USAGE
$$fp = shift;
$$rp = shift;
while (<>) {
  $$r += $$1 if /$$rp/;
  $$f += $$1 if /$$fp/;
}
print "\nMemory usage\n";
print sprintf("  %-6s %6d bytes\n" x 2 ."\n", "Ram:", $$r, "Flash:", $$f);
endef
export MEM_USAGE