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
# 生成安装路径名后缀
function install_suffix([string]$prefix){
	args_not_null_empty_undefined prefix HOST_OS HOST_PROCESSOR
	return "${prefix}_${HOST_OS}_${HOST_PROCESSOR}"
}
# 根据哈希表提供的信息创建project info对象
function create_project_info([hashtable]$hash){
	args_not_null_empty_undefined hash INSTALL_PREFIX_ROOT
    $info= New-Object PSObject  -Property $hash
    # 没有定义 prefix 的不定义install_path
    if($info.prefix){
	    Add-Member -InputObject $info -NotePropertyName install_path -NotePropertyValue $(Join-Path -ChildPath $(install_suffix $info.prefix) -Path $INSTALL_PREFIX_ROOT) 
    }
    $f=$info.prefix
    # 如果没有定义版本号，则folder与prefix相同
    if($info.version){
       $f+="-"+$info.version
    }
	if(! $info.folder){
		Add-Member -InputObject $info -NotePropertyName folder -NotePropertyValue $f
	}
    return $info
}

# 指定编译器
echo 编译器位置：
echo MAKE_CXX_COMPILER:$MAKE_CXX_COMPILER
echo MAKE_C_COMPILER:$MAKE_C_COMPILER
# 操作系统,CPU类型
$HOST_OS,$HOST_PROCESSOR=get_os_processor
echo HOST_OS=$HOST_OS
echo HOST_OS=$HOST_PROCESSOR

# cmake 参数定义
$CMAKE_VARS_DEFINE="-DCMAKE_CXX_COMPILER:FILEPATH=$MAKE_CXX_COMPILER -DCMAKE_C_COMPILER:FILEPATH=$MAKE_C_COMPILER -DCMAKE_BUILD_TYPE:STRING=RELEASE"
# 脚本所在路径
$BIN_ROOT=$(Get-Item $MyInvocation.MyCommand.Definition).Directory
# 项目根目录
$DEPENDS_ROOT=$BIN_ROOT.Parent.FullName
# 安装根目录
$INSTALL_PREFIX_ROOT=Join-Path -ChildPath release -Path $DEPENDS_ROOT
# 源码根目录
$SOURCE_ROOT=Join-Path -ChildPath source -Path $DEPENDS_ROOT
# 压缩包根目录
$PACKAGE_ROOT=Join-Path -ChildPath package -Path $DEPENDS_ROOT 
# 补丁文件根目录
$PATCH_ROOT=Join-Path -ChildPath patch -Path $DEPENDS_ROOT 
# 工具软件根据目录
$TOOLS_ROOT=Join-Path -ChildPath tools -Path $DEPENDS_ROOT 

# 多线程编译参数 make -j 
$MAKE_JOBS=get_logic_core_count
##################################项目配置信息
$protobuf_hash=@{
	prefix="protobuf"
	version="3.3.1"
	md5="9377e414994fa6165ecb58a41cca3b40"
	owner="google"
	package_prefix="v"
}
$PROTOBUF_INFO= create_project_info $protobuf_hash
#$PROTOBUF_INFO

$glog_hash=@{
	prefix="glog"
	version="0.3.5"
	md5="454766d0124951091c95bad33dafeacd"
	owner="google"
	package_prefix="v"
}
$GLOG_INFO= create_project_info $glog_hash
#$GLOG_INFO

$gflags_hash=@{
	prefix="gflags"
	version="2.2.0"
	md5="f3d31a4225a7e0e6cac50b2b65525317"
	version_2_1_2="2.1.2"
	md5_2_1_2="5cb0a1b38740ed596edb7f86cd5b3bd8"
	owner="gflags"
	package_prefix="v"
}
$GFLAGS_INFO= create_project_info $gflags_hash
#$GFLAGS_INFO

$leveldb_hash=@{
	prefix="leveldb"
	version="1.18"
	md5="06e9f4984e40ccf27af366d5bec0580a"
	owner="google"
	package_prefix="v"
}
$LEVELDB_INFO= create_project_info $leveldb_hash
#$LEVELDB_INFO

$snappy_hash=@{
	prefix="snappy"
	version_1_1_4="1.1.4"
	md5_1_1_4="b9bdbb6818d9c66b31edb6c037fef3d0"
	version="master"
	owner="google"
	package_prefix=""
}
$SNAPPY_INFO= create_project_info $snappy_hash
#$SNAPPY_INFO

$openblas_hash=@{
	prefix="OpenBLAS"
	version="0.2.18"
	md5="4ca49eb1c45b3ca82a0034ed3cc2cef1"
	owner="xianyi"
	package_prefix="v"
}
$OPENBLAS_INFO= create_project_info $openblas_hash
#$OPENBLAS_INFO

$lmdb_hash=@{
	prefix="lmdb"
	version="0.9.21"
	md5="a47ddf0fade922e8335226726be5e6c4"
	owner="LMDB"
	package_prefix="LMDB_"
}
$LMDB_INFO= create_project_info $lmdb_hash
#$LMDB_INFO


$bzip2_hash=@{
	prefix="bzip2"
	version="1.0.5"
	# 1.0.5 zip 包md5校验码(github下载)
	MD5="052fec5cdcf9ae26026c3e85cea5f573"
	# 1.0.6 tar.gz包md5校验码(官网 bzip2.org 下载)
	tar_gz_md5_1_0_6="00b516f4704d4a7cb50a1d97e6e8e15b"
	owner="LuaDist"
	package_prefix=""
}
$BZIP2_INFO= create_project_info $bzip2_hash
#$BZIP2_INFO

$boost_hash=@{
	prefix="boost"
	version="1.58.0"
	md5="5a5d5614d9a07672e1ab2a250b5defc5"
}
$BOOST_INFO= create_project_info $boost_hash
#$BOOST_INFO

$hdf5_hash=@{
	prefix="hdf5"
	version="1.8.16"
	md5="a7559a329dfe74e2dac7d5e2d224b1c2"
}
$HDF5_INFO= create_project_info $hdf5_hash
#$HDF5_INFO

$opencv_hash=@{
	prefix="opencv"
	version_2_4_9="2.4.9"
	md5_2_4_9="7f958389e71c77abdf5efe1da988b80c"
	version="2.4.13.2"
	md5="e48803864e77fc8ae7114be4de732d80"
	owner="opencv"
	package_prefix=""
}
$OPENCV_INFO= create_project_info $opencv_hash
#$OPENCV_INFO

$ssd_hash=@{
	prefix="caffe-ssd"	
}
$SSD_INFO= create_project_info $ssd_hash
#$SSD_INFO

$cmake_hash=@{
	md5="ab02cf61915e1ad15b8523347ad37c46"
	folder="cmake-3.8.2-Linux-x86_64"
}
$CMAKE_INFO= create_project_info $cmake_hash
# 添加root属性
Add-Member -InputObject $CMAKE_INFO -NotePropertyName root -NotePropertyValue (Join-Path -ChildPath $CMAKE_INFO.folder -Path $TOOLS_ROOT )
# 添加exe属性
Add-Member -InputObject $CMAKE_INFO -NotePropertyName exe -NotePropertyValue ([io.path]::combine($CMAKE_INFO.root,"bin","cmake"))
#$CMAKE_INFO
# wget.exe位置
$WGET=[io.path]::combine($TOOLS_ROOT,"wget","wget")

