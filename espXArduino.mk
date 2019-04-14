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
PERL := perl$(EXEC_EXT)

#DUMMY := $(shell $(ROOT_DIR)/bin/generate_platform.sh $(ARDUINO_HOME)/platform.txt $(ROOT_DIR)/bin/$(ARDUINO_ARCH)/platform.txt)
#runtime.platform.path = $(ARDUINO_HOME)
#include $(ROOT_DIR)/bin/$(ARDUINO_ARCH)/platform.txt

SERIAL_PORT ?= /dev/tty.nodemcu
ARDUINO_ARCH ?= esp8266
ifeq ($(ARDUINO_ARCH),esp8266)
	ESP8266_VERSION ?= 2.4.2
else
	ESP8266_VERSION ?= 1.0.1
endif
ARDUINO_HOME ?=  $(ROOT_DIR)/$(ARDUINO_ARCH)-$(ESP8266_VERSION)

ARDUINO_VARIANT ?= nodemcu
ARDUINO_VERSION ?= 10805

BOARDS_TXT  = $(ARDUINO_HOME)/boards.txt
PLATFORM_TXT  = $(ARDUINO_HOME)/platform.txt
PARSE_BOARD = $(ROOT_DIR)/bin/ard-parse-boards
PARSE_PLATFORM = $(ROOT_DIR)/bin/ard-parse-platform
PARSE_BOARD_OPTS = --boards_txt=$(BOARDS_TXT)
PARSE_BOARD_CMD = $(PARSE_BOARD) $(PARSE_BOARD_OPTS)
PARSE_PLATFORM_OPTS = --platform_txt=$(PLATFORM_TXT)
PARSE_PLATFORM_CMD = $(PARSE_PLATFORM) $(PARSE_PLATFORM_OPTS)

ARDUINO_CORE_VERSION = $(shell $(PARSE_PLATFORM_CMD) version)
ARDUINO_BOARD = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.board)
VARIANT = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.variant)

CONCATENATE_USER_FILES ?= yes
FLASH_PARTITION ?= 4M1M

MCU = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.mcu)
SERIAL_BAUD   ?= 115200
ifeq ($(ARDUINO_ARCH),esp8266)
	CPU_FREQ ?= 80
	DEFAULT_FLASH_FREQ = 40
	FLASH_FREQ ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_freq)
	ifeq ($(FLASH_FREQ), none)
		FLASH_FREQ = $(DEFAULT_FLASH_FREQ)
	endif
else
	CPU_FREQ ?= 40
	FLASH_FREQ ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashFreq.$(CPU_FREQ).build.flash_freq)
endif

FLASH_MODE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_mode)
ifeq ($(FLASH_MODE), none)
	FLASH_MODE = qio
endif

UPLOAD_RESETMETHOD ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.resetmethod)
UPLOAD_SPEED ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.speed)
ifeq ($(UPLOAD_SPEED),none)
	UPLOAD_SPEED = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.UploadSpeed.115200)
endif

ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git 2.5.0))
	FLASH_LD ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).build.flash_ld)
else
	FLASH_LD ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).build.flash_ld)
endif

#ifeq ($(FLASH_LD),none)
	#directly select the ld file from FLASH_PARTITION
#	FLASH_LD := eagle.flash.$(shell echo $(FLASH_PARTITION) | tr '[:upper:]' '[:lower:]').ld
#endif

