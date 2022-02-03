# ds3231-spin Makefile - requires GNU Make, or compatible
# Variables below can be overridden on the command line
#	e.g. make TARGET=DS3231_SPIN DS3231-Demo.binary

# P1, P2 device nodes and baudrates
#P1DEV=
P1BAUD=115200
#P2DEV=
P2BAUD=2000000

# P1, P2 compilers
P1BUILD=flexspin --interp=rom
#P1BUILD=flexspin
P2BUILD=flexspin -2

# For P1 only: build using the bytecode or PASM-based I2C engine
# (independent of overall bytecode or PASM build)
#TARGET=DS3231_SPIN
TARGET=DS3231_PASM

# Paths to spin-standard-library, and p2-spin-standard-library,
#  if not specified externally
SPIN1_LIB_PATH=~/spin-standard-library/library
SPIN2_LIB_PATH=~/p2-spin-standard-library/library


# -- Internal --
SPIN1_DRIVER_FN=$(SPIN1_LIB_PATH)/time.rtc.ds3231.spin
SPIN2_DRIVER_FN=$(SPIN2_LIB_PATH)/time.rtc.ds3231.spin2
SPIN1_CORE_FN=$(SPIN1_LIB_PATH)/core.con.ds3231.spin
SPIN2_CORE_FN=$(SPIN2_LIB_PATH)/core.con.ds3231.spin
# --

# Build all targets (build only)
all: DS3231-Demo.binary DS3231-Demo.bin2

# Load P1 or P2 target (will build first, if necessary)
p1demo: loadp1demo
p2demo: loadp2demo

# Build binaries
DS3231-Demo.binary: DS3231-Demo.spin $(SPIN1_DRIVER_FN) $(SPIN1_CORE_FN)
	$(P1BUILD) -L $(SPIN1_LIB_PATH) -b -D $(TARGET) DS3231-Demo.spin

DS3231-Demo.bin2: DS3231-Demo.spin2 $(SPIN2_DRIVER_FN) $(SPIN2_CORE_FN)
	$(P2BUILD) -L $(SPIN2_LIB_PATH) -b -2 -D $(TARGET) -o DS3231-Demo.bin2 DS3231-Demo.spin2

# Load binaries to RAM (will build first, if necessary)
loadp1demo: DS3231-Demo.binary
	proploader -t -p $(P1DEV) -Dbaudrate=$(P1BAUD) DS3231-Demo.binary

loadp2demo: DS3231-Demo.bin2
	loadp2 -SINGLE -p $(P2DEV) -v -b$(P2BAUD) -l$(P2BAUD) DS3231-Demo.bin2 -t

# Remove built binaries and assembler outputs
clean:
	rm -fv *.binary *.bin2 *.pasm *.p2asm

