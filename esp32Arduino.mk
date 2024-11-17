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

SERIAL_PORT ?= /dev/tty.nodemcu
ESP32_VERSION ?= 3.0.7
OTA_PORT ?= 8266
ARDUINO_HOME ?=  $(ROOT_DIR)/esp32-$(ESP32_VERSION)
ARDUINO_VARIANT ?= nodemcu
ARDUINO_ARCH ?= $($(ARDUINO_VARIANT).build.target)
ARDUINO_VERSION ?= 10607
BOARDS_TXT  = $(ARDUINO_HOME)/boards.txt
include $(BOARDS_TXT)
ARDUINO_BOARD = $($(ARDUINO_VARIANT).build.board)
VARIANT = $($(ARDUINO_VARIANT).build.variant)
CONCATENATE_USER_FILES ?= no
FLASH_PARTITION ?= 4M1M
MCU = $($(ARDUINO_VARIANT).build.mcu)
SERIAL_BAUD   ?= 115200
CPU_FREQ ?= $($(ARDUINO_VARIANT).build.f_cpu)
FLASH_FREQ ?= $($(ARDUINO_VARIANT).build.flash_freq)
ifeq ($(FLASH_FREQ),)
	FLASH_FREQ = 80m
endif

MEMORY_TYPE = $($(ARDUINO_VARIANT).build.memory_type)
ifeq ($(MEMORY_TYPE),)
	MEMORY_TYPE = $($(ARDUINO_VARIANT).build.boot)_qspi
