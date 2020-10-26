#!/bin/bash
# 静态交叉编译(arm) boost 源码脚本
# author guyadong@gdface.net
shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

rm $SOURCE_ROOT/$BOOST_FOLDER/b2 >/dev/null 2>&1
rm $SOURCE_ROOT/$BOOST_FOLDER/bjam >/dev/null 2>&1
rm -fr $SOURCE_ROOT/$BOOST_FOLDER/bin.v2 >/dev/null 2>&1
rm -fr $SOURCE_ROOT/$BOOST_FOLDER/project-config.jam >/dev/null 2>&1

[ ! $(which arm-linux-gnueabihf-g++) ] \
    && echo "not install compiler arm-linux-gnueabihf-g++,install please:" \
    && echo "sudo apt-get install g++-arm-linux-gnueabihf" && exit -1

CXX_COMPILER=arm-linux-gnueabihf-g++ \
C_COMPILER=arm-linux-gnueabihf-gcc \
./build_boost.sh