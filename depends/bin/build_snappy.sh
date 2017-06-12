#!/bin/bash
# 静态编译 snappy 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$SNAPPY_INSTALL_PATH
echo install_path:$install_path
remove_if_exist $install_path
gflags_DIR=$GFLAGS_INSTALL_PATH/lib/cmake/gflags
exit_if_not_exist $gflags_DIR "not found $gflags_DIR,please build $GFLAGS_PREFIX"

pushd $SOURCE_ROOT/$SNAPPY_FOLDER
clean_folder build.gcc
pushd build.gcc
$CMAKE_EXE "$(dirs +1)" $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path -DGflags_DIR=$gflags_DIR -DBUILD_SHARED_LIBS=off
exit_on_error
make -j $MAKE_JOBS install
exit_on_error
popd
rm -fr build.gcc
popd
