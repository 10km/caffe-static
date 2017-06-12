#!/bin/bash
# 编译 leveldb 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$LEVELDB_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$LEVELDB_FOLDER
make clean
#指定编译器
export CC=$MAKE_C_COMPILER
export CXX=$MAKE_CXX_COMPILER
make -j $MAKE_JOBS
exit_on_error
echo install_path:$install_path
clean_folder $install_path
mkdir "$install_path/include"
mkdir "$install_path/lib"
cp -v -d  libleveldb.so* "$install_path/lib"
cp -v libleveldb.a "$install_path/lib"
cp -v -R include/* "$install_path/include"
popd
