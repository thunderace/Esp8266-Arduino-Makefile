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

#DUMMY := $(shell $(ROOT_DIR)/bin/generate_platform.sh $(ARDUINO_HOME)/platform.txt $(ROOT_DIR)/bin/$(ARDUINO_ARCH)/platform.txt)
#runtime.platform.path = $(ARDUINO_HOME)
#include $(ROOT_DIR)/bin/$(ARDUINO_ARCH)/platform.txt

SERIAL_PORT ?= /dev/tty.nodemcu
ARDUINO_ARCH ?= esp8266
ifeq ($(ARDUINO_ARCH),esp8266)
	ESP8266_VERSION?=3.0.2
else
	ESP8266_VERSION ?= 2.0.0
endif

OTA_PORT ?= 8266

word-dot = $(word $2,$(subst ., ,$1))
NUM_ESP8266_VERSION = $(call word-dot,$(ESP8266_VERSION),1)$(call word-dot,$(ESP8266_VERSION),2)$(call word-dot,$(ESP8266_VERSION),3)
ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git))
	ESP8266_V3=true
else
	compareint = $(shell if [ $(1) -ge $(2) ] ; then echo ge ; else echo lt ; fi)
	ifeq ($(call compareint,$(NUM_ESP8266_VERSION),300),ge)
		ESP8266_V3=true
	else
		ESP8266_V3=false
	endif
endif

ARDUINO_HOME ?=  $(ROOT_DIR)/$(ARDUINO_ARCH)-$(ESP8266_VERSION)

ARDUINO_VARIANT ?= nodemcu
ARDUINO_VERSION ?= 10805

BOARDS_TXT  = $(ARDUINO_HOME)/boards.txt
PLATFORM_TXT  = $(ARDUINO_HOME)/platform.txt
include $(BOARDS_TXT)

ARDUINO_BOARD = $($(ARDUINO_VARIANT).build.board)
VARIANT = $($(ARDUINO_VARIANT).build.variant)
CONCATENATE_USER_FILES ?= no
FLASH_PARTITION ?= 4M1M

MCU = $($(ARDUINO_VARIANT).build.mcu)
SERIAL_BAUD   ?= 115200
ifeq ($(ARDUINO_ARCH),esp8266)
	CPU_FREQ ?= 80
	DEFAULT_FLASH_FREQ = 40
	FLASH_FREQ ?= $($(ARDUINO_VARIANT).build.flash_freq)
	ifeq ($(FLASH_FREQ),)
		FLASH_FREQ = $(DEFAULT_FLASH_FREQ)
	endif
else
	CPU_FREQ ?= 40
	FLASH_FREQ ?= $($(ARDUINO_VARIANT).menu.FlashFreq.$(CPU_FREQ).build.flash_freq)
endif

FLASH_MODE ?= $($(ARDUINO_VARIANT).build.flash_mode)
ifeq ($(FLASH_MODE),)
	FLASH_MODE = qio
endif

UPLOAD_RESETMETHOD ?= $($(ARDUINO_VARIANT).upload.resetmethod)
UPLOAD_SPEED ?= $($(ARDUINO_VARIANT).upload.speed)
ifeq ($(UPLOAD_SPEED),)
	UPLOAD_SPEED = 115200
endif

FLASH_LD ?= $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).build.flash_ld)

#ifeq ($(FLASH_LD),)
	#directly select the ld file from FLASH_PARTITION
#	FLASH_LD := eagle.flash.$(shell echo $(FLASH_PARTITION) | tr '[:upper:]' '[:lower:]').ld
#endif

ifeq ($(ESP8266_V3), true)
	MMU_SIZE ?= 3232
	MMU_FLAGS = $($(ARDUINO_VARIANT).menu.mmu.$(MMU_SIZE).build.mmuflags)
	NON32XFER ?=fast
	NON32XFER_FLAGS = $($(ARDUINO_VARIANT).menu.non32xfer.$(NON32XFER).build.non32xferflags)
	STDCPP_LEVEL = gnu++17
	STDC_LEVEL=gnu17
	STACKSMASH ?=disabled
	STACKSMASH_FLAGS = $($(ARDUINO_VARIANT).menu.stacksmash.$(STACKSMASH).build.stacksmash_flags)
else
	STDCPP_LEVEL = gnu++11
	STDC_LEVEL=gnu99
endif
SSL ?= basic
SSL_FLAGS = $($(ARDUINO_VARIANT).menu.ssl.$(SSL).build.sslflags)

