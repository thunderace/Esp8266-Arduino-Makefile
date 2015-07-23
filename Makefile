TARGET = $(notdir $(realpath .))
ROOT_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

#-include local.mk

SERIAL_PORT ?= /dev/tty.nodemcu

# arduino installation and 3rd party hardware folder stuff
ARDUINO_HOME ?= $(wildcard ~/arduino)
ARDUINO_BIN ?= $(ARDUINO_HOME)/arduino
ARDUINO_VENDOR = esp8266com
ARDUINO_ARCH = esp8266
ARDUINO_BOARD ?= ESP8266_ESP12
ARDUINO_VARIANT ?= nodemcu
ARDUINO_CORE ?= $(ARDUINO_HOME)/hardware/$(ARDUINO_VENDOR)/$(ARDUINO_ARCH)
ARDUINO_VERSION ?= 10605
#ESPTOOL_VERBOSE ?= -vv

ifndef BOARDS_TXT
BOARDS_TXT  = $(ARDUINO_CORE)/boards.txt
endif

ifndef PARSE_BOARD
PARSE_BOARD = $(ROOT_DIR)/bin/ard-parse-boards
endif

ifndef PARSE_BOARD_OPTS
PARSE_BOARD_OPTS = --boards_txt=$(BOARDS_TXT)
endif

ifndef PARSE_BOARD_CMD
PARSE_BOARD_CMD = $(PARSE_BOARD) $(PARSE_BOARD_OPTS)
endif

# Which variant ? This affects the include path
ifndef VARIANT
VARIANT = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.variant)
endif

# processor stuff
ifndef MCU
MCU   = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.mcu)
endif

# upload speed
ifndef SERIAL_BAUD
SERIAL_BAUD   = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.speed)
endif

ifndef F_CPU
F_CPU = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.f_cpu)
endif

ifndef FLASH_SIZE
FLASH_SIZE = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_size)
endif

ifndef FLASH_MODE
FLASH_MODE = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_mode)
endif

ifndef FLASH_FREQ
FLASH_FREQ = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) build.flash_freq)
endif

ifndef UPLOAD_RESETMETHOD
UPLOAD_RESETMETHOD = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.resetmethod)
endif

ifndef UPLOAD_SPEED
UPLOAD_SPEED = $(shell $(PARSE_BOARD_CMD) $(ARDUINO_VARIANT) upload.speed)
endif


DEP_FILE   = $(BUILD_OUT)/depends.mk
DEPS            = $(OBJ_FILES:.o=.d)


# sketch-specific
USER_LIBDIR = ../libraries
#USER_LIBS = Ticker #AQMath HTU21D IRremote RCSwitch

XTENSA_TOOLCHAIN = $(ARDUINO_CORE)/tools/xtensa-lx106-elf/bin/
# XTENSA_TOOLCHAIN ?=
ESPRESSIF_SDK = $(ARDUINO_CORE)/tools/sdk
ESPTOOL = $(ARDUINO_CORE)/tools/esptool

BUILD_OUT = ./build.$(ARDUINO_VARIANT)

