#!/bin/bash
# 静态编译 glog 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$GLOG_INSTALL_PATH
echo install_path:$install_path
gflags_DIR=$GFLAGS_INSTALL_PATH/lib/cmake/gflags
exit_if_not_exist $gflags_DIR "not found $gflags_DIR,please build $GFLAGS_PREFIX"
pushd $SOURCE_ROOT/$GLOG_FOLDER
remove_if_exist CMakeCache.txt
$CMAKE_EXE . $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path \
	-Dgflags_DIR=$gflags_DIR \
#	-DBUILD_SHARED_LIBS=on

exit_on_error
remove_if_exist $install_path
make clean
make -j $MAKE_JOBS install
exit_on_error
popd
