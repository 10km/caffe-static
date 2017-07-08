#!/bin/bash
# 静态编译 OpenBLAS 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$OPENBLAS_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$OPENBLAS_FOLDER
make clean
exit_on_error
# NO_SHARED=1 不编译动态库
# NOFORTRAN=1 不编译fortran
# DYNAMIC_ARCH=1 动态架构模式(根据cpu类型自动切换内核)
make -j $MAKE_JOBS CC=$MAKE_C_COMPILER NOFORTRAN=1 NO_SHARED=1 DYNAMIC_ARCH=1
if [  $? -ne 0 ]
then
		make clean
		exit_on_error
		# 如果编译出错，加上NO_AVX2=1再尝试一次,解决Error: no such instruction: `vpermpd` 
		make -j $MAKE_JOBS CC=$MAKE_C_COMPILER NOFORTRAN=1 NO_SHARED=1 DYNAMIC_ARCH=1 NO_AVX2=1
		exit_on_error
fi

remove_if_exist $install_path
make install PREFIX=$install_path NO_LAPACKE=1 NO_SHARED=1
popd