ifeq ($(ARDUINO_ARCH),esp8266)
	F_CPU = $($(ARDUINO_VARIANT).menu.xtal.$(CPU_FREQ).build.f_cpu)
	FLASH_SIZE ?= $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).build.flash_size)
	SPIFFS_PAGESIZE ?= $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).build.spiffs_pagesize)
	SPIFFS_START ?= $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).build.spiffs_start)
	SPIFFS_END ?= $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).build.spiffs_end)
	SPIFFS_BLOCKSIZE ?= $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).build.spiffs_blocksize)
	UPLOAD_MAXIMUM_SIZE ?=  $($(ARDUINO_VARIANT).menu.eesz.$(FLASH_PARTITION).upload.maximum_size) 
	UPLOAD_ERASE_CMD ?= $($(ARDUINO_VARIANT).upload.erase_cmd)
	FLASH_FLAG ?= $($(ARDUINO_VARIANT).build.flash_flags)
	ifeq ($(FLASH_FLAG),) # for generic boards
		FLASH_FLAG = $($(ARDUINO_VARIANT).menu.FlashMode.$(FLASH_MODE).build.flash_flags)
	endif
	LWIP_VARIANT ?= lm2f
	LWIP_FLAGS ?= $($(ARDUINO_VARIANT).menu.ip.$(LWIP_VARIANT).build.lwip_flags)
	LWIP_LIB ?= $($(ARDUINO_VARIANT).menu.ip.$(LWIP_VARIANT).build.lwip_lib)
	LWIP_INCLUDE ?= $($(ARDUINO_VARIANT).menu.ip.$(LWIP_VARIANT).build.lwip_include)
	ifeq ($(SPIFFS_PAGESIZE),)
		SPIFFS_PAGESIZE = 256
	endif
	ifeq ($(SPIFFS_BLOCKSIZE),)
		SPIFFS_BLOCKSIZE = 4096
	endif
	
	LED_BUILTIN ?= $($(ARDUINO_VARIANT).menu.led.2.build.led)

	SPIFFS_SIZE ?= $(shell echo $$(( $(SPIFFS_END) - $(SPIFFS_START) ))) 
	UPLOAD_MAXIMUM_DATA_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_data_size) 
else #ESP32
	PARTITIONS = $($(ARDUINO_VARIANT).build.partitions)
	F_CPU = $($(ARDUINO_VARIANT).build.f_cpu)
	FLASH_SIZE ?= $($(ARDUINO_VARIANT).build.flash_size)
	BOOT ?= $($(ARDUINO_VARIANT).build.boot)
	UPLOAD_MAXIMUM_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_size) 
	UPLOAD_MAXIMUM_DATA_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_data_size) 
endif


ifeq ($(ARDUINO_ARCH),esp8266)
	ESPRESSIF_SDK = $(ARDUINO_HOME)/tools/sdk
else
	ESPRESSIF_SDK = $(ARDUINO_HOME)/tools/sdk/$(MCU)
