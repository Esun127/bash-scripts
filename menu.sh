#!/bin/bash

declare -i time
function modechoose(){
    #clear
    echo -e "\033[8;30H1) easy mode"
    echo -e "\033[9;30H2) normal mode"
    echo -e "\033[10;30H3) difficult mode"
    echo -ne "\033[22;2H Please input yur choice: "
    read mode
    case $mode in
        "1")
            time=10
            dismenu
            ;;
        "2")
            time=5
            dismenu
            ;;
        "3")
            time=3
            dismenu
            ;;
        *)
            echo -e "\033[22;2H Your choice is wrong, please try again"
            sleep 1
            ;;
    esac
}

modechoose
