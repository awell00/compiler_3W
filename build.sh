#!/bin/bash

mainDir="compilation_result"

if [ ! -d "compilation" ]; then
    mkdir "compilation"
fi

mkMainDir()
{
    echo -e "\033[1;33mCréation du dossier '${mainDir}' pour les résultats de la compilation...\033[0m"
    if [ -d "compilation/${maindir}" ]; then
        echo -e "\033[1;33mAie ! '${mainDir}' existe déjà dans le répertoire courant.\033[0m"
        echo -e "\033[1;33m[1] Écraser\033[0m"
        echo -e "\033[1;33m[2] Archiver\033[0m"
        echo -e "\033[1;33m[3] Quitter\033[0m"
        read choice
        case $choice in
            1)
                rm -rf "compilation/${mainDir}" && echo -e "\033[1;33mDossier ${mainDir} supprimé.\033[0m"
                ;;
            2)
                echo -e "\033[1;33mEntrez un suffixe numérique pour archiver le dossier.\033[0m" && read suffix
                if [[ "$suffix" =~ ^[0-9]+$ ]]; then
                    if [ -d "compilation/${mainDir}_${suffix}" ]; then
                        echo -e "\033[1;31mErreur : ${mainDir}_${suffix} existe déjà.\033[0m" && exit
                    fi
                    mv "compilation/${mainDir}" "compilation/${mainDir}_${suffix}" && echo -e "\033[1;33mDossier '${mainDir}' renommé '${mainDir}_${suffix}'.\033[0m"
                else
                    echo -e "\033[1;31mErreur : Seul les chiffres sont acceptés.\033[0m" && exit
                fi
                ;;
            3)
                echo -e "\033[1;33mFin du programme.\033[0m" && exit
                ;;
            *)
                echo -e "\033[1;31mErreur : Saisie invalide.\033[0m" && exit
                ;;
        esac
    fi
    mkdir -p "compilation/${mainDir}/bin"
    mkdir -p "compilation/${mainDir}/build/obj"
    mkdir -p "compilation/${mainDir}/build/artifacts"
    mkdir -p "compilation/${mainDir}/lib"
    mkdir -p "compilation/${mainDir}/src"
    cp -r lib/* "compilation/${mainDir}/lib/" || { echo -e "\033[1;31mErreur : 'lib' introuvable.\033[0m";  rm -rf "compilation/${mainDir}" ; exit ; }
    cp -r src/* "compilation/${mainDir}/src/" || { echo -e "\033[1;31mErreur : 'src' introuvable.\033[0m";  rm -rf "compilation/${mainDir}" ; exit ; }
    echo -e "\033[1;33mNouveau dossier ${mainDir} créé.\033[0m"
    echo
}

compile()
{
    echo -e "\033[1;33mCompilation...\033[0m"

    #1) ajoute les chemins d'inclusion à la variable 'paths' pour que le préprocesseur trouve les fichiers headers

    paths="-I compilation/${mainDir}/lib/cores/arduino -I compilation/${mainDir}/lib/variants/standard -I compilation/${mainDir}/lib/libraries"
    for dir in $(find "compilation/${mainDir}/lib/libraries" -type d); do
        paths="${paths} -I $dir"
    done

    #2) compile chaque bibliothèque en fichier objet (.o)

    optimization="-Os -flto -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-asynchronous-unwind-tables -fno-fat-lto-objects"

    for file in $(find "compilation/${mainDir}/lib" -name "*.c" -o -name "*.cpp" -type f); do #pour chaque fichier c ou cpp dans lib
        extension="${file##*.}" #extrait l'extension
        filename="$(basename "${file}" .${extension})" #extrait le nom du fichier sans l'extension
        if [ "$extension" = "cpp" ]; then
            compiler=avr-g++ #compilateur C++
        else
            compiler=avr-gcc #compilateur C
        fi
        $compiler -c -mmcu=atmega328p -DF_CPU=16000000UL $optimization $paths $file -o "compilation/${mainDir}/build/obj/${filename}.${extension}.o" #compile
    done

    #3) créé un fichier archive (.a) avec les fichiers objets des bibliothèques

    avr-gcc-ar rcs "compilation/${mainDir}/build/artifacts/arlib.a" compilation/${mainDir}/build/obj/*.o

    #4) ajoute les chemins d'inclusion pour le code source

    for dir in $(find "compilation/${mainDir}/src" -type d); do
        paths="-I ${dir} ${paths}"
    done
    paths="-I compilation/${mainDir}/src ${paths}"

    #5) compile le code source

    extraOptimization="-fno-exceptions -fno-rtti -fno-asynchronous-unwind-tables -fno-unwind-tables"

    avr-g++ -c -mmcu=atmega328p -DF_CPU=16000000UL $optimization $extraOptimization $paths "compilation/${mainDir}/src/main.cpp" -o "compilation/${mainDir}/build/obj/sourcecode.o" #compile

    #6) lie le code source compilé avec l'archive des bibliothèques en un exécutable (format .elf)

    avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL $optimization -o "compilation/${mainDir}/build/artifacts/project.elf" "compilation/${mainDir}/build/obj/sourcecode.o" "compilation/${mainDir}/build/artifacts/arlib.a" -Wl,--gc-sections,--relax,--strip-all

    #7) supprime les trucs inutilisés dans le fichier .elf

    avr-strip -s -R .comment -R .gnu.version "compilation/${mainDir}/build/artifacts/project.elf"

    #8) rend le .elf flashable en le convertissant en .hex

    avr-objcopy -O ihex -R .eeprom "compilation/${mainDir}/build/artifacts/project.elf" "compilation/${mainDir}/bin/project.hex"

    echo -e "\033[1;33mProjet compilé.\033[0m"
}


upload()
{
    #9) ask for serial port

    echo -e "\033[1;33mEntrez votre port série\033[0m"
    echo -e "\033[1;33m[1] /dev/ttyACM0 #Port série pour microcontrôleurs (Ubuntu)\033[0m"
    echo -e "\033[1;33m[2] /dev/ttyUSB0 #Convertisseur USB vers série\033[0m"
    echo -e "\033[1;33m[3] /dev/ttyS0   #Port série matériel natif (Ubuntu)\033[0m"
    echo -e "\033[1;33m[4] Entrer un port série personnalisé\033[0m"
    read choice

    case $choice in
        1)
            serial="/dev/ttyACM0"
            ;;
        2)
            serial="/dev/ttyUSB0"
            ;;
        3)
            serial="/dev/ttyS0"
            ;;
        4)
            echo -e "\033[1;33mEntrez votre port série.\033[0m" && read input
            serial="$input"
            ;;
        *)
            echo -e "\033[1;31mErreur : Saisie invalide.\033[0m" && exit
            ;;
    esac

    echo -e "\033[1;33mTéléversement...\033[0m"

    baudRate=115200
    file="compilation/${mainDir}/bin/project.hex"
    mcu="atmega328p"

    #10) téléverse

    avrdude -v -p $mcu -c arduino -P $serial -b $baudRate -D -U flash:w:${file}:i || { echo -e "\033[1;31mErreur\033[0m"; echo -e "\033[1;31mÉchec du téléversement\033[0m"; exit ; }

    echo -e "\033[1;33mTéléversement réussi\033[0m"
}

echo "
 _______        __     ____ ___  __  __ ____ ___ _
|___ /\ \      / /    / ___/ _ \|  \/  |  _ \_ _| |
  |_ \ \ \ /\ / /____| |  | | | | |\/| | |_) | || |
 ___) | \ V  V /_____| |__| |_| | |  | |  __/| || |___
|____/   \_/\_/       \____\___/|_|  |_|_|  |___|_____|
                                                       "
echo -e "\033[1;33mCompilateur pour arduino uno\033[0m"
echo -e "\033[1;33m[1] Compiler\033[0m"
echo -e "\033[1;33m[2] Compiler et téléverser\033[0m"
echo -e "\033[1;33m[3] Quitter\033[0m"
echo "
_______________________________________________________
"
read choice

case $choice in
    1)
        mkMainDir
        compile
        ;;
    2)
        mkMainDir
        compile
        upload
        ;;
    3)
      echo -e "\033[1;33mFin du programme.\033[0m" && exit
      ;;
    *)
      echo -e "\033[1;31mErreur : Saisie invalide.\033[0m" && exit
      ;;
esac
