#!/bin/bash
# 静态交叉编译(arm) boost 源码脚本
# author guyadong@gdface.net

[ ! $(which arm-linux-gnueabihf-g++) ] \
    && echo "not install compiler arm-linux-gnueabihf-g++,install please:" \
    && echo "sudo apt-get install g++-arm-linux-gnueabihf" \
    && echo "sudo apt-get install gcc-arm-linux-gnueabihf" \
    && exit -1

CXX=arm-linux-gnueabihf-g++ \
CC=arm-linux-gnueabihf-gcc \
./build_boost.sh