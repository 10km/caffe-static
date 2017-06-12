#!/bin/bash
shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars
mkdir_if_not_exist $PACKAGE_ROOT
mkdir_if_not_exist $SOURCE_ROOT
mkdir_if_not_exist $TOOLS_ROOT

pushd $shell_folder
./fetch.sh;exit_on_error
./build_gflags.sh;exit_on_error
./build_glog.sh;exit_on_error
./build_bzip2.sh;exit_on_error
./build_boost.sh;exit_on_error
./build_hdf5.sh;exit_on_error
./build_leveldb.sh;exit_on_error
./build_lmdb.sh;exit_on_error
./build_OpenBLAS.sh;exit_on_error
./build_opencv.sh;exit_on_error
./build_protobuf.sh;exit_on_error
./build_snappy.sh;exit_on_error
./build_ssd.sh;exit_on_error
popd
