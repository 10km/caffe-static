#!/bin/bash
# 静态编译 protobuf 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars


install_path=$PROTOBUF_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$PROTOBUF_FOLDER
clean_folder build.gcc
pushd build.gcc
$CMAKE_EXE "`dirs +1`/cmake" $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path  \
	-Dprotobuf_BUILD_TESTS=off \
	-Dprotobuf_BUILD_SHARED_LIBS=off\
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++" 

exit_on_error

remove_if_exist $install_path
make -j $MAKE_JOBS install
popd
rm -fr build.gcc
popd
