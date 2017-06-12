#!/bin/bash
# 静态编译 opencv 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

install_path=$OPENCV_INSTALL_PATH
echo install_path:$install_path
bzip2_libraries=$BZIP2_INSTALL_PATH/lib/libbz2.a
exit_if_not_exist $bzip2_libraries "not found $bzip2_libraries,please build $BZIP2_PREFIX"

pushd $SOURCE_ROOT/$OPENCV_FOLDER
clean_folder build.gcc
#mkdir_if_not_exist build.gcc
pushd build.gcc

$CMAKE_EXE "`dirs +1`" $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path \
	-DBZIP2_LIBRARIES=$BZIP2_INSTALL_PATH/lib/libbz2.a \
	-DBUILD_DOCS=off \
	-DBUILD_SHARED_LIBS=off \
	-DBUILD_PACKAGE=on \
	-DBUILD_PERF_TESTS=off \
	-DBUILD_FAT_JAVA_LIB=off \
	-DBUILD_TESTS=off \
	-DBUILD_TIFF=on \
	-DBUILD_JASPER=on \
	-DBUILD_JPEG=on \
	-DBUILD_OPENEXR=on \
	-DBUILD_PNG=on \
	-DBUILD_ZLIB=on \
	-DBUILD_opencv_apps=off \
	-DBUILD_opencv_calib3d=off \
	-DBUILD_opencv_contrib=off \
	-DBUILD_opencv_features2d=off \
	-DBUILD_opencv_flann=off \
	-DBUILD_opencv_gpu=off \
	-DBUILD_opencv_java=off \
	-DBUILD_opencv_legacy=off \
	-DBUILD_opencv_ml=off \
	-DBUILD_opencv_nonfree=off \
	-DBUILD_opencv_objdetect=off \
	-DBUILD_opencv_ocl=off \
	-DBUILD_opencv_photo=off \
	-DBUILD_opencv_python=off \
	-DBUILD_opencv_stitching=off \
	-DBUILD_opencv_superres=off \
	-DBUILD_opencv_ts=off \
	-DBUILD_opencv_video=off \
	-DBUILD_opencv_videostab=off \
	-DBUILD_opencv_world=off \
	-DBUILD_opencv_lengcy=off \
	-DWITH_JASPER=on \
	-DWITH_JPEG=on \
	-DWITH_1394=off \
	-DWITH_OPENEXR=on \
	-DWITH_PNG=on \
	-DWITH_TIFF=on \
	-DWITH_1394=off \
	-DWITH_EIGEN=off \
	-DWITH_FFMPEG=off \
	-DWITH_GIGEAPI=off \
	-DWITH_GSTREAMER=off \
	-DWITH_GTK=off \
	-DWITH_PVAPI=off \
	-DWITH_V4L=off \
	-DWITH_LIBV4L=off \
	-DWITH_CUDA=off \
	-DWITH_CUFFT=off \
	-DWITH_OPENCL=off \
	-DWITH_OPENCLAMDBLAS=off \
	-DWITH_OPENCLAMDFFT=off 
#read -n 1
exit_on_error
remove_if_exist $install_path  
make -j $MAKE_JOBS install
exit_on_error
popd
rm -fr build.gcc
popd
