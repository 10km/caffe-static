#!/bin/bash
# 编译 lmdb 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$LMDB_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$LMDB_FOLDER/libraries/liblmdb
make clean
exit_on_error
clean_folder $install_path
make -j $MAKE_JOBS CC=$MAKE_C_COMPILER DESTDIR="$install_path" install 
popd
