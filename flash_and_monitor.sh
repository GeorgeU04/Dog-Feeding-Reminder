#!/bin/bash

set -e

MCU="atmega328p"
CLOCK="1000000UL"
OPTIMIZATION="-Os"
HEX_FILE="firmware.hex"
ELF_FILE="firmware.elf"
PROGRAMMER="atmelice_isp"

COMMON_FLAGS=(-mmcu="$MCU" -DF_CPU="$CLOCK" "$OPTIMIZATION")
OBJECTS=()

shopt -s nullglob

echo "Assembling..."
for src in *.S; do
    obj="${src%.S}.o"
    avr-gcc "${COMMON_FLAGS[@]}" -x assembler-with-cpp -c "$src" -o "$obj"
    OBJECTS+=("$obj")
done

echo "Compiling..."
for src in *.c; do
    obj="${src%.c}.o"
    avr-gcc "${COMMON_FLAGS[@]}" -c "$src" -o "$obj"
    OBJECTS+=("$obj")
done

if [ ${#OBJECTS[@]} -eq 0 ]; then
    echo "No source files (*.S or *.c) found!"
    exit 1
fi

echo "Linking..."
avr-gcc -mmcu="$MCU" -o "$ELF_FILE" "${OBJECTS[@]}"

echo "Converting ELF to HEX..."
avr-objcopy -O ihex "$ELF_FILE" "$HEX_FILE"

echo "Uploading to ATmega328P..."
avrdude -c "$PROGRAMMER" -p "$MCU" -U "flash:w:$HEX_FILE:i"

echo "Done."
