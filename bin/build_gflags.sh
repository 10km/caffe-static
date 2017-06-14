#!/bin/bash
# 静态编译 gflags 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$GFLAGS_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$GFLAGS_FOLDER
remove_if_exist CMakeCache.txt
$CMAKE_EXE . $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path \
	-DBUILD_SHARED_LIBS=off \
	-DBUILD_STATIC_LIBS=on \
	-DBUILD_gflags_LIB=on \
	-DINSTALL_STATIC_LIBS=on \
	-DINSTALL_SHARED_LIBS=off \
	-DREGISTER_INSTALL_PREFIX=off
exit_on_error
remove_if_exist $install_path
make clean
make -j $MAKE_JOBS install
exit_on_error
popd