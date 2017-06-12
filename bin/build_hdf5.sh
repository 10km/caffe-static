#!/bin/bash
# 静态编译 hdf5 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$HDF5_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$HDF5_FOLDER
clean_folder build.gcc
pushd build.gcc
#	-DHDF5_ENABLE_SZIP_SUPPORT=on \
#	-DHDF5_ENABLE_Z_LIB_SUPPORT=on \

$CMAKE_EXE "$(dirs +1)/hdf5-1.8.16" $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path \
	-DBUILD_SHARED_LIBS=off \
	-DBUILD_TESTING=off \
	-DHDF5_BUILD_FORTRAN=off \
	-DHDF5_BUILD_EXAMPLES=off \
	-DHDF5_BUILD_TOOLS=off \
	-DHDF5_DISABLE_COMPILER_WARNINGS=on \
	-DSKIP_HDF5_FORTRAN_SHARED=off

exit_on_error
remove_if_exist $install_path
make -j $MAKE_JOBS install
exit_on_error
popd
rm -fr build.gcc
popd
