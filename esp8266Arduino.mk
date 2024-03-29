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
ESP8266_VERSION?=3.1.2
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
CPU_FREQ ?= 80
DEFAULT_FLASH_FREQ = 40
FLASH_FREQ ?= $($(ARDUINO_VARIANT).build.flash_freq)
ifeq ($(FLASH_FREQ),)
	FLASH_FREQ = $(DEFAULT_FLASH_FREQ)
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

ESPRESSIF_SDK = $(ARDUINO_HOME)/tools/sdk
FS_DIR ?= ./data
FS_IMAGE=$(BUILD_OUT)/spiffs/spiffs.bin
FS_FILES=$(wildcard $(FS_DIR)/*)

MKSPIFFS=$(ARDUINO_HOME)/tools/mkspiffs/mkspiffs$(EXEC_EXT)
ESPOTA ?= $(ARDUINO_HOME)/tools/espota.py
XTENSA_TOOLCHAIN ?= $(ARDUINO_HOME)/tools/xtensa-lx106-elf/bin/
PYTHON = $(ARDUINO_HOME)/tools/python3/python3$(EXEC_EXT)
ESPTOOL ?= $(ARDUINO_HOME)/tools/elf2bin.py
UPLOADTOOL ?= $(ARDUINO_HOME)/tools/upload.py
ESP8266_SDK ?= NONOSDK22x_190703
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

CPREPROCESSOR_FLAGS = -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ -D_GNU_SOURCE -I$(ESPRESSIF_SDK)/include -I$(ESPRESSIF_SDK)/$(LWIP_INCLUDE) -I$(ESPRESSIF_SDK)/libc/xtensa-lx106-elf/include -I$(BUILD_OUT)/core

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

CORE_INC = $(ARDUINO_HOME)/cores/$(ARDUINO_ARCH) \
	$(ARDUINO_HOME)/variants/$(VARIANT)

INCLUDE_ARDUINO_H = -include Arduino.h
INCLUDES =  $(CORE_INC:%=-I%) $(ALIBDIRS:%=-I%) $(ULIBDIRS:%=-I%)  $(USRCDIRS:%=-I%)

VPATH = . $(CORE_INC) $(ALIBDIRS) $(ULIBDIRS)

WARNING_FLAGS ?= -w
EXCEPTION_FLAGS ?= -fno-exceptions

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
.PHONY: all dirs clean upload fs upload_fs

all: sketch libs core bin size


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
	$(LD) $(ELFFLAGS) $(C_COMBINE_PATTERN) -o $@ 

size: $(BUILD_OUT)/$(TARGET).elf
	@$(SIZE) -A $(BUILD_OUT)/$(TARGET).elf | perl -e "$$MEM_USAGE" $(SIZE_REGEX) $(SIZE_REGEX_DATA)

$(BUILD_OUT)/$(TARGET).bin: $(BUILD_OUT)/$(TARGET).elf
	$(ESPTOOL) $(OBJCOPY_HEX_PATTERN)
	@sha256sum $(BUILD_OUT)/$(TARGET).bin > $(BUILD_OUT)/$(TARGET).sha

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
	@echo "SPIFFS Uploading Image..."
	@echo "[SPIFFS] upload   : " $(FS_IMAGE)
	@echo "[SPIFFS] address  : " $(SPIFFS_START)
	@echo "[SPIFFS] reset    : " $(UPLOAD_RESETMETHOD)
	@echo "[SPIFFS] port     : " $(SERIAL_PORT)
	@echo "[SPIFFS] speed    : " $(UPLOAD_SPEED)
	@echo "[SPIFFS] uploader : " $(ARDUINO_HOME)/tools/esptool/esptool.py
	
	#/home/thunder/Esp8266-Arduino-Makefile/esp8266-2.6.1/tools/python3/python3 /home/thunder/Esp8266-Arduino-Makefile/esp8266-2.6.1/tools/esptool/esptool.py --chip esp8266 --port /dev/ttyUSB0 --baud 115200   write_flash  0x300000 ./build.nodemcuv2.ArDomo23-2.6.1/spiffs/spiffs.bin
	$(PYTHON) $(ARDUINO_HOME)/tools/esptool/esptool.py --chip esp8266 --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) write_flash $(SPIFFS_START) $(FS_IMAGE) 

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