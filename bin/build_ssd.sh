#!/bin/bash
# cmake 静态编译 caffe-ssd 代码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars
# 项目安装路径
install_path=$SSD_INSTALL_PATH
echo install_path:$install_path
# gflags 安装路径
gflags_root=$GFLAGS_INSTALL_PATH
exit_if_not_exist "$gflags_root/lib/libgflags.a" "not found $gflags_root/lib/libgflags.a,please build $GFLAGS_PREFIX"
# glog 安装路径
glog_root=$GLOG_INSTALL_PATH
exit_if_not_exist "$glog_root/lib/libglog.a" "not found $glog_root/lib/libglog.a,please build $GLOG_PREFIX"
# hdf5 cmake 位置  
hdf5_cmake_dir=$HDF5_INSTALL_PATH/share/cmake
exit_if_not_exist $hdf5_cmake_dir "not found $hdf5_cmake_dir,please build $HDF5_PREFIX"
exit_if_not_exist $BOOST_INSTALL_PATH "not found $BOOST_INSTALL_PATH,please build $BOOST_PREFIX"
exit_if_not_exist $OPENBLAS_INSTALL_PATH "not found $OPENBLAS_INSTALL_PATH,please build $OPENBLAS_PREFIX"
exit_if_not_exist $PROTOBUF_INSTALL_PATH "not found $PROTOBUF_INSTALL_PATH,please build $PROTOBUF_PREFIX"
# protobuf lib 路径
# centos下安装路径可能是lib64
[ -e "$PROTOBUF_INSTALL_PATH/lib" ] && protobuf_lib=$PROTOBUF_INSTALL_PATH/lib
[ -e "$PROTOBUF_INSTALL_PATH/lib64" ] && protobuf_lib=$PROTOBUF_INSTALL_PATH/lib64
exit_if_not_exist $SNAPPY_INSTALL_PATH "not found $SNAPPY_INSTALL_PATH,please build $SNAPPY_PREFIX"
# lmdb 安装路径根目录
lmdb_install_root=$LMDB_INSTALL_PATH/usr/local
exit_if_not_exist $lmdb_install_root "not found $lmdb_install_root,please build lmdb"
exit_if_not_exist $LEVELDB_INSTALL_PATH "not found $LEVELDB_INSTALL_PATH,please build $LEVELDB_PREFIX"
# opencv 配置文件(OpenCVConfig.cmake)所在路径
opencv_cmake_dir=$OPENCV_INSTALL_PATH/share/OpenCV
exit_if_not_exist $opencv_cmake_dir "not found $opencv_cmake_dir,please build $OPENCV_PREFIX"

pushd $SOURCE_ROOT/$SSD_FOLDER
clean_folder build.gcc
#mkdir_if_not_exist build.gcc
pushd build.gcc
# 指定 OpenBLAS 安装路径 参见 $caffe_source/cmake/Modules/FindOpenBLAS.cmake
export OpenBLAS_HOME=$OPENBLAS_INSTALL_PATH
# 指定 lmdb 安装路径 参见 $caffe_source/cmake/Modules/FindLMDB.cmake.cmake
export LMDB_DIR=$lmdb_install_root
# 指定 leveldb 安装路径 参见 $caffe_source/cmake/Modules/FindLevelDB.cmake.cmake
export LEVELDB_ROOT=$LEVELDB_INSTALL_PATH
# GLOG_ROOT_DIR 参见 $caffe_source/cmake/Modules/FindGlog.cmake
# GFLAGS_ROOT_DIR 参见 $caffe_source/cmake/Modules/FindGFlags.cmake
# HDF5_ROOT 参见 https://cmake.org/cmake/help/v3.8/module/FindHDF5.html
# BOOST_ROOT,Boost_NO_SYSTEM_PATHS 参见 https://cmake.org/cmake/help/v3.8/module/FindBoost.html
# SNAPPY_ROOT_DIR 参见 $caffe_source/cmake/Modules/FindSnappy.cmake
# PROTOBUF_LIBRARY,PROTOBUF_PROTOC_LIBRARY... 参见 https://cmake.org/cmake/help/v3.8/module/FindProtobuf.html
# OpenCV_DIR 参见https://cmake.org/cmake/help/v3.8/command/find_package.html
$CMAKE_EXE "$(dirs +1)" $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
	-DGLOG_ROOT_DIR=$glog_root \
	-DGFLAGS_ROOT_DIR=$gflags_root \
	-DHDF5_ROOT=$HDF5_INSTALL_PATH \
	-DBOOST_ROOT=$BOOST_INSTALL_PATH \
	-DBoost_NO_SYSTEM_PATHS=on \
	-DSNAPPY_ROOT_DIR=$SNAPPY_INSTALL_PATH \
	-DOpenCV_DIR=$opencv_cmake_dir \
	-DPROTOBUF_LIBRARY=$protobuf_lib/libprotobuf.a \
	-DPROTOBUF_PROTOC_LIBRARY=$protobuf_lib/libprotoc.a \
	-DPROTOBUF_LITE_LIBRARY=$protobuf_lib/libprotobuf-lite.a \
	-DPROTOBUF_PROTOC_EXECUTABLE=$PROTOBUF_INSTALL_PATH/bin/protoc \
	-DPROTOBUF_INCLUDE_DIR=$PROTOBUF_INSTALL_PATH/include \
	-DCPU_ONLY=ON \
	-DBLAS=Open \
	-DBUILD_SHARED_LIBS=off \
	-DBUILD_docs=off \
	-DBUILD_python=off \
	-DBUILD_python_layer=off \
	-DUSE_LEVELDB=on \
	-DUSE_LMDB=on \
	-DUSE_OPENCV=on 
exit_on_error
# 修改所有 link.txt 删除-lstdc++ 选项，保证静态连接libstdc++库,否则在USE_OPENCV=on的情况下，libstdc++不会静态链接
for file in $(find . -name link.txt)
do 
	echo "modifing file: $file"
	sed -i -r "s/-lstdc\+\+/ /g" $file
done
#read -n 1
remove_if_exist $install_path
make -j $MAKE_JOBS install
exit_on_error
popd
rm -fr build.gcc
popd