CORE_SSRC = $(wildcard $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/*.S)
CORE_SRC = $(wildcard $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/*.c)
# spiffs files are in a subdirectory, don't know much about makefiles
CORE_SRC += $(wildcard $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/*/*.c)
CORE_CXXSRC = $(wildcard $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/*.cpp)
CORE_OBJS = $(addprefix $(BUILD_OUT)/, \
	$(notdir $(CORE_SSRC:.S=.S.o) $(CORE_SRC:.c=.c.o) $(CORE_CXXSRC:.cpp=.cpp.o)))

# arduino libraries
ALIBDIRS = $(sort $(dir $(wildcard \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/hardware/$(ARDUINO_VENDOR)/$(ARDUINO_ARCH)/libraries/%/*.c) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/hardware/$(ARDUINO_VENDOR)/$(ARDUINO_ARCH)/libraries/%/*.cpp) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/hardware/$(ARDUINO_VENDOR)/$(ARDUINO_ARCH)/libraries/%/src/*.c) \
	$(ARDUINO_LIBS:%=$(ARDUINO_HOME)/hardware/$(ARDUINO_VENDOR)/$(ARDUINO_ARCH)/libraries/%/src/*.cpp))))

# user libraries and sketch code
ULIBDIRS = . $(sort $(dir $(wildcard \
	$(USER_LIBS:%=$(USER_LIBDIR)/%/*.c) \
	$(USER_LIBS:%=$(USER_LIBDIR)/%/*.cpp) \
	$(USER_LIBS:%=$(USER_LIBDIR)/%/src/*.c) \
	$(USER_LIBS:%=$(USER_LIBDIR)/%/src/*.cpp))))

# all sources
LIB_SRC = $(wildcard $(addsuffix /*.c,$(ULIBDIRS))) \
	$(wildcard $(addsuffix /*.c,$(ALIBDIRS)))
LIB_CXXSRC = $(wildcard $(addsuffix /*.cpp,$(ULIBDIRS))) \
	$(wildcard $(addsuffix /*.cpp,$(ALIBDIRS))) 

# object files
OBJ_FILES = $(addprefix $(BUILD_OUT)/,$(notdir $(LIB_SRC:.c=.c.o) $(LIB_CXXSRC:.cpp=.cpp.o)))

DEFINES = -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ \
	-DF_CPU=$(F_CPU) -DARDUINO=$(ARDUINO_VERSION) \
	-DARDUINO_$(ARDUINO_BOARD) -DESP8266 \
	-DARDUINO_ARCH_$(shell echo "$(ARDUINO_ARCH)" | tr '[:lower:]' '[:upper:]') \
	-I$(ESPRESSIF_SDK)/include

CORE_INC = $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH) \
	$(ARDUINO_CORE)/variants/$(ARDUINO_VARIANT) \
# can't figure this out
CORE_INC += $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/spiffs

INCLUDES = $(CORE_INC:%=-I%) $(ALIBDIRS:%=-I%) $(ULIBDIRS:%=-I%)
VPATH = . $(CORE_INC) $(ALIBDIRS) $(ULIBDIRS)

ASFLAGS = -c -g -x assembler-with-cpp -MMD $(DEFINES)
CFLAGS = -c -Os -Wpointer-arith -Wno-implicit-function-declaration -Wl,-EL \
	-fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals \
	-falign-functions=4 -MMD -std=c99
CXXFLAGS = -c -Os -mlongcalls -mtext-section-literals -fno-exceptions \
	-fno-rtti -falign-functions=4 -std=c++11 -MMD

LDFLAGS = -nostdlib -Wl,--no-check-sections -u call_user_start -Wl,-static

CC := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-gcc
CXX := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-g++
AR := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-ar
LD := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-gcc
OBJDUMP := $(XTENSA_TOOLCHAIN)xtensa-lx106-elf-objdump
SIZE:=$(XTENSA_TOOLCHAIN)xtensa-lx106-elf-size


.PHONY: all arduino dirs clean

all: dirs core libs bin
# all: arduino


dirs:
	@mkdir -p $(BUILD_OUT)

clean:
	rm -rf $(BUILD_OUT)

core: dirs $(BUILD_OUT)/core.a

libs: dirs $(OBJ_FILES)

bin: $(BUILD_OUT)/$(TARGET).bin

$(BUILD_OUT)/%.o: $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/%.c
	$(CC) $(DEFINES) $(CORE_INC:%=-I%) $(CFLAGS) -o $@ $<

# ugly, someone fix this
$(BUILD_OUT)/%.o: $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/spiffs/%.c
	$(CC) $(DEFINES) $(CORE_INC:%=-I%) $(CFLAGS) -o $@ $<

$(BUILD_OUT)/%.o: $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/%.cpp
	$(CXX) $(DEFINES) $(CORE_INC:%=-I%) $(CXXFLAGS) -o $@ $<

$(BUILD_OUT)/%.S.o: $(ARDUINO_CORE)/cores/$(ARDUINO_ARCH)/%.S
	$(CC) $(ASFLAGS) -o $@ $<

$(BUILD_OUT)/core.a: $(CORE_OBJS)
	$(AR) cru $@ $(CORE_OBJS)

$(BUILD_OUT)/%.c.o: %.c
	$(CC) $(DEFINES) $(CFLAGS) $(INCLUDES) -o $@ $<

$(BUILD_OUT)/%.cpp.o: %.cpp
	$(CXX) $(DEFINES) $(CXXFLAGS) $(INCLUDES) $< -o $@

# ultimately, use our own ld scripts ...
$(BUILD_OUT)/$(TARGET).elf: core libs
	$(LD) $(LDFLAGS) -L$(ESPRESSIF_SDK)/lib \
		-L$(ESPRESSIF_SDK)/ld -T$(ESPRESSIF_SDK)/ld/eagle.flash.4m.ld \
		-o $@ -Wl,--start-group $(OBJ_FILES) $(BUILD_OUT)/core.a \
		-lm -lgcc -lhal -lphy -lnet80211 -llwip -lwpa -lmain -lpp -lsmartconfig \
		-Wl,--end-group -L$(BUILD_OUT)
		$(SIZE) -A $(BUILD_OUT)/$(TARGET).elf | grep -E '^(?:\.text|\.data|\.rodata|\.irom0\.text|)\s+([0-9]+).*'


$(BUILD_OUT)/$(TARGET).bin: $(BUILD_OUT)/$(TARGET).elf
	$(ESPTOOL) -eo $(BUILD_OUT)/$(TARGET).elf -bo $(BUILD_OUT)/$(TARGET)_00000.bin \
		-bm $(FLASH_MODE) -bf $(FLASH_FREQ) -bz $(FLASH_SIZE) \
		-bs .text -bs .data -bs .rodata -bc -ec -eo $(BUILD_OUT)/$(TARGET).elf -es .irom0.text $(BUILD_OUT)/$(TARGET)_10000.bin -ec  

upload: $(BUILD_OUT)/$(TARGET).bin
	$(ESPTOOL) $(ESPTOOL_VERBOSE) -cd $(UPLOAD_RESETMETHOD) -cb $(UPLOAD_SPEED) -cp $(SERIAL_PORT) -ca 0x00000 -cf $(BUILD_OUT)/$(TARGET)_00000.bin -ca 0x10000 -cf $(BUILD_OUT)/$(TARGET)_10000.bin


#build
#esptool -bz 4M -eo app.elf -bo app_00000.bin -bs .text -bs .data -bs .rodata -bc -ec -eo app.elf -es .irom0.text app_40000.bin -ec
#upload
#esptool -cp COM5 -cd none -cb 115200 -ca 0x00000 -cf 00000.bin -ca 0x40000 -cf 40000.bin


term:
	minicom -D $(SERIAL_PORT) -b $(UPLOAD_SPEED)

print-%  : ; @echo $* = $($*)


depends:	$(DEPS)
		cat $(DEPS) > $(DEP_FILE)

$(DEP_FILE):	$(BUILD_OUT) $(DEPS)
		cat $(DEPS) > $(DEP_FILE)