endif
FS_DIR ?= ./data
FS_IMAGE=$(BUILD_OUT)/spiffs/spiffs.bin
FS_FILES=$(wildcard $(FS_DIR)/*)

MKSPIFFS=$(ARDUINO_HOME)/tools/mkspiffs/mkspiffs$(EXEC_EXT)
ESPOTA ?= $(ARDUINO_HOME)/tools/espota.py
ifeq ($(ARDUINO_ARCH),esp8266)
	XTENSA_TOOLCHAIN ?= $(ARDUINO_HOME)/tools/xtensa-lx106-elf/bin/
	PYTHON = $(ARDUINO_HOME)/tools/python3/python3$(EXEC_EXT)
	ESPTOOL ?= $(ARDUINO_HOME)/tools/elf2bin.py
	UPLOADTOOL ?= $(ARDUINO_HOME)/tools/upload.py
	ESP8266_SDK ?= NONOSDK22x_190703
else
	XTENSA_TOOLCHAIN ?= $(ARDUINO_HOME)/tools/xtensa-esp32-elf/bin/
	ESPTOOL ?= $(ARDUINO_HOME)/tools/esptool.py
endif

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
	BUILD_OUT ?= ./build.$(ARDUINO_VARIANT).$(NODENAME)-$(ESP8266_VERSION)
else
	BUILD_OUT ?= ./build.$(ARDUINO_VARIANT)-$(ESP8266_VERSION)
endif

### ESP8266 CORE
CORE_SSRC = $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*.S)
CORE_SRC = $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*.c)
CORE_SRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*/*.c)
CORE_CXXSRC = $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*.cpp)
CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/libb64/*.cpp)
CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/spiffs/*.cpp)
CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/umm_malloc/*.cpp)

CORE_OBJS = $(addprefix $(BUILD_OUT)/core/, \
	$(notdir $(CORE_SSRC:.S=.S.o) )) \
	$(addprefix $(BUILD_OUT)/core/, $(patsubst $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/%.c,%.c.o,$(CORE_SRC))) \
	$(addprefix $(BUILD_OUT)/core/, $(patsubst $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/%.cpp,%.cpp.o,$(CORE_CXXSRC))) 
#	$(addprefix $(BUILD_OUT)/core/libb64/, $(patsubst $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/libb64/%.cpp,%.cpp.o,$(CORE_CXXSRC))) \
#	$(addprefix $(BUILD_OUT)/core/spiffs/, $(patsubst $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/spiffs/%.cpp,%.cpp.o,$(CORE_CXXSRC))) \
#	$(addprefix $(BUILD_OUT)/core/umm_malloc/, $(patsubst $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/umm_malloc/%.cpp,%.cpp.o,$(CORE_CXXSRC)))
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


ifeq ($(ARDUINO_ARCH),esp8266)
	CPREPROCESSOR_FLAGS = -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ -D_GNU_SOURCE -I$(ESPRESSIF_SDK)/include -I$(ESPRESSIF_SDK)/$(LWIP_INCLUDE) -I$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/include -I$(BUILD_OUT)/core
else #ESP32
	CPREPROCESSOR_FLAGS = -DHAVE_CONFIG_H -DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\" -DUNITY_INCLUDE_CONFIG_H -DWITH_POSIX -D_GNU_SOURCE \
							-DIDF_VER=\"v4.4-dev-2313-gc69f0ec32\" -DESP_PLATFORM -I$(ESPRESSIF_SDK)/include/config -I$(ESPRESSIF_SDK)/include/newlib/platform_include \
							-I$(ESPRESSIF_SDK)/include/freertos/include -I$(ESPRESSIF_SDK)/include/freertos/port/xtensa/include -I$(ESPRESSIF_SDK)/include/esp_hw_support/include \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc -I$(ESPRESSIF_SDK)/include/esp_hw_support/include/soc/esp32 \
							-I$(ESPRESSIF_SDK)/include/esp_hw_support/port/esp32 -I$(ESPRESSIF_SDK)/include/heap/include -I$(ESPRESSIF_SDK)/include/log/include \
							-I$(ESPRESSIF_SDK)/include/lwip/include/apps -I$(ESPRESSIF_SDK)/include/lwip/include/apps/sntp -I$(ESPRESSIF_SDK)/include/lwip/lwip/src/include \
							-I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include -I$(ESPRESSIF_SDK)/include/lwip/port/esp32/include/arch -I$(ESPRESSIF_SDK)/include/soc/include \
							-I$(ESPRESSIF_SDK)/include/soc/esp32 -I$(ESPRESSIF_SDK)/include/soc/esp32/include -I$(ESPRESSIF_SDK)/include/hal/esp32/include \
							-I$(ESPRESSIF_SDK)/include/hal/include -I$(ESPRESSIF_SDK)/include/hal/platform_port/include -I$(ESPRESSIF_SDK)/include/esp_rom/include -I$(ESPRESSIF_SDK)/include/esp_rom/esp32 \
							-I$(ESPRESSIF_SDK)/include/esp_rom/include/esp32 -I$(ESPRESSIF_SDK)/include/esp_common/include -I$(ESPRESSIF_SDK)/include/esp_system/include -I$(ESPRESSIF_SDK)/include/esp_system/port/soc \
							-I$(ESPRESSIF_SDK)/include/esp_system/port/public_compat -I$(ESPRESSIF_SDK)/include/esp32/include -I$(ESPRESSIF_SDK)/include/xtensa/include \
							-I$(ESPRESSIF_SDK)/include/xtensa/esp32/include -I$(ESPRESSIF_SDK)/include/driver/include -I$(ESPRESSIF_SDK)/include/driver/esp32/include \
							-I$(ESPRESSIF_SDK)/include/esp_pm/include -I$(ESPRESSIF_SDK)/include/esp_ringbuf/include -I$(ESPRESSIF_SDK)/include/efuse/include -I$(ESPRESSIF_SDK)/include/efuse/esp32/include \
							-I$(ESPRESSIF_SDK)/include/vfs/include -I$(ESPRESSIF_SDK)/include/esp_wifi/include -I$(ESPRESSIF_SDK)/include/esp_event/include -I$(ESPRESSIF_SDK)/include/esp_netif/include \
							-I$(ESPRESSIF_SDK)/include/esp_eth/include -I$(ESPRESSIF_SDK)/include/tcpip_adapter/include -I$(ESPRESSIF_SDK)/include/esp_phy/include \
							-I$(ESPRESSIF_SDK)/include/esp_phy/esp32/include -I$(ESPRESSIF_SDK)/include/app_trace/include -I$(ESPRESSIF_SDK)/include/esp_timer/include \
							-I$(ESPRESSIF_SDK)/include/esp_ipc/include -I$(ESPRESSIF_SDK)/include/mbedtls/port/include -I$(ESPRESSIF_SDK)/include/mbedtls/mbedtls/include \
							-I$(ESPRESSIF_SDK)/include/mbedtls/esp_crt_bundle/include -I$(ESPRESSIF_SDK)/include/app_update/include -I$(ESPRESSIF_SDK)/include/spi_flash/include \
							-I$(ESPRESSIF_SDK)/include/bootloader_support/include -I$(ESPRESSIF_SDK)/include/nvs_flash/include -I$(ESPRESSIF_SDK)/include/pthread/include \
							-I$(ESPRESSIF_SDK)/include/esp_gdbstub/include -I$(ESPRESSIF_SDK)/include/esp_gdbstub/xtensa -I$(ESPRESSIF_SDK)/include/esp_gdbstub/esp32 \
							-I$(ESPRESSIF_SDK)/include/espcoredump/include -I$(ESPRESSIF_SDK)/include/espcoredump/include/port/xtensa -I$(ESPRESSIF_SDK)/include/wpa_supplicant/include \
							-I$(ESPRESSIF_SDK)/include/wpa_supplicant/port/include -I$(ESPRESSIF_SDK)/include/wpa_supplicant/include/esp_supplicant -I$(ESPRESSIF_SDK)/include/ieee802154/include \
							-I$(ESPRESSIF_SDK)/include/asio/asio/asio/include -I$(ESPRESSIF_SDK)/include/asio/port/include -I$(ESPRESSIF_SDK)/include/bt/common/osi/include \
							-I$(ESPRESSIF_SDK)/include/bt/include/esp32/include -I$(ESPRESSIF_SDK)/include/bt/common/api/include/api -I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/blufi/include \
							-I$(ESPRESSIF_SDK)/include/bt/common/btc/profile/esp/include -I$(ESPRESSIF_SDK)/include/bt/host/bluedroid/api/include/api -I$(ESPRESSIF_SDK)/include/cbor/port/include \
							-I$(ESPRESSIF_SDK)/include/unity/include -I$(ESPRESSIF_SDK)/include/unity/unity/src -I$(ESPRESSIF_SDK)/include/cmock/CMock/src -I$(ESPRESSIF_SDK)/include/coap/port/include \
							-I$(ESPRESSIF_SDK)/include/coap/port/include/coap -I$(ESPRESSIF_SDK)/include/coap/libcoap/include -I$(ESPRESSIF_SDK)/include/coap/libcoap/include/coap2 \
							-I$(ESPRESSIF_SDK)/include/console -I$(ESPRESSIF_SDK)/include/nghttp/port/include -I$(ESPRESSIF_SDK)/include/nghttp/nghttp2/lib/includes \
							-I$(ESPRESSIF_SDK)/include/esp-tls -I$(ESPRESSIF_SDK)/include/esp-tls/esp-tls-crypto -I$(ESPRESSIF_SDK)/include/esp_adc_cal/include -I$(ESPRESSIF_SDK)/include/esp_hid/include \
							-I$(ESPRESSIF_SDK)/include/tcp_transport/include -I$(ESPRESSIF_SDK)/include/esp_http_client/include -I$(ESPRESSIF_SDK)/include/esp_http_server/include \
							-I$(ESPRESSIF_SDK)/include/esp_https_ota/include -I$(ESPRESSIF_SDK)/include/esp_lcd/include -I$(ESPRESSIF_SDK)/include/esp_lcd/interface -I$(ESPRESSIF_SDK)/include/protobuf-c/protobuf-c \
							-I$(ESPRESSIF_SDK)/include/protocomm/include/common -I$(ESPRESSIF_SDK)/include/protocomm/include/security -I$(ESPRESSIF_SDK)/include/protocomm/include/transports \
							-I$(ESPRESSIF_SDK)/include/mdns/include -I$(ESPRESSIF_SDK)/include/esp_local_ctrl/include -I$(ESPRESSIF_SDK)/include/sdmmc/include -I$(ESPRESSIF_SDK)/include/esp_serial_slave_link/include \
							-I$(ESPRESSIF_SDK)/include/esp_websocket_client/include -I$(ESPRESSIF_SDK)/include/expat/expat/expat/lib -I$(ESPRESSIF_SDK)/include/expat/port/include \
							-I$(ESPRESSIF_SDK)/include/wear_levelling/include -I$(ESPRESSIF_SDK)/include/fatfs/diskio -I$(ESPRESSIF_SDK)/include/fatfs/vfs -I$(ESPRESSIF_SDK)/include/fatfs/src \
							-I$(ESPRESSIF_SDK)/include/freemodbus/common/include -I$(ESPRESSIF_SDK)/include/idf_test/include -I$(ESPRESSIF_SDK)/include/idf_test/include/esp32 -I$(ESPRESSIF_SDK)/include/jsmn/include \
							-I$(ESPRESSIF_SDK)/include/json/cJSON -I$(ESPRESSIF_SDK)/include/libsodium/libsodium/src/libsodium/include -I$(ESPRESSIF_SDK)/include/libsodium/port_include \
							-I$(ESPRESSIF_SDK)/include/mqtt/esp-mqtt/include -I$(ESPRESSIF_SDK)/include/openssl/include -I$(ESPRESSIF_SDK)/include/perfmon/include -I$(ESPRESSIF_SDK)/include/spiffs/include \
							-I$(ESPRESSIF_SDK)/include/ulp/include -I$(ESPRESSIF_SDK)/include/wifi_provisioning/include -I$(ESPRESSIF_SDK)/include/button/button/include -I$(ESPRESSIF_SDK)/include/json_parser \
							-I$(ESPRESSIF_SDK)/include/json_parser/jsmn/include -I$(ESPRESSIF_SDK)/include/json_generator -I$(ESPRESSIF_SDK)/include/esp_schedule/include -I$(ESPRESSIF_SDK)/include/esp_rainmaker/include \
							-I$(ESPRESSIF_SDK)/include/qrcode/include -I$(ESPRESSIF_SDK)/include/ws2812_led -I$(ESPRESSIF_SDK)/include/esp_littlefs/src -I$(ESPRESSIF_SDK)/include/esp_littlefs/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/dotprod/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/support/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/hann/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman_harris/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/blackman_nuttall/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/nuttall/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/windows/flat_top/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/iir/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/fir/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/add/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/sub/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/mul/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/addc/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/mulc/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/math/sqrt/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/matrix/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/fft/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/dct/include \
							-I$(ESPRESSIF_SDK)/include/esp-dsp/modules/conv/include -I$(ESPRESSIF_SDK)/include/esp-dsp/modules/common/include -I$(ESPRESSIF_SDK)/include/esp-face/face_detection/include \
							-I$(ESPRESSIF_SDK)/include/esp-face/face_recognition/include -I$(ESPRESSIF_SDK)/include/esp-face/object_detection/include -I$(ESPRESSIF_SDK)/include/esp-face/image_util/include \
							-I$(ESPRESSIF_SDK)include/esp-face/pose_estimation/include -I$(ESPRESSIF_SDK)/include/esp-face/lib/include -I$(ESPRESSIF_SDK)/include/esp32-camera/driver/include \
							-I$(ESPRESSIF_SDK)/include/esp32-camera/conversions/include -I$(ESPRESSIF_SDK)/include/fb_gfx/include
endif

ifeq ($(ARDUINO_ARCH),esp8266)
	DEFINES = -D$(ESP8266_SDK)=1 -DF_CPU=$(F_CPU) $(LWIP_FLAGS) -DARDUINO=$(ARDUINO_VERSION) \
		-DARDUINO_$(ARDUINO_BOARD) -DARDUINO_ARCH_$(shell echo "$(ARDUINO_ARCH)" | tr '[:lower:]' '[:upper:]') \
		-DARDUINO_BOARD=\"$(ARDUINO_BOARD)\"  $(LED_BUILTIN) $(FLASH_FLAG) -DESP8266 
	# with release installation from git the constants are not defined so do it here
	ifneq ($(ESP8266_VERSION),git)
		ESP8266_RELEASE_STRING=\"$(call word-dot,$(ESP8266_VERSION),1)_$(call word-dot,$(ESP8266_VERSION),2)_$(call word-dot,$(ESP8266_VERSION),3)\"
		
		DEFINES += -DARDUINO_ESP8266_RELEASE_$(call word-dot,$(ESP8266_VERSION),1)_$(call word-dot,$(ESP8266_VERSION),2)_$(call word-dot,$(ESP8266_VERSION),3) -DARDUINO_ESP8266_RELEASE=$(ESP8266_RELEASE_STRING)
		DEFINES += -DARDUINO_ESP8266_MAJOR=$(call word-dot,$(ESP8266_VERSION),1)
		DEFINES += -ARDUINO_ESP8266_MINOR=$(call word-dot,$(ESP8266_VERSION),2)
		DEFINES += -ARDUINO_ESP8266_REVISION=$(call word-dot,$(ESP8266_VERSION),3)
	endif
else # ESP32
	DEFINES = -DF_CPU=$(F_CPU) -DARDUINO=$(ARDUINO_VERSION) \
		-DARDUINO_$(ARDUINO_BOARD) -DARDUINO_ARCH_$(shell echo "$(ARDUINO_ARCH)" | tr '[:lower:]' '[:upper:]') \
		-DARDUINO_BOARD=\"$(ARDUINO_BOARD)\" -DARDUINO_VARIANT=\"$(ARDUINO_VARIANT)\" -DESP32
endif

CORE_INC = $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH) \
	$(ARDUINO_HOME)/variants/$(VARIANT)

INCLUDE_ARDUINO_H = -include Arduino.h
INCLUDES =  $(CORE_INC:%=-I%) $(ALIBDIRS:%=-I%) $(ULIBDIRS:%=-I%)  $(USRCDIRS:%=-I%)

VPATH = . $(CORE_INC) $(ALIBDIRS) $(ULIBDIRS)

WARNING_FLAGS ?= -w
EXCEPTION_FLAGS ?= -fno-exceptions

ifeq ($(ARDUINO_ARCH),esp8266)
	ASFLAGS = -c -g -x assembler-with-cpp -MMD -mlongcalls
	ARFLAGS = cru
	ifeq ($(ESP8266_V3), true)
		CFLAGS = -c $(WARNING_FLAGS) -std=$(STDC_LEVEL) $(STACKSMASH_FLAGS) -Os -g -free -fipa-pta -Wpointer-arith -Wno-implicit-function-declaration -Wl,-EL \
			-fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals \
			-falign-functions=4 -MMD -ffunction-sections -fdata-sections $(EXCEPTION_FLAGS) \
			$(MMU_FLAGS) $(NON32XFER_FLAGS) $(SSL_FLAGS)
		ASFLAGS := $(ASFLAGS) -I$(ARDUINO_HOME)/tools/xtensa-lx106-elf/include
		CXXFLAGS = -c $(WARNING_FLAGS) $(STACKSMASH_FLAGS) -Os -g -free -fipa-pta -mlongcalls -mtext-section-literals $(EXCEPTION_FLAGS)  \
			-fno-rtti -falign-functions=4 -std=$(STDCPP_LEVEL) -MMD -ffunction-sections -fdata-sections \
			$(EXCEPTION_FLAGS) $(MMU_FLAGS) $(NON32XFER_FLAGS) $(SSL_FLAGS)
		ELFLIBS = -lhal -lphy -lpp -lnet80211 $(LWIP_LIB) -lwpa -lcrypto -lmain -lwps -lbearssl -lespnow -lsmartconfig -lairkiss -lwpa2 -lstdc++ \
			-lm -lc -lgcc
		ELFFLAGS = -fno-exceptions -g -w -Os -nostdlib -Wl,--no-check-sections -u app_entry -u _printf_float -u _scanf_float -Wl,-static \
			-L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/lib/$(ESP8266_SDK) -L$(ESPRESSIF_SDK)/ld -L$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/lib \
			 -Tlocal.eagle.flash.ld \
			 -Wl,--gc-sections -Wl,-wrap,system_restart_local -Wl,-wrap,spi_flash_read
	else
		CFLAGS = -c -Os -g -Wpointer-arith -Wno-implicit-function-declaration -Wl,-EL \
			-fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals \
			-falign-functions=4 -MMD -std=$(STDC_LEVEL) -ffunction-sections -fdata-sections \
			$(EXCEPTION_FLAGS) $(SSL_FLAGS)
			
		CXXFLAGS = -c $(WARNING_FLAGS) -Os -g -mlongcalls -mtext-section-literals $(EXCEPTION_FLAGS)  \
			-fno-rtti -falign-functions=4 -std=$(STDCPP_LEVEL) -MMD -ffunction-sections -fdata-sections \
			$(EXCEPTION_FLAGS) $(SSL_FLAGS)
		ELFLIBS = -lhal -lphy -lpp -lnet80211 $(LWIP_LIB) -lwpa -lcrypto -lmain -lwps -lbearssl -laxtls -lespnow -lsmartconfig -lairkiss -lwpa2 -lstdc++ -lm -lc -lgcc
		ELFFLAGS = -fno-exceptions -g -w -Os -nostdlib -Wl,--no-check-sections -u app_entry -u _printf_float -u _scanf_float -Wl,-static \
			-L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/lib/$(ESP8266_SDK) -L$(ESPRESSIF_SDK)/ld -L$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/lib \
			 -T$(FLASH_LD) \
			 -Wl,--gc-sections -Wl,-wrap,system_restart_local -Wl,-wrap,spi_flash_read
	endif
else	#ESP32
	ASFLAGS = -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable -Wno-error=deprecated-declarations \
				-Wno-unused-parameter -Wno-sign-compare -ggdb -O2 -Wwrite-strings -fstack-protector -fstrict-volatile-bitfields \
				-Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion  -x assembler-with-cpp -MMD -c	

	CFLAGS = -mlongcalls -Wno-frame-address -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
			 -Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -O2 -Wwrite-strings -fstack-protector \
			 -fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion -std=gnu99 \
			 -Wno-old-style-declaration  -MMD -c
	CXXFLAGS = -mlongcalls -Wno-frame-address -ffunction-sections -fdata-sections -Wno-error=unused-function -Wno-error=unused-variable \
				-Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -ggdb -O2 -Wwrite-strings -fstack-protector \
				-fstrict-volatile-bitfields -Wno-error=unused-but-set-variable -fno-jump-tables -fno-tree-switch-conversion -std=gnu++11 \
				-fexceptions -fno-rtti  -MMD -c			 
	ELFLIBS = -lesp_ringbuf -lefuse -lesp_ipc -ldriver -lesp_pm -lmbedtls -lapp_update -lbootloader_support -lspi_flash -lnvs_flash -lpthread -lesp_gdbstub -lespcoredump \
			  -lesp_phy -lesp_system -lesp_rom -lhal -lvfs -lesp_eth -ltcpip_adapter -lesp_netif -lesp_event -lwpa_supplicant -lesp_wifi -llwip -llog -lheap -lsoc \
			  -lesp_hw_support -lxtensa -lesp_common -lesp_timer -lfreertos -lnewlib -lcxx -lapp_trace -lasio -lbt -lcbor -lunity -lcmock -lcoap -lconsole -lnghttp \
			  -lesp-tls -lesp_adc_cal -lesp_hid -ltcp_transport -lesp_http_client -lesp_http_server -lesp_https_ota -lesp_lcd -lprotobuf-c -lprotocomm -lmdns -lesp_local_ctrl \
			  -lsdmmc -lesp_serial_slave_link -lopenssl -lperfmon -lspiffs \
			  -lulp -lwifi_provisioning -lbutton -ljson_parser -ljson_generator -lesp_schedule -lesp_rainmaker -lqrcode -lws2812_led -lesp-dsp -lesp-face -lesp32-camera \
			  -lesp_littlefs -lfb_gfx -lesp_websocket_client -lexpat -lfreemodbus -ljsmn -llibsodium \
			  -lfatfs -lwear_levelling -lmqtt -lbtdm_app \
			  -ljson -lpe -lfd -lfr -ldetection_cat_face -ldetection -ldl \
			  -lmbedcrypto -lmbedx509 -lcoexist -lcore -lespnow -lmesh -lnet80211 -lpp -lsmartconfig -lwapi \
			  -lphy -lrtc -lxt_hal -lm  -lstdc++ \
			  -lgcc -lgcov -lc 
	ARFLAGS = cr

	ELFFLAGS = -T esp32.rom.redefined.ld -T memory.ld -T sections.ld -T esp32.rom.ld -T esp32.rom.api.ld -T esp32.rom.libgcc.ld -T esp32.rom.newlib-data.ld \
				-T esp32.rom.syscalls.ld -T esp32.peripherals.ld  -mlongcalls -Wno-frame-address -Wl,--cref -Wl,--gc-sections -fno-rtti -fno-lto -u _Z5setupv \
				-u _Z4loopv -Wl,--wrap=mbedtls_mpi_exp_mod -u esp_app_desc -u pthread_include_pthread_impl -u pthread_include_pthread_cond_impl \
				-u pthread_include_pthread_local_storage_impl -u ld_include_panic_highint_hdl -u start_app -u start_app_other_cores \
				-u __ubsan_include -Wl,--wrap=longjmp -u __assert_func -u vfs_include_syscalls_impl -Wl,--undefined=uxTopUsedPriority \
				-u app_main -u newlib_include_heap_impl -u newlib_include_syscalls_impl -u newlib_include_pthread_impl -u __cxa_guard_dummy -DESP32 -DCORE_DEBUG_LEVEL=0 -DARDUINO_RUNNING_CORE=1 -DARDUINO_EVENT_RUNNING_CORE=1
endif		

ifeq ($(ARDUINO_ARCH),esp8266)
	CC := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-gcc
	CXX := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-g++
	AR := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-ar
	LD := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-gcc
	OBJDUMP := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-objdump
	SIZE := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-size
	OBJCOPY_HEX_PATTERN = --eboot $(ARDUINO_HOME)/bootloaders/eboot/eboot.elf --app $(BUILD_OUT)/$(TARGET).elf \
		--flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) --flash_size $(FLASH_SIZE) \
		--path $(XTENSA_TOOLCHAIN) --out $(BUILD_OUT)/$(TARGET).bin
	SIZE_REGEX_DATA = '^(?:\.data|\.rodata|\.bss)\s+([0-9]+).*'
	SIZE_REGEX = '^(?:\.irom0\.text|\.text|\.text1|\.data|\.rodata|)\s+([0-9]+).*'
	SIZE_REGEX_EEPROM = '^(?:\.eeprom)\s+([0-9]+).*'
	UPLOAD_PATTERN = $(ESPTOOL_VERBOSE) -cd $(UPLOAD_RESETMETHOD) -cb $(UPLOAD_SPEED) -cp $(SERIAL_PORT) -ca 0x00000 -cf $(BUILD_OUT)/$(TARGET).bin
	RESET_PATTERN = $(ESPTOOL_VERBOSE) --chip auto $(UPLOAD_RESETMETHOD) --port $(SERIAL_PORT) chip_id
	FS_UPLOAD_PATTERN = $(ESPTOOL_VERBOSE)  --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) -a soft_reset write_flash $(SPIFFS_START) 
	MKSPIFFS_PATTERN = -c $(FS_DIR) -b $(SPIFFS_BLOCKSIZE) -p $(SPIFFS_PAGESIZE) -s $(SPIFFS_SIZE) $(FS_IMAGE)
	C_COMBINE_PATTERN = -Wl,-Map "-Wl,$(BUILD_OUT)/$(TARGET).map" -Wl,--start-group $(OBJ_FILES) $(LIB_OBJ_FILES) $(BUILD_OUT)/core/core.a \
		$(ELFLIBS) -Wl,--end-group -L$(BUILD_OUT)
else #ESP32
	CC := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-gcc
	CXX := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-g++
	AR := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-ar
	AS := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-as
	#LD := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-gcc
	LD := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-g++
	OBJDUMP := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-objdump
	SIZE := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-size
	OBJCOPY_HEX_PATTERN = --chip $(MCU) elf2image --flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) --flash_size $(FLASH_SIZE) \
		-o $(BUILD_OUT)/$(TARGET).bin $(BUILD_OUT)/$(TARGET).elf
	OBJCOPY_PARTITION_PATTERN = $(ARDUINO_HOME)/tools/gen_esp32part.py -q $(BUILD_OUT)/partitions.csv $(BUILD_OUT)/$(TARGET).partitions.bin
	PREBUILD1_PATTERN = bash -c "[ ! -f ./partitions.csv ] || cp -f ./partitions.csv $(BUILD_OUT)/partitions.csv"
	PREBUILD2_PATTERN = bash -c "[ -f $(BUILD_OUT)/partitions.csv ] || [ ! -f $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv ] || cp $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv $(BUILD_OUT)/partitions.csv"
	PREBUILD3_PATTERN = bash -c "[ -f $(BUILD_OUT)/partitions.csv ] || cp $(ARDUINO_HOME)/tools/partitions/$(PARTITIONS).csv $(BUILD_OUT)/partitions.csv"



	C_COMBINE_PATTERN = -Wl,--Map=$(BUILD_OUT)/map.map -L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/ld $(ELFFLAGS) -DARDUINO_USB_CDC_ON_BOOT=0 \
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
endif

.PHONY: all dirs clean upload fs upload_fs

ifeq ($(ARDUINO_ARCH),esp8266)
  REQ=prebuild
endif

all: $(REQ) sketch libs core bin size


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

prelink:
ifeq ($(ESP8266_V3), true)
	mkdir -p $(BUILD_OUT)/ld_h
	cp $(ESPRESSIF_SDK)/ld/$(FLASH_LD) $(BUILD_OUT)/ld_h/local.eagle.flash.ld.h
	$(CC) $(VTABLE_FLAGS) -CC -E -P  $(MMU_FLAGS) $(VTABLE_FLAGS) $(BUILD_OUT)/ld_h/local.eagle.flash.ld.h -o $(BUILD_OUT)/local.eagle.flash.ld
	$(CC) $(VTABLE_FLAGS) -CC -E -P  $(MMU_FLAGS) $(VTABLE_FLAGS) $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld.h -o $(BUILD_OUT)/local.eagle.app.v6.common.ld
else
ifneq ("$(wildcard  $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld.h)","")
	$(CC) $(VTABLE_FLAGS) -CC -E -P  $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld.h -o $(BUILD_OUT)/local.eagle.app.v6.common.ld
endif
endif
$(BUILD_OUT)/core/%.S.o: $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/%.S
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

$(BUILD_OUT)/$(TARGET).elf: sketch prelink core libs
ifeq ($(ARDUINO_ARCH),esp32)
	$(LD) $(C_COMBINE_PATTERN) -o $@ 
else
	$(LD) $(ELFFLAGS) $(C_COMBINE_PATTERN) -o $@ 
endif

size: $(BUILD_OUT)/$(TARGET).elf
	@$(SIZE) -A $(BUILD_OUT)/$(TARGET).elf | perl -e "$$MEM_USAGE" $(SIZE_REGEX) $(SIZE_REGEX_DATA)

$(BUILD_OUT)/$(TARGET).bin: $(BUILD_OUT)/$(TARGET).elf
	$(ESPTOOL) $(OBJCOPY_HEX_PATTERN)
	@sha256sum $(BUILD_OUT)/$(TARGET).bin > $(BUILD_OUT)/$(TARGET).sha

prebuild:
ifeq ($(ARDUINO_ARCH),esp32)
	$(PREBUILD1_PATTERN)
	$(PREBUILD2_PATTERN)
	$(PREBUILD3_PATTERN)
	$(OBJCOPY_PARTITION_PATTERN)
endif

reset: 
	$(PYTHON) $(ARDUINO_HOME)/tools/esptool/esptool.py $(RESET_PATTERN)

upload: $(BUILD_OUT)/$(TARGET).bin size
	$(PYTHON) $(UPLOADTOOL) --chip esp8266 --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) $(UPLOAD_ERASE_CMD) $(UPLOAD_RESETMETHOD) write_flash 0x0 $(BUILD_OUT)/$(TARGET).bin

erase:
	$(PYTHON) $(UPLOADTOOL) --chip esp8266 --port $(SERIAL_PORT) erase_flash


fs:
ifneq ($(strip $(FS_FILES)),)
	@rm -f $(FS_IMAGE)
	@mkdir -p $(BUILD_OUT)/spiffs
	$(MKSPIFFS) $(MKSPIFFS_PATTERN)
endif

upload_fs: fs
ifeq ($(ARDUINO_ARCH),esp8266)
	@echo "SPIFFS Uploading Image..."
	@echo "[SPIFFS] upload   : " $(FS_IMAGE)
	@echo "[SPIFFS] address  : " $(SPIFFS_START)
	@echo "[SPIFFS] reset    : " $(UPLOAD_RESETMETHOD)
	@echo "[SPIFFS] port     : " $(SERIAL_PORT)
	@echo "[SPIFFS] speed    : " $(UPLOAD_SPEED)
	@echo "[SPIFFS] uploader : " $(ARDUINO_HOME)/tools/esptool/esptool.py
	
	#/home/thunder/Esp8266-Arduino-Makefile/esp8266-2.6.1/tools/python3/python3 /home/thunder/Esp8266-Arduino-Makefile/esp8266-2.6.1/tools/esptool/esptool.py --chip esp8266 --port /dev/ttyUSB0 --baud 115200   write_flash  0x300000 ./build.nodemcuv2.ArDomo23-2.6.1/spiffs/spiffs.bin
	$(PYTHON) $(ARDUINO_HOME)/tools/esptool/esptool.py --chip esp8266 --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) write_flash $(SPIFFS_START) $(FS_IMAGE) 
else 
	@echo TODO upload_fs : No SPIFFS function available for $(ARDUINO_ARCH)
endif

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