ifeq ($(ARDUINO_ARCH),esp8266)
	ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git 2.5.0))
		F_CPU = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.xtal.$(CPU_FREQ).build.f_cpu)
		FLASH_SIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).build.flash_size)
		SPIFFS_PAGESIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).build.spiffs_pagesize)
		SPIFFS_START ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).build.spiffs_start)
		SPIFFS_END ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).build.spiffs_end)
		SPIFFS_BLOCKSIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).build.spiffs_blocksize)
		UPLOAD_MAXIMUM_SIZE ?=  $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.eesz.$(FLASH_PARTITION).upload.maximum_size) 
		FLASH_FLAG ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_flags)
		ifeq ($(FLASH_FLAG), none) # for generic boards
			FLASH_FLAG = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashMode.$(FLASH_MODE).build.flash_flags)
		endif
		LWIP_VARIANT ?= lm2f
		LWIP_FLAGS ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.ip.$(LWIP_VARIANT).build.lwip_flags)
		LWIP_LIB ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.ip.$(LWIP_VARIANT).build.lwip_lib)
		LWIP_INCLUDE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.ip.$(LWIP_VARIANT).build.lwip_include)
	else # Old releases
		F_CPU = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.CpuFrequency.$(CPU_FREQ).build.f_cpu)
		FLASH_SIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).build.flash_size)
		SPIFFS_PAGESIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).build.spiffs_pagesize)
		SPIFFS_START ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).build.spiffs_start)
		SPIFFS_END ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).build.spiffs_end)
		SPIFFS_BLOCKSIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).build.spiffs_blocksize)
		UPLOAD_MAXIMUM_SIZE ?=  $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.FlashSize.$(FLASH_PARTITION).upload.maximum_size) 
		LWIP_VARIANT ?= v2mss536
		LWIP_FLAGS ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.LwIPVariant.$(LWIP_VARIANT).build.lwip_flags)
		LWIP_LIB ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.LwIPVariant.$(LWIP_VARIANT).build.lwip_lib)
		LWIP_INCLUDE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.LwIPVariant.$(LWIP_VARIANT).build.lwip_include)
	endif
	
	LED_BUILTIN ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) menu.led.2.build.led)
	SPIFFS_SIZE ?= $(shell echo $$(( $(SPIFFS_END) - $(SPIFFS_START) ))) 
	UPLOAD_MAXIMUM_DATA_SIZE ?=  $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.maximum_data_size) 
else #ESP32
	F_CPU = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.f_cpu)
	FLASH_SIZE ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_size)
	BOOT ?= $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.boot)
	UPLOAD_MAXIMUM_SIZE ?=  $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.maximum_size) 
	UPLOAD_MAXIMUM_DATA_SIZE ?=  $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.maximum_data_size) 
endif


