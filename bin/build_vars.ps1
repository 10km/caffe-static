#!/bin/bash
. "./build_funs.ps1"
# 获取CPU逻辑核心总数
function get_logic_core_count(){
    $cpu=get-wmiobject win32_processor
    return @($cpu).count*$cpu.NumberOfLogicalProcessors
}
function get_os_processor(){
    try { 
        # 先尝试执行linux命令判断操作系统,产生异常时执行windows下指令
		$os=$(uname -s)
		$processor=$(uname -p)
    } catch { 
        $os="windows"
	    $arch=$env:PROCESSOR_ARCHITECTURE
        $processor="x86"
        if($arch -eq "AMD64"){
             $processor += "_64"
        }	    
    } 
    $os
    $processor
}
# 定义 xxx_FOLDER 变量
function define_project_folder([string]$prefix){
    args_not_null_empty_undefined prefix    
	$prefix=$prefix.ToUpper()
    $v1=$(gv -Name "${prefix}_PREFIX" -Scope "script").Value
    $v2=$(gv -Name "${prefix}_VERSION" -Scope "script").Value
    New-Variable -Name "${prefix}_FOLDER" -Value "${v1}_${v2}" -Scope "script" -Force 
}
# 生成安装路径名后缀
function install_suffix([string]$prefix){
   args_not_null_empty_undefined prefix
   return "${prefix}_${global:HOST_OS}_${global:HOST_PROCESSOR}"
}
# 指定编译器
echo 编译器位置：
echo MAKE_CXX_COMPILER:$MAKE_CXX_COMPILER
echo MAKE_C_COMPILER:$MAKE_C_COMPILER
# 操作系统,CPU类型
$HOST_OS,$HOST_PROCESSOR=get_os_processor
echo HOST_OS=$HOST_OS,HOST_OS=$HOST_PROCESSOR

# cmake 参数定义
$CMAKE_VARS_DEFINE="-DCMAKE_CXX_COMPILER:FILEPATH=$MAKE_CXX_COMPILER -DCMAKE_C_COMPILER:FILEPATH=$MAKE_C_COMPILER -DCMAKE_BUILD_TYPE:STRING=RELEASE"
# 脚本所在路径
$BIN_ROOT=$(Get-Item $MyInvocation.MyCommand.Definition).Directory
# 项目根目录
$DEPENDS_ROOT=$BIN_ROOT.Parent.FullName
# 安装根目录
$INSTALL_PREFIX_ROOT="$DEPENDS_ROOT/release"
# 源码根目录
$SOURCE_ROOT="$DEPENDS_ROOT/source"
# 压缩包根目录
$PACKAGE_ROOT="$DEPENDS_ROOT/package"
# 补丁文件根目录
$PATCH_ROOT="$DEPENDS_ROOT/patch"
# 工具软件根据目录
$TOOLS_ROOT="$DEPENDS_ROOT/tools"

# 多线程编译参数 make -j 
$MAKE_JOBS=get_logic_core_count
# cmake 位置定义
$CMAKE_FOLDER="cmake-3.8.2-Linux-x86_64"
$CMAKE_MD5="ab02cf61915e1ad15b8523347ad37c46"
$CMAKE_ROOT="$DEPENDS_ROOT/tools/$CMAKE_FOLDER"
$CMAKE_EXE="$CMAKE_ROOT/bin/cmake"

##################################项目配置信息
$PROTOBUF_PREFIX="protobuf"
$PROTOBUF_VERSION="3.3.1"
$PROTOBUF_MD5="9377e414994fa6165ecb58a41cca3b40"
$PROTOBUF_OWNER="google"
$PROTOBUF_PACKAGE_PREFIX="v"
$PROTOBUF_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $PROTOBUF_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $PROTOBUF_PREFIX

$GLOG_PREFIX="glog"
$GLOG_VERSION="0.3.5"
$GLOG_MD5="454766d0124951091c95bad33dafeacd"
$GLOG_OWNER="google"
$GLOG_PACKAGE_PREFIX="v"
$GLOG_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $GLOG_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $GLOG_PREFIX