endif
FLASH_MODE = $($(ARDUINO_VARIANT).build.flash_mode)
#esp32c6.menu.FlashMode.qio.build.flash_mode=dio
FLASH_MODE2 ?= $($(ARDUINO_VARIANT).menu.FlashMode.$(FLASH_MODE).build.flash_mode)
ifeq ($(FLASH_MODE2),)
	FLASH_MODE2 = dio
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
BOOTLOADER_ADDR = $($(ARDUINO_VARIANT).build.bootloader_addr)
UPLOAD_MAXIMUM_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_size) 
UPLOAD_MAXIMUM_DATA_SIZE ?= $($(ARDUINO_VARIANT).upload.maximum_data_size) 
ESPRESSIF_SDK = $(ARDUINO_HOME)/tools/esp32-arduino-libs/$(MCU)
FS_DIR ?= ./data
FS_IMAGE=$(BUILD_OUT)/spiffs/spiffs.bin
FS_FILES=$(wildcard $(FS_DIR)/*)
CORE_DEBUG_LEVEL ?= 0

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

CPREPROCESSOR_FLAGS =	$(shell cat $(ESPRESSIF_SDK)/flags/defines) -iprefix $(ESPRESSIF_SDK)/include/ $(shell cat $(ESPRESSIF_SDK)/flags/includes) -I$(ESPRESSIF_SDK) \
						-I$(ESPRESSIF_SDK)/$(MEMORY_TYPE)/include

ASFLAGS =	-MMD -c -x assembler-with-cpp $(shell cat $(ESPRESSIF_SDK)/flags/S_flags) -Os -w -Werror=return-type

CFLAGS =	-MMD -c $(shell cat $(ESPRESSIF_SDK)/flags/c_flags) -Os -w -Werror=return-type

CXXFLAGS =	-MMD -c $(shell cat $(ESPRESSIF_SDK)/flags/cpp_flags) -Os -w -Werror=return-type

ELFLIBS = $(shell cat $(ESPRESSIF_SDK)/flags/ld_libs)

ARFLAGS = cr

ELFFLAGS =	$(shell cat $(ESPRESSIF_SDK)/flags/ld_flags) $(shell cat $(ESPRESSIF_SDK)/flags/ld_scripts) -Os -w -Wl,--Map=$(BUILD_OUT)/project.map \
			-L$(ESPRESSIF_SDK)/lib -L$(ESPRESSIF_SDK)/ld -L$(ESPRESSIF_SDK)/$(MEMORY_TYPE) -Wl,--wrap=esp_panic_handler

BUILD_EXTRA_FLAGS ?= -DARDUINO_HOST_OS=\"windows\" -DESP32=ESP32 -DCORE_DEBUG_LEVEL=$(CORE_DEBUG_LEVEL) \
	$($(ARDUINO_VARIANT).build.loop_core) $($(ARDUINO_VARIANT).build.loop_core) $($(ARDUINO_VARIANT).build.event_core) $($(ARDUINO_VARIANT).build.defines)
	
						
ifeq ($(MCU),esp32)
	BUILD_EXTRA_FLAGS += -DARDUINO_USB_CDC_ON_BOOT=0
endif #!ESP32

ifeq ($(MCU),esp32s2)
	BUILD_EXTRA_FLAGS += -DARDUINO_USB_MODE=0 -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) \
						-DARDUINO_USB_MSC_ON_BOOT=$($(ARDUINO_VARIANT).build.msc_on_boot) -DARDUINO_USB_DFU_ON_BOOT=$($(ARDUINO_VARIANT).build.dfu_on_boot)
endif #!S2

ifeq ($(MCU),esp32s3)
	BUILD_EXTRA_FLAGS += -DARDUINO_USB_MODE=$($(ARDUINO_VARIANT).build.usb_mode) -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) \
						-DARDUINO_USB_MSC_ON_BOOT=$($(ARDUINO_VARIANT).build.msc_on_boot) -DARDUINO_USB_DFU_ON_BOOT=$($(ARDUINO_VARIANT).build.dfu_on_boot)
	MEMORY_TYPE = $($(ARDUINO_VARIANT).build.boot)_$($(ARDUINO_VARIANT).build.psram_type)
endif #!s3

ifeq ($(MCU),esp32c3)
	BUILD_EXTRA_FLAGS += -DARDUINO_USB_MODE=1 -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) 
endif #!c3

ifeq ($(MCU),esp32c6)
	BUILD_EXTRA_FLAGS += -DARDUINO_USB_MODE=1 -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot) $($(ARDUINO_VARIANT).build.zigbee_mode) \
		-DARDUINO_FQBN=\"esp32:esp32:esp32c6:UploadSpeed=921600,CDCOnBoot=default,CPUFreq=160,FlashFreq=80,FlashMode=qio,FlashSize=4M,PartitionScheme=default,DebugLevel=none,EraseFlash=none,JTAGAdapter=default,ZigbeeMode=default\" 
endif #!c6

ifeq ($(MCU),esp32h2)
	BUILD_EXTRA_FLAGS += -DARDUINO_USB_MODE=1 -DARDUINO_USB_CDC_ON_BOOT=$($(ARDUINO_VARIANT).build.cdc_on_boot)
	FLASH_FREQ = 16m
endif #!h2


CC := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-gcc
CXX := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-g++
AR := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-ar
AS := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-as
LD := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-g++
OBJDUMP := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-objdump
SIZE := $(XTENSA_TOOLCHAIN)$($(ARDUINO_VARIANT).build.tarch)-$(ARDUINO_ARCH)-elf-size

OBJCOPY_BIN_PATTERN = --chip $(MCU) elf2image --flash_mode $(FLASH_MODE2) --flash_freq $(FLASH_FREQ) \
	--flash_size $(FLASH_SIZE) --elf-sha256-offset 0xb0 -o $(BUILD_OUT)/$(TARGET).bin $(BUILD_OUT)/$(TARGET).elf

#                                                                  -q "                            VerySimple.ino.partitions.bin"

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
UPLOAD_SPEED ?= 921600
# WARNING : NOT TESTED TODO : TEST
RESET_PATTERN = --chip $(MCU) --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED)  --after hard_reset read_mac

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

$(BUILD_OUT)/core/%.S.o: $(ARDUINO_HOME)/cores/esp32/%.S
	$(CC) -DARDUINO_CORE_BUILD $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(BUILD_EXTRA_FLAGS) $(DEFINES) $(CORE_INC:%=-I%) -o $@ $<

$(BUILD_OUT)/core/%.c.o: %.c
	$(CC) -DARDUINO_CORE_BUILD $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(BUILD_EXTRA_FLAGS) $(DEFINES) $(CORE_INC:%=-I%) -o $@ $<

$(BUILD_OUT)/core/%.cpp.o: %.cpp
	$(CXX) -DARDUINO_CORE_BUILD $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(BUILD_EXTRA_FLAGS) $(DEFINES) $(CORE_INC:%=-I%)  $< -o $@

$(BUILD_OUT)/core/core.a: $(CORE_OBJS)
	@echo Creating core archive...
	$(AR) $(ARFLAGS) $@ $(CORE_OBJS)

$(BUILD_OUT)/libraries/%.c.o: %.c
	$(CC) $(CPREPROCESSOR_FLAGS) $(CFLAGS) $(BUILD_EXTRA_FLAGS) $(DEFINES) -D_TAG_=\"$(TAG)\" $(INCLUDES) -o $@ $<

$(BUILD_OUT)/libraries/%.cpp.o: %.cpp
	$(CXX) $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) $(BUILD_EXTRA_FLAGS) $(DEFINES) -D_TAG_=\"$(TAG)\" $(INCLUDE_ARDUINO_H) $(INCLUDES) $< -o $@	

$(BUILD_OUT)/libraries/%.S.o: %.S
	$(CC) $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(DEFINES) $(BUILD_EXTRA_FLAGS) $(USER_DEFINE) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.c.o: %.c
	$(CC) -D_TAG_=\"$(TAG)\" $(CFLAGS) $(CPREPROCESSOR_FLAGS) $(BUILD_EXTRA_FLAGS) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.cpp.o: %.cpp
	$(CXX) $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) -D_TAG_=\"$(TAG)\" $(BUILD_EXTRA_FLAGS) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) $< -o $@	

$(BUILD_OUT)/%.S.o: %.S
	$(CC) $(CPREPROCESSOR_FLAGS) $(ASFLAGS) $(BUILD_EXTRA_FLAGS) $(DEFINES) $(USER_DEFINE) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.ino.cpp: $(USER_INOSRC)
ifeq ($(CONCATENATE_USER_FILES), yes)
	-$(CAT) $(TARGET).ino $(filter-out $(TARGET).ino,$^) > $@
else
	ln -s ../$(TARGET).ino $@
endif

$(BUILD_OUT)/%.ino.cpp.o: $(BUILD_OUT)/%.ino.cpp
	$(CXX) $(CPREPROCESSOR_FLAGS) $(CXXFLAGS) $(USER_DEFINE) -D_TAG_=\"$(TAG)\" $(BUILD_EXTRA_FLAGS) $(DEFINES) $(INCLUDE_ARDUINO_H) $(INCLUDES) $< -o $@

$(BUILD_OUT)/$(TARGET).elf: sketch core libs
	$(LD) $(C_COMBINE_PATTERN) -o $@ 

size: $(BUILD_OUT)/$(TARGET).elf
	@$(SIZE) -A $(BUILD_OUT)/$(TARGET).elf | perl -e "$$MEM_USAGE" $(SIZE_REGEX) $(SIZE_REGEX_DATA)

$(BUILD_OUT)/$(TARGET).bin: $(BUILD_OUT)/$(TARGET).elf
	$(PYTHON) $(ESPTOOL) $(OBJCOPY_BIN_PATTERN)
	
	#recipe.hooks.objcopy.postobjcopy.1
	# TODO shell [ ! -d "{build.path}"/libraries/Insights ] || {tools.gen_insights_pkg.cmd} {recipe.hooks.objcopy.postobjcopy.1.pattern_args}"
	#recipe.hooks.objcopy.postobjcopy.2
	# TODO shell [ ! -d "{build.path}"/libraries/ESP_SR ] || [ ! -f "{compiler.sdk.path}"/esp_sr/srmodels.bin ] || cp -f "{compiler.sdk.path}"/esp_sr/srmodels.bin "{build.path}"/srmodels.bin"
	#recipe.hooks.objcopy.postobjcopy.3
	$(PYTHON) $(ESPTOOL) --chip $(MCU) merge_bin -o $(BUILD_OUT)/$(TARGET).merged.bin --fill-flash-size $(FLASH_SIZE) --flash_mode keep --flash_freq keep --flash_size keep \
		$(BOOTLOADER_ADDR) $(BUILD_OUT)/$(TARGET).bootloader.bin 0x8000 $(BUILD_OUT)/$(TARGET).partitions.bin 0xe000 \
		$(ARDUINO_HOME)/tools/partitions/boot_app0.bin 0x10000 $(BUILD_OUT)/$(TARGET).bin
	@sha256sum $(BUILD_OUT)/$(TARGET).bin > $(BUILD_OUT)/$(TARGET).sha

reset: 
	$(PYTHON) $(ESPTOOL) $(RESET_PATTERN)

upload: all
	$(PYTHON) $(ESPTOOL) --chip $(MCU) --port $(SERIAL_PORT) --baud $(UPLOAD_SPEED) $(UPLOAD_FLAGS) --before default_reset --after hard_reset write_flash \
		$($(ARDUINO_VARIANT).upload.erase_cmd) -z --flash_mode keep \
		--flash_freq keep --flash_size keep $(BOOTLOADER_ADDR) $(BUILD_OUT)/$(TARGET).bootloader.bin \
		0x8000 $(BUILD_OUT)/$(TARGET).partitions.bin \
		0xe000 $(ARDUINO_HOME)/tools/partitions/boot_app0.bin \
		0x10000 $(BUILD_OUT)/$(TARGET).bin  $($(ARDUINO_VARIANT).upload.extra_flags)
erase:
	$(PYTHON) $(UPLOADTOOL) --chip $(MCU) --port $(SERIAL_PORT) erase_flash

fs:
ifneq ($(strip $(FS_FILES)),)
	@rm -f $(FS_IMAGE)
	@mkdir -p $(BUILD_OUT)/spiffs
	$(MKSPIFFS) $(MKSPIFFS_PATTERN)
endif

prebuild:
	# recipe.hooks.prebuild.1.pattern
	@test ! -f $(USRCDIRS)/partitions.csv || cp  $(USRCDIRS)/partitions.csv $(BUILD_OUT)
	# recipe.hooks.prebuild.2.pattern
	@test -f $(BUILD_OUT)/partitions.csv || test ! -f $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv || cp $(ARDUINO_HOME)/variants/$(VARIANT)/partitions.csv $(BUILD_OUT)
	# recipe.hooks.prebuild.3.pattern
	@test -f $(BUILD_OUT)/partitions.csv || cp $(ARDUINO_HOME)/tools/partitions/default.csv $(BUILD_OUT)/partitions.csv
	# recipe.hooks.prebuild.4.pattern
	@test ! -f $(USRCDIRS)/bootloader.bin || cp  $(USRCDIRS)/bootloader.bin $(BUILD_OUT)/$(TARGET).bootloader.bin
	@test -f $(BUILD_OUT)/bootloader.bin || test ! -f $(ARDUINO_HOME)/variants/$(VARIANT)/bootloader.bin || cp $(ARDUINO_HOME)/variants/$(VARIANT)/bootloader.bin $(BUILD_OUT)/$(TARGET).bootloader.bin
#"                                                  esptool.exe" --chip esp32c6 elf2image --flash_mode dio --flash_freq 80m --flash_size 4MB -o "C:\\Users\\arlau\\AppData\\Local\\Temp\\arduino\\sketches\\7C7934C1F04211AEDFCB6900C1CC883A\\VerySimple.ino.bootloader.bin" "C:\\Users\\arlau\\AppData\\Local\\Arduino15\\packages\\esp32\\tools\\esp32-arduino-libs\\idf-release_v5.1-632e0c2a\\esp32c6\\bin\\bootloader_qio_80m.elf" ) )	
	test -f $(BUILD_OUT)/bootloader.bin || $(PYTHON) $(ESPTOOL) --chip $(MCU) elf2image --flash_mode $(FLASH_MODE2) --flash_freq $(FLASH_FREQ) \
	--flash_size $(FLASH_SIZE) -o $(BUILD_OUT)/$(TARGET).bootloader.bin $(ARDUINO_HOME)/tools/esp32-arduino-libs/$(MCU)/bin/bootloader_$(FLASH_MODE)_$(FLASH_FREQ).elf  
	# recipe.hooks.prebuild.5.pattern
	@test ! -f $(USRCDIRS)/build_opt.h || cp  $(USRCDIRS)/build_opt.h $(BUILD_OUT)
	# recipe.hooks.prebuild.6.pattern
	@test -f $(USRCDIRS)/build_opt.h || touch $(BUILD_OUT)/build_opt.h
	
	# recipe.hooks.prebuild.8.pattern
	@cp -f $(ESPRESSIF_SDK)/sdkconfig $(BUILD_OUT)/sdkconfig
	$(PYTHON) $(OBJCOPY_PARTITION_PATTERN)

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