ESPRESSIF_SDK = $(ARDUINO_HOME)/tools/sdk
FS_DIR ?= ./data
FS_IMAGE=$(BUILD_OUT)/spiffs/spiffs.bin
FS_FILES=$(wildcard $(FS_DIR)/*)

MKSPIFFS=$(ARDUINO_HOME)/tools/mkspiffs/mkspiffs$(EXEC_EXT)
ESPOTA ?= $(ARDUINO_HOME)/tools/espota.py
ifeq ($(ARDUINO_ARCH),esp8266)
	XTENSA_TOOLCHAIN ?= $(ARDUINO_HOME)/tools/xtensa-lx106-elf/bin/
	ESPTOOL ?= $(ARDUINO_HOME)/tools/esptool/esptool$(EXEC_EXT)
	ESP8266_SDK ?= NONOSDK221
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
	BUILD_OUT_TR ?= build.$(ARDUINO_VARIANT).$(NODENAME)-$(ESP8266_VERSION)
else
	BUILD_OUT ?= ./build.$(ARDUINO_VARIANT)-$(ESP8266_VERSION)
	BUILD_OUT_TR ?= build.$(ARDUINO_VARIANT)-$(ESP8266_VERSION)
endif

### ESP8266 CORE
CORE_SSRC = $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*.S)
CORE_SRC = $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*.c)
CORE_SRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*/*.c)
CORE_CXXSRC = $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/*.cpp)
ifeq ($(ARDUINO_ARCH)$(ESP8266_VERSION),esp8266git)
	CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/libb64/*.cpp)
	CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/spiffs/*.cpp)
	CORE_CXXSRC += $(wildcard $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/umm_malloc/*.cpp)
endif
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
	
ALIB_CSRC := $(wildcard $(addsuffix *.c,$(ALIBDIRS)))
ALIB_SSRC := $(wildcard $(addsuffix *.S,$(ALIBDIRS)))
ALIB_CXXSRC := $(wildcard $(addsuffix *.cpp,$(ALIBDIRS)))


# object files
OBJ_FILES = $(addprefix $(BUILD_OUT)/,$(notdir $(TARGET).ino.cpp.o $(USER_SRC:.c=.c.o) $(USER_CXXSRC:.cpp=.cpp.o) ))
# LIB_OBJ_FILES = $(addprefix $(BUILD_OUT)/libraries/,$(notdir $(ULIB_CSRC:.c=.c.o) $(ALIB_CSRC:.c=.c.o) $(ALIB_SSRC:.S=.S.o) $(ULIB_CXXSRC:.cpp=.cpp.o) $(ALIB_CXXSRC:.cpp=.cpp.o) ))
LIB_OBJ_FILES = $(subst $(ARDUINO_HOME),$(BUILD_OUT),$(ULIB_CSRC:.c=.c.o) $(ALIB_CSRC:.c=.c.o) $(ALIB_SSRC:.S=.S.o) $(ULIB_CXXSRC:.cpp=.cpp.o) $(ALIB_CXXSRC:.cpp=.cpp.o))
LIB_DIRS = $(sort $(dir $(LIB_OBJ_FILES)))

ifeq ($(ARDUINO_ARCH),esp8266)
	CPREPROCESSOR_FLAGS = -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ -I$(ESPRESSIF_SDK)/include -I$(ESPRESSIF_SDK)/$(LWIP_INCLUDE) -I$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/include -I$(BUILD_OUT)/core
else #ESP32
ifeq ($(ESP8266_VERSION),git)
	CPREPROCESSOR_FLAGS = -DESP_PLATFORM -DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\" -DHAVE_CONFIG_H -I$(ESPRESSIF_SDK)/include/config \
					-I$(ESPRESSIF_SDK)/include/app_trace -I$(ESPRESSIF_SDK)/include/app_update -I$(ESPRESSIF_SDK)/include/asio -I$(ESPRESSIF_SDK)/include/bootloader_support \
					-I$(ESPRESSIF_SDK)/include/bt -I$(ESPRESSIF_SDK)/include/coap -I$(ESPRESSIF_SDK)/include/console -I$(ESPRESSIF_SDK)/include/driver -I$(ESPRESSIF_SDK)/include/efuse -I$(ESPRESSIF_SDK)/include/esp-tls \
					-I$(ESPRESSIF_SDK)/include/esp32 -I$(ESPRESSIF_SDK)/include/esp_adc_cal -I$(ESPRESSIF_SDK)/include/esp_event -I$(ESPRESSIF_SDK)/include/esp_http_client \
					-I$(ESPRESSIF_SDK)/include/esp_http_server -I$(ESPRESSIF_SDK)/include/esp_https_ota -I$(ESPRESSIF_SDK)/include/esp_https_server \
					-I$(ESPRESSIF_SDK)/include/esp_ringbuf -I$(ESPRESSIF_SDK)/include/espcoredump -I$(ESPRESSIF_SDK)/include/ethernet -I$(ESPRESSIF_SDK)/include/expat -I$(ESPRESSIF_SDK)/include/fatfs \
					-I$(ESPRESSIF_SDK)/include/freemodbus -I$(ESPRESSIF_SDK)/include/freertos -I$(ESPRESSIF_SDK)/include/heap -I$(ESPRESSIF_SDK)/include/idf_test \
					-I$(ESPRESSIF_SDK)/include/jsmn  -I$(ESPRESSIF_SDK)/include/json -I$(ESPRESSIF_SDK)/include/libsodium -I$(ESPRESSIF_SDK)/include/log \
					-I$(ESPRESSIF_SDK)/include/lwip -I$(ESPRESSIF_SDK)/include/mbedtls -I$(ESPRESSIF_SDK)/include/mdns -I$(ESPRESSIF_SDK)/include/micro-ecc \
					-I$(ESPRESSIF_SDK)/include/mqtt -I$(ESPRESSIF_SDK)/include/newlib -I$(ESPRESSIF_SDK)/include/nghttp -I$(ESPRESSIF_SDK)/include/nvs_flash \
					-I$(ESPRESSIF_SDK)/include/openssl -I$(ESPRESSIF_SDK)/include/protobuf-c -I$(ESPRESSIF_SDK)/include/protocomm -I$(ESPRESSIF_SDK)/include/pthread \
					-I$(ESPRESSIF_SDK)/include/sdmmc -I$(ESPRESSIF_SDK)/include/smartconfig_ack -I$(ESPRESSIF_SDK)/include/soc -I$(ESPRESSIF_SDK)/include/spi_flash \
					-I$(ESPRESSIF_SDK)/include/spiffs -I$(ESPRESSIF_SDK)/include/tcp_transport -I$(ESPRESSIF_SDK)/include/tcpip_adapter -I$(ESPRESSIF_SDK)/include/ulp \
					-I$(ESPRESSIF_SDK)/include/unity -I$(ESPRESSIF_SDK)/include/vfs -I$(ESPRESSIF_SDK)/include/wear_levelling -I$(ESPRESSIF_SDK)/include/wifi_provisioning \
					-I$(ESPRESSIF_SDK)/include/wpa_supplicant -I$(ESPRESSIF_SDK)/include/xtensa-debug-module -I$(ESPRESSIF_SDK)/include/esp32-camera \
					-I$(ESPRESSIF_SDK)/include/esp-face -I$(ESPRESSIF_SDK)/include/fb_gfx 
else
	CPREPROCESSOR_FLAGS = -DESP_PLATFORM -DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\" -DHAVE_CONFIG_H -I$(ESPRESSIF_SDK)/include/config \
					-I$(ESPRESSIF_SDK)/include/app_trace -I$(ESPRESSIF_SDK)/include/app_update -I$(ESPRESSIF_SDK)/include/asio -I$(ESPRESSIF_SDK)/include/bootloader_support \
					-I$(ESPRESSIF_SDK)/include/bt -I$(ESPRESSIF_SDK)/include/coap -I$(ESPRESSIF_SDK)/include/console -I$(ESPRESSIF_SDK)/include/driver -I$(ESPRESSIF_SDK)/include/esp-tls \
					-I$(ESPRESSIF_SDK)/include/esp32 -I$(ESPRESSIF_SDK)/include/esp_adc_cal -I$(ESPRESSIF_SDK)/include/esp_event -I$(ESPRESSIF_SDK)/include/esp_http_client \
					-I$(ESPRESSIF_SDK)/include/esp_http_server -I$(ESPRESSIF_SDK)/include/esp_https_ota -I$(ESPRESSIF_SDK)/include/esp_https_server \
					-I$(ESPRESSIF_SDK)/include/esp_ringbuf -I$(ESPRESSIF_SDK)/include/ethernet -I$(ESPRESSIF_SDK)/include/expat -I$(ESPRESSIF_SDK)/include/fatfs \
					-I$(ESPRESSIF_SDK)/include/freemodbus -I$(ESPRESSIF_SDK)/include/freertos -I$(ESPRESSIF_SDK)/include/heap -I$(ESPRESSIF_SDK)/include/idf_test \
					-I$(ESPRESSIF_SDK)/include/jsmn  -I$(ESPRESSIF_SDK)/include/json -I$(ESPRESSIF_SDK)/include/libsodium -I$(ESPRESSIF_SDK)/include/log \
					-I$(ESPRESSIF_SDK)/include/lwip -I$(ESPRESSIF_SDK)/include/mbedtls -I$(ESPRESSIF_SDK)/include/mdns -I$(ESPRESSIF_SDK)/include/micro-ecc \
					-I$(ESPRESSIF_SDK)/include/mqtt -I$(ESPRESSIF_SDK)/include/newlib -I$(ESPRESSIF_SDK)/include/nghttp -I$(ESPRESSIF_SDK)/include/nvs_flash \
					-I$(ESPRESSIF_SDK)/include/openssl -I$(ESPRESSIF_SDK)/include/protobuf-c -I$(ESPRESSIF_SDK)/include/protocomm -I$(ESPRESSIF_SDK)/include/pthread \
					-I$(ESPRESSIF_SDK)/include/sdmmc -I$(ESPRESSIF_SDK)/include/smartconfig_ack -I$(ESPRESSIF_SDK)/include/soc -I$(ESPRESSIF_SDK)/include/spi_flash \
					-I$(ESPRESSIF_SDK)/include/spiffs -I$(ESPRESSIF_SDK)/include/tcp_transport -I$(ESPRESSIF_SDK)/include/tcpip_adapter -I$(ESPRESSIF_SDK)/include/ulp \
					-I$(ESPRESSIF_SDK)/include/unity -I$(ESPRESSIF_SDK)/include/vfs -I$(ESPRESSIF_SDK)/include/wear_levelling -I$(ESPRESSIF_SDK)/include/wifi_provisioning \
					-I$(ESPRESSIF_SDK)/include/wpa_supplicant -I$(ESPRESSIF_SDK)/include/xtensa-debug-module -I$(ESPRESSIF_SDK)/include/esp32-camera \
					-I$(ESPRESSIF_SDK)/include/esp-face -I$(ESPRESSIF_SDK)/include/fb_gfx 
					
endif
endif

ifeq ($(ARDUINO_ARCH),esp8266)
	ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git 2.5.0))
		DEFINES = -D$(ESP8266_SDK)=1 -DF_CPU=$(F_CPU) $(LWIP_FLAGS) -DARDUINO=$(ARDUINO_VERSION) \
			-DARDUINO_$(ARDUINO_BOARD) -DARDUINO_ARCH_$(shell echo "$(ARDUINO_ARCH)" | tr '[:lower:]' '[:upper:]') \
			-DARDUINO_BOARD=\"$(ARDUINO_BOARD)\"  $(LED_BUILTIN) $(FLASH_FLAG) -DESP8266 
	else
		DEFINES = -DF_CPU=$(F_CPU) $(LWIP_FLAGS) -DARDUINO=$(ARDUINO_VERSION) \
			-DARDUINO_$(ARDUINO_BOARD) -DARDUINO_ARCH_$(shell echo "$(ARDUINO_ARCH)" | tr '[:lower:]' '[:upper:]') \
			-DARDUINO_BOARD=\"$(ARDUINO_BOARD)\" -DESP8266 
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

ifeq ($(ARDUINO_ARCH),esp8266)
	ASFLAGS = -c -g -x assembler-with-cpp -MMD -mlongcalls
	CFLAGS = -c -Os -g -Wpointer-arith -Wno-implicit-function-declaration -Wl,-EL \
		-fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals \
		-falign-functions=4 -MMD -std=gnu99 -ffunction-sections -fdata-sections
	CXXFLAGS = -c -w -Os -g -mlongcalls -mtext-section-literals -fno-exceptions \
		-fno-rtti -falign-functions=4 -std=c++11 -MMD -ffunction-sections -fdata-sections
ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git 2.5.0))
	ELFFLAGS = -g -w -Os -nostdlib -Wl,--no-check-sections -u app_entry -u _printf_float -u _scanf_float -Wl,-static \
			-L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/lib/$(ESP8266_SDK) -L$(ESPRESSIF_SDK)/ld -L$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/lib \
			 -T$(FLASH_LD) \
			 -Wl,--gc-sections -Wl,-wrap,system_restart_local -Wl,-wrap,spi_flash_read
	ELFLIBS = -lhal -lphy -lpp -lnet80211 $(LWIP_LIB) -lwpa -lcrypto -lmain -lwps -lbearssl -laxtls -lespnow -lsmartconfig -lairkiss -lwpa2 -lstdc++ -lm -lc -lgcc
else
	ELFFLAGS = -g -Os -nostdlib -Wl,--no-check-sections -u call_user_start -u _printf_float -u _scanf_float -Wl,-static \
			-L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/ld -L$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/lib \
			 -T$(FLASH_LD) \
			 -Wl,--gc-sections -Wl,-wrap,system_restart_local -Wl,-wrap,spi_flash_read
	ELFLIBS = -lhal -lphy -lpp -lnet80211 $(LWIP_LIB) -lwpa -lcrypto -lmain -lwps -laxtls -lespnow -lsmartconfig -lairkiss -lwpa2 -lstdc++ -lm -lc -lgcc
endif
			 
else	#ESP32
	ASFLAGS = -c -g3 -x assembler-with-cpp -MMD -mlongcalls
	CFLAGS = -std=gnu99 -Os -g3 -fstack-protector -ffunction-sections -fdata-sections -fstrict-volatile-bitfields -mlongcalls \
		-nostdlib -Wpointer-arith -w -Wno-error=unused-function -Wno-error=unused-but-set-variable \
		-Wno-error=unused-variable -Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-sign-compare -Wno-old-style-declaration -MMD -c
	CXXFLAGS = -std=gnu++11 -fno-exceptions -Os -g3 -Wpointer-arith -fexceptions -fstack-protector -ffunction-sections -fdata-sections -fstrict-volatile-bitfields \
		-mlongcalls -nostdlib -w -Wno-error=unused-function -Wno-error=unused-but-set-variable -Wno-error=unused-variable -Wno-error=deprecated-declarations \
		-Wno-unused-parameter -Wno-sign-compare -fno-rtti -MMD -c
ifeq ($(ESP8266_VERSION),git)
	ELFLIBS = -lgcc -lopenssl -lbtdm_app -lfatfs -lwps -lcoexist -lwear_levelling -lesp_http_client -lprotobuf-c -lhal -lnewlib -ldriver -lbootloader_support -lpp -lfreemodbus \
		-lmesh -lsmartconfig -ljsmn -lwpa -lethernet -lphy -lfrmn -lapp_trace -lfr_coefficients -lconsole -lulp -lwpa_supplicant -lfreertos -lbt -lmicro-ecc -lesp32-camera \
		-lcxx -lxtensa-debug-module -ltcp_transport -lmdns -lvfs -lmtmn -lespcoredump -lesp_ringbuf -lsoc -lcore -lfb_gfx -lsdmmc -llibsodium -lcoap -ltcpip_adapter \
		-lprotocomm -lesp_event -limage_util -lc_nano -lesp-tls -lasio -lrtc -lspi_flash -lwpa2 -lwifi_provisioning -lesp32 -lface_recognition -lapp_update -lnghttp -lspiffs \
		-lface_detection -lefuse -lunity -lesp_https_server -lespnow -lnvs_flash -lesp_adc_cal -llog -ldl_lib -lsmartconfig_ack -lexpat -lfd_coefficients -lm -lmqtt -lc -lheap -lmbedtls -llwip \
		-lnet80211 -lesp_http_server -lpthread -ljson -lesp_https_ota -lstdc++
else
	ELFLIBS = -lgcc -lopenssl -lbtdm_app -lfatfs -lwps -lcoexist -lwear_levelling -lesp_http_client -lprotobuf-c -lhal -lnewlib -ldriver -lbootloader_support -lpp -lfreemodbus \
		-lmesh -lsmartconfig -ljsmn -lwpa -lethernet -lphy -lfrmn -lapp_trace -lfr_coefficients -lconsole -lulp -lwpa_supplicant -lfreertos -lbt -lmicro-ecc -lesp32-camera \
		-lcxx -lxtensa-debug-module -ltcp_transport -lmdns -lvfs -lmtmn -lesp_ringbuf -lsoc -lcore -lfb_gfx -lsdmmc -llibsodium -lcoap -ltcpip_adapter \
		-lprotocomm -lesp_event -limage_util -lc_nano -lesp-tls -lasio -lrtc -lspi_flash -lwpa2 -lwifi_provisioning -lesp32 -lface_recognition -lapp_update -lnghttp -lspiffs \
		-lface_detection -lunity -lesp_https_server -lespnow -lnvs_flash -lesp_adc_cal -llog -ldl_lib -lsmartconfig_ack -lexpat -lfd_coefficients -lm -lmqtt -lc -lheap -lmbedtls -llwip \
		-lnet80211 -lesp_http_server -lpthread -ljson -lesp_https_ota -lstdc++
endif		
	ELFFLAGS = -nostdlib -L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/ld -T esp32_out.ld -T esp32.common.ld -T esp32.rom.ld -T esp32.peripherals.ld -T esp32.rom.spiram_incompatible_fns.ld\
		-u ld_include_panic_highint_hdl -u call_user_start_cpu0 -Wl,--gc-sections -Wl,-static -Wl,--undefined=uxTopUsedPriority -u __cxa_guard_dummy -u __cxx_fatal_exception
endif		

ifeq ($(ARDUINO_ARCH),esp8266)
	CC := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-gcc
	CXX := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-g++
	AR := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-ar
	LD := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-gcc
	OBJDUMP := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-objdump
	SIZE := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-size
	OBJCOPY_HEX_PATTERN = -eo $(ARDUINO_HOME)/bootloaders/eboot/eboot.elf -bo $(BUILD_OUT)/$(TARGET).bin \
		-bm $(FLASH_MODE) -bf $(FLASH_FREQ) -bz $(FLASH_SIZE) \
		-bs .text -bp 4096 -ec -eo $(BUILD_OUT)/$(TARGET).elf -bs .irom0.text -bs .text -bs .data -bs .rodata -bc -ec
	SIZE_REGEX_DATA = '^(?:\.data|\.rodata|\.bss)\s+([0-9]+).*'
	SIZE_REGEX = '^(?:\.irom0\.text|\.text|\.data)\s+([0-9]+).*'
	SIZE_REGEX_EEPROM = '^(?:\.eeprom)\s+([0-9]+).*'
	UPLOAD_PATTERN = $(ESPTOOL_VERBOSE) -cd $(UPLOAD_RESETMETHOD) -cb $(UPLOAD_SPEED) -cp $(SERIAL_PORT) -ca 0x00000 -cf $(BUILD_OUT)/$(TARGET).bin
	RESET_PATTERN = $(ESPTOOL_VERBOSE) -cd $(UPLOAD_RESETMETHOD) -cp $(SERIAL_PORT) -cr
	FS_UPLOAD_PATTERN = $(ESPTOOL_VERBOSE)  --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) -a soft_reset write_flash $(SPIFFS_START) 
	MKSPIFFS_PATTERN = -c $(FS_DIR) -b $(SPIFFS_BLOCKSIZE) -p $(SPIFFS_PAGESIZE) -s $(SPIFFS_SIZE) $(FS_IMAGE)
ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git 2.5.0))
	C_COMBINE_PATTERN = -Wl,-Map "-Wl,$(BUILD_OUT)/$(TARGET).map" -Wl,--start-group $(OBJ_FILES) $(LIB_OBJ_FILES) $(BUILD_OUT)/core/core.a \
		$(ELFLIBS) -Wl,--end-group -L$(BUILD_OUT)
else
	C_COMBINE_PATTERN = -Wl,--start-group $(OBJ_FILES) $(LIB_OBJ_FILES) $(BUILD_OUT)/core/core.a \
		$(ELFLIBS) -Wl,--end-group -L$(BUILD_OUT)
endif

else
	CC := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-gcc
	CXX := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-g++
	AR := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-ar
	AS := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-as
	LD := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-gcc
	OBJDUMP := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-objdump
	SIZE := $(XTENSA_TOOLCHAIN)xtensa-esp32-elf-size
	OBJCOPY_HEX_PATTERN = --chip esp32 elf2image --flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) --flash_size $(FLASH_SIZE) \
		-o $(BUILD_OUT)/$(TARGET).bin $(BUILD_OUT)/$(TARGET).elf
	OBJCOPY_EEP_PATTERN = $(ARDUINO_HOME)/tools/gen_esp32part.py -q $(ARDUINO_HOME)/tools/partitions/default.csv $(BUILD_OUT)/$(TARGET).partitions.bin
	C_COMBINE_PATTERN = -Wl,--start-group $(OBJ_FILES) $(LIB_OBJ_FILES) $(BUILD_OUT)/core/core.a \
		$(ELFLIBS) -Wl,--end-group -Wl,-EL
	SIZE_REGEX_DATA =  '^(?:\.dram0\.data|\.dram0\.bss)\s+([0-9]+).*'
	SIZE_REGEX = '^(?:\.iram0\.text|\.dram0\.text|\.flash\.text|\.dram0\.data|\.flash\.rodata)\s+([0-9]+).*'
	UPLOAD_SPEED ?= 115200
	UPLOAD_PATTERN = --chip esp32 --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED)  --before default_reset --after hard_reset write_flash -z \
		--flash_mode $(FLASH_MODE) --flash_freq $(FLASH_FREQ) \
		--flash_size detect 0xe000 $(ARDUINO_HOME)/tools/partitions/boot_app0.bin 0x1000  \
		$(ARDUINO_HOME)/tools/sdk/bin/bootloader_$(BOOT)_$(FLASH_FREQ).bin 0x10000 \
		$(BUILD_OUT)/$(TARGET).bin 0X8000 $(BUILD_OUT)/$(TARGET).partitions.bin  
	# WARNING : NOT TESTED TODO : TEST
	RESET_PATTERN = --chip esp32 --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED)  --before default_reset 
endif

.PHONY: all dirs clean upload fs upload_fs

all: sketch libs core bin size 
# size perl presentation error with cygwin
# $(PERL) -e "$$MEM_USAGE" $(SIZE_REGEX) $(SIZE_REGEX_DATA)


show_variables:
	$(info [CORE_OBJS] : $(CORE_OBJS))
	$(info [CORE_DIRS] : $(CORE_DIRS))
	$(info [ARDUINO_LIBS] : $(ARDUINO_LIBS))
	$(info [USER_LIBS] : $(USER_LIBS))
	$(info [ALIBDIRS] : $(ALIBDIRS))
	$(info [ALIB_CSRC] : $(ALIB_CSRC))
	$(info [ALIB_SSRC] : $(ALIB_SSRC))
	$(info [ALIB_CXXSRC] : $(ALIB_CXXSRC))
	$(info [OBJ_FILES] : $(OBJ_FILES))
	$(info [LIB_OBJ_FILES] : $(LIB_OBJ_FILES))
	$(info [LIB_DIRS] : $(LIB_DIRS))
	$(info [BUILD_OUT_TR] : $(BUILD_OUT_TR))
	$(info [ARDUINO_HOME] : $(ARDUINO_HOME))

dirs:
	@mkdir -p $(CORE_DIRS)
	@mkdir -p $(BUILD_OUT)/libraries
	@mkdir -p $(LIB_DIRS)

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
ifneq ("$(wildcard  $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld.h)","")
ifeq ($(ESP8266_VERSION),$(filter $(ESP8266_VERSION),git 2.5.0))
	$(CC) $(VTABLE_FLAGS) -CC -E -P  $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld.h -o $(BUILD_OUT)/local.eagle.app.v6.common.ld
else
	$(CC) $(VTABLE_FLAGS) -CC -E -P  $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld.h -o $(ESPRESSIF_SDK)/ld/eagle.app.v6.common.ld
endif
endif

$(BUILD_OUT)/core/%.S.o: $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH)/%.S
	$(CC) $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(DEFINES) $(CORE_INC:%=-I%) -o $@ $<

$(BUILD_OUT)/core/core.a: $(CORE_OBJS)
	@echo Creating core archive...
	$(AR) cru $@ $(CORE_OBJS)

$(BUILD_OUT)/core/%.c.o: %.c
	$(CC) $(CORE_DEFINE) $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(DEFINES) $(CORE_INC:%=-I%) -o $@ $<

$(BUILD_OUT)/core/%.cpp.o: %.cpp
	$(CXX) $(CORE_DEFINE) $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(DEFINES) $(CORE_INC:%=-I%)  $< -o $@

$(filter %.c.o,$(LIB_OBJ_FILES)): %.c.o:
	$(CC) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(DEFINES)  $(INCLUDES) -o $@ $(subst $(BUILD_OUT_TR),$(ARDUINO_HOME),$(subst .c.o,.c, $@))
	
$(filter %.cpp.o,$(LIB_OBJ_FILES)): %.cpp.o:
	$(CXX) -D_TAG_=\"$(TAG)\" $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) $(subst $(BUILD_OUT_TR),$(ARDUINO_HOME),$(subst .cpp.o,.cpp, $@)) -o $@

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
	$(LD) $(ELFFLAGS) -o $@ $(C_COMBINE_PATTERN)

size: $(BUILD_OUT)/$(TARGET).elf
	@$(SIZE) -A $(BUILD_OUT)/$(TARGET).elf | grep -E '^(Total|\.text|\.data|\.rodata|\.bss|\.comment|\.irom0\.text|)\s+([0-9]+).*'
	

$(BUILD_OUT)/$(TARGET).bin: $(BUILD_OUT)/$(TARGET).elf
ifeq ($(ARDUINO_ARCH),esp32)
	$(OBJCOPY_EEP_PATTERN)
endif
	$(ESPTOOL) $(OBJCOPY_HEX_PATTERN)

reset: 
	-$(ESPTOOL) $(RESET_PATTERN)

upload: $(BUILD_OUT)/$(TARGET).bin size
	$(ESPTOOL) $(UPLOAD_PATTERN)

fs:
ifneq ($(FS_FILES),)
	@rm -f $(FS_IMAGE)
	@mkdir -p $(BUILD_OUT)/spiffs
	$(MKSPIFFS) $(MKSPIFFS_PATTERN)
else
	
endif

upload_fs: fs
ifeq ($(ARDUINO_ARCH),esp8266)
	$(ESPTOOL) $(ESPTOOL_VERBOSE) -cd $(UPLOAD_RESETMETHOD) -cb $(UPLOAD_SPEED) -cp $(SERIAL_PORT) -ca $(SPIFFS_START) -cf $(FS_IMAGE)
else
	@echo upload_fs : No SPIFFS function available for $(ARDUINO_ARCH)
endif

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