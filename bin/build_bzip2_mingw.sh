#!/bin/bash
# cmake静态编译 bzip2 1.0.5源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$BZIP2_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$BZIP2_FOLDER
clean_folder build.gcc
pushd build.gcc
$CMAKE_EXE .. $CMAKE_VARS_DEFINE -DCMAKE_TOOLCHAIN_FILE=$BIN_ROOT/Toolchain-mingw.cmake -DCMAKE_INSTALL_PREFIX=$install_path \
	-DBUILD_SHARED_LIBS=off 
exit_on_error
remove_if_exist $install_path
make -j $MAKE_JOBS install
exit_on_error
popd
rm -fr build.gcc
popd