$GFLAGS_PREFIX="gflags"
$GFLAGS_VERSION="2.2.0"
$GFLAGS_MD5="f3d31a4225a7e0e6cac50b2b65525317"
#GFLAGS_VERSION="2.1.2"
#GFLAGS_MD5_2_1_2="5cb0a1b38740ed596edb7f86cd5b3bd8"
$GFLAGS_OWNER="gflags"
$GFLAGS_PACKAGE_PREFIX="v"
$GFLAGS_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $GFLAGS_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $GFLAGS_PREFIX

$LEVELDB_PREFIX="leveldb"
$LEVELDB_VERSION="1.18"
$LEVELDB_MD5="06e9f4984e40ccf27af366d5bec0580a"
$LEVELDB_OWNER="google"
$LEVELDB_PACKAGE_PREFIX="v"
$LEVELDB_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $LEVELDB_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $LEVELDB_PREFIX

$SNAPPY_PREFIX="snappy"
#SNAPPY_VERSION="1.1.4"
#SNAPPY_MD5="b9bdbb6818d9c66b31edb6c037fef3d0"
$SNAPPY_VERSION="master"
$SNAPPY_MD5=""
$SNAPPY_OWNER="google"
$SNAPPY_PACKAGE_PREFIX=""
$SNAPPY_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $SNAPPY_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $SNAPPY_PREFIX

$OPENBLAS_PREFIX="OpenBLAS"
$OPENBLAS_VERSION="0.2.18"
$OPENBLAS_MD5="4ca49eb1c45b3ca82a0034ed3cc2cef1"
$OPENBLAS_OWNER="xianyi"
$OPENBLAS_PACKAGE_PREFIX="v"
$OPENBLAS_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $OPENBLAS_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $OPENBLAS_PREFIX

$LMDB_PREFIX="lmdb"
$LMDB_VERSION="0.9.21"
$LMDB_MD5="a47ddf0fade922e8335226726be5e6c4"
$LMDB_OWNER="LMDB"
$LMDB_PACKAGE_PREFIX="LMDB_"
$LMDB_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $LMDB_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $LMDB_PREFIX

$BZIP2_PREFIX="bzip2"
$BZIP2_VERSION="1.0.5"
# 1.0.5 zip 包md5校验码(github下载)
$BZIP2_MD5="052fec5cdcf9ae26026c3e85cea5f573"
# 1.0.6 tar.gz包md5校验码(官网 bzip2.org 下载)
$BZIP2_TAR_GZ_MD5_1_0_6="00b516f4704d4a7cb50a1d97e6e8e15b"
$BZIP2_OWNER="LuaDist"
$BZIP2_PACKAGE_PREFIX=""
$BZIP2_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $BZIP2_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $BZIP2_PREFIX

$BOOST_PREFIX="boost"
$BOOST_VERSION="1.58.0"
$BOOST_MD5="5a5d5614d9a07672e1ab2a250b5defc5"
$BOOST_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $BOOST_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $BOOST_PREFIX

$HDF5_PREFIX="hdf5"
$HDF5_VERSION="1.8.16"
$HDF5_MD5="a7559a329dfe74e2dac7d5e2d224b1c2"
$HDF5_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $HDF5_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $HDF5_PREFIX

$OPENCV_PREFIX="opencv"
#OPENCV_VERSION="2.4.9"
#OPENCV_MD5="7f958389e71c77abdf5efe1da988b80c"
$OPENCV_VERSION="2.4.13.2"
$OPENCV_MD5="e48803864e77fc8ae7114be4de732d80"
$OPENCV_OWNER="opencv"
$OPENCV_PACKAGE_PREFIX=""
$OPENCV_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $OPENCV_PREFIX) -Path $INSTALL_PREFIX_ROOT)
define_project_folder $OPENCV_PREFIX

$SSD_PREFIX="caffe-ssd"
$SSD_FOLDER="caffe-ssd"
$SSD_INSTALL_PATH=$(Join-Path -ChildPath $(install_suffix $OPENCV_PREFIX) -Path $SSD_PREFIX)

