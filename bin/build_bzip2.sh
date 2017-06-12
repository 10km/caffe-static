#!/bin/bash
# 静态编译 bzip2 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$BZIP2_INSTALL_PATH
echo install_path:$install_path
remove_if_exist $install_path
pushd $SOURCE_ROOT/$BZIP2_FOLDER
make clean
exit_on_error
make install -j $MAKE_JOBS  PREFIX=$install_path 
popd
