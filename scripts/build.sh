#!/bin/bash

compile() {

  # Create necessary directories
  if [ ! -d "../build" ]; then
    mkdir "../build"
  fi

  if [ ! -d "../build/obj" ]; then
    mkdir -p "../build/obj"
  fi

  if [ ! -d "../build/bin" ]; then
    mkdir -p "../build/bin"
  fi

  if [ ! -d "../build/log" ]; then
    mkdir "../build/log"
  fi

  INCLUDE_PATHS="-I ../lib/cores/arduino -I ../lib/variants/standard"

  for dir in ../lib/libraries/*; do
    if [ -d "$dir" ]; then
      INCLUDE_PATHS="$INCLUDE_PATHS -I $dir"
      if [ -d "$dir/utility" ]; then
        INCLUDE_PATHS="$INCLUDE_PATHS -I $dir/utility"
      fi
    fi
  done

  # Optimization flags
  OPT_FLAGS="-Os -flto -ffunction-sections -fdata-sections"

  # Compile C files
  for file in ../lib/cores/arduino/*.c ../lib/libraries/*/utility/*.c; do
        avr-gcc -c -mmcu=atmega328p -DF_CPU=16000000UL $OPT_FLAGS $INCLUDE_PATHS "$file" -o "../build/obj/$(basename "${file%.c}.o")" 1>/dev/null 2> >(tee >(ts >> ../build/log/compile_errors.log) >&2)
    done

    # Compile C++ files
    for file in ../lib/cores/arduino/*.cpp ../lib/libraries/*/*.cpp ../lib/libraries/*/utility/*.cpp; do
        avr-gcc -c -mmcu=atmega328p -DF_CPU=16000000UL $OPT_FLAGS $INCLUDE_PATHS "$file" -o "../build/obj/$(basename "${file%.cpp}.o")" 1>/dev/null 2> >(tee >(ts >> ../build/log/compile_errors.log) >&2)
    done

    # Create archive with LTO
    AR=avr-gcc-ar avr-gcc-ar rcs ../build/obj/core.a ../build/obj/*.o

    # Compile main.cpp with LTO and strip unused sections
    avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL $OPT_FLAGS $INCLUDE_PATHS ../src/main.cpp ../build/obj/core.a -Wl,--gc-sections -o ../build/bin/output.elf 1>/dev/null 2> >(tee >(ts >> ../build/log/compile_errors.log) >&2)

    # Strip unused sections
    avr-strip ../build/bin/output.elf

    echo "Compilation complete"
}

upload() {
  # Convert to hex
  avr-objcopy -O ihex ../build/bin/output.elf ../build/bin/output.hex 1>/dev/null 2> >(tee >(ts >> ../build/log/compile_errors.log) >&2)

  # Upload to Arduino
  avrdude -p atmega328p -c arduino -P /dev/ttyACM0 -b 115200 -U flash:w:../build/bin/output.hex:i 1>/dev/null 2> >(tee >(ts >> ../build/log/televerse_errors.log) >&2)

  echo "Upload complete"
}

compile_and_upload() {
  compile
  upload
}

clear

echo "
 _______        __     ____ ___  __  __ ____ ___ _
|___ /\ \      / /    / ___/ _ \|  \/  |  _ \_ _| |
  |_ \ \ \ /\ / /____| |  | | | | |\/| | |_) | || |
 ___) | \ V  V /_____| |__| |_| | |  | |  __/| || |___
|____/   \_/\_/       \____\___/|_|  |_|_|  |___|_____|
                                                       "

show_menu() {
  echo -e "\033[1;37mWhat would you like to do?\033[0m"
  echo -e "\033[1;36m1) Compile Only\033[0m"
  echo -e "\033[1;36m2) Compile and Upload\033[0m"
  echo -e "\033[1;36m3) Quit\033[0m"
  echo -ne "\033[1;37mChoose an option: \033[0m"
  read choice

  case $choice in
    1)
      compile
      ;;
    2)
      echo -ne "\033[1;37mDo you want to launch the Serial Monitor after uploading? [y/n]: \033[0m"  # White
      read serialMonitor
      compile_and_upload
      if [ "$serialMonitor" = "y" ]; then
          screen /dev/ttyACM0
      fi
      ;;
    3)
      exit 0
      ;;
    *)
      echo -e "\033[1;31mInvalid option, please try again.\033[0m"  # Red
      ;;
  esac
}

# Main loop
while true; do
  show_menu
done