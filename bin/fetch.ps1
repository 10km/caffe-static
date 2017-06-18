param(
[string[]]$names=($all_names -split ' ') ,
[switch]$force,
[switch]$verbose,
[switch]$help
)
. "./build_vars.ps1"
<#
下载caffe-ssd及其所有依赖库的源码以及cmake工具，
下载的源码压缩包存放在 $PACKAGE_ROOT 文件夹下
并解压缩到 $SOURCE_ROOT 文件夹下，
如果压缩已经存在则跳过下载直接解压缩
#>

# $file 待检查的文件路径
# $md5 md5校验码
# 如果$file不存在 返回$true
# 如果$file是文件夹则报错退出
# 如果$file存在且checksum与$2指定的md5相等则返回 $false,否则返回$true
# 如果$file存在且md5为空时，由全局变量$FORCE_DOWNLOAD_IF_EXIST决定是否需要下载
function need_download([string]$file,[string]$md5){
    args_not_null_empty_undefined file 
	if (Test-Path $file -PathType Leaf){
		if($md5){
			echo "File already exists. Checking md5..."
			if($HOST_OS -eq "windows"){
				$checksum=(md5sum $file)
			}else{
				$os=$(uname -s)
				if ( $os -eq "Linux" ){
					$checksum=$(md5sum $file | awk '{ print $1 }')
				}elseif ( $os -eq "Darwin" ){
					$checksum=$(cat $file | md5)
				}
				exit_on_error
			}
			if ( $checksum -eq  $md5){
				echo "Checksum is correct. No need to download $file."
				return $false
			}else{
				echo "Checksum is incorrect. Need to download again $file"
				return $true
			}
		}else{
			return $FORCE_DOWNLOAD_IF_EXIST
		}
	}elseif (Test-Path $file -PathType Container){
		# $file是文件夹则报错退出
		echo "invalid argument: package=$file is a folder!!!"
		call_stack
		exit -1
	}else{
		return $true
	}
}
# 下载并解压指定的项目文件
function download_and_extract([PSObject]$info,[string]$uri,[string]$targetRoot=$SOURCE_ROOT,[string]$sourceRoot=$PACKAGE_ROOT,[string]$md5Name,[string]$versionName){
	args_not_null_empty_undefined info uri
    if($md5Name){
        $md5=$info."$md5Name"
        if(! $md5){
            echo "undefined member property '$md5Name'"
            call_stack
            exit -1
        }        
    }else{
        $md5=$info.md5
    }
    if($versionName){
        $version=$info."$versionName"
        if(! $version){
            echo "undefined member property '$versionName'"
            call_stack
            exit -1
        }        
    }else{
        $version=$info.version
    }
    if($info.package_suffix){
	    $package=$info.folder + $info.package_suffix
    }else{
        $package=$info.folder + ".zip"
    }
	$package_path=Join-Path $sourceRoot $package
	if( (need_download $package_path $md5)[-1] ){	
		remove_if_exist $package_path
		Write-Host "(下载)downloading" $info.prefix $version 
        # 设置为Tls12 解决报错：
        # Invoke-WebRequest : 请求被中止: 未能创建 SSL/TLS 安全通道。
        # 参见 https://stackoverflow.com/questions/41618766/powershell-invoke-webrequest-fails-with-ssl-tls-secure-channel
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Invoke-WebRequest -Uri $uri -OutFile $package_path 
		exit_on_error
	}
	remove_if_exist (Join-Path $targetRoot $info.folder)
	echo "(解压缩)extracting file from $package_path"
	unpack $package_path -targetFolder $targetRoot	
}
# 从github上下载源码
# 如果本地不存在指定的zip包，或$md5为空或$md5校验码不匹配则从github下载
# 如果本地存在指定的zip包，且$md5为空,则根据$FORCE_DOWNLOAD_IF_EXIST决定是否跳过下载直接解压
# $info 项目配置信息 $xxxx_INFO
function fetch_from_github([PSObject]$info){
	args_not_null_empty_undefined info
	$package=$info.folder+".zip"
    $uri="https://github.com/$($info.owner)/$($info.prefix)/archive/$($info.package_prefix)$($info.version).zip"
    download_and_extract $info -uri $uri
	$unpack_folder=$info.prefix+'-'+$info.package_prefix+$info.version
	if( $info.package_prefix -and (Test-Path (Join-Path $SOURCE_ROOT $unpack_folder) -PathType Container)){
		Write-Host rename $unpack_folder to $info.folder
        pushd $SOURCE_ROOT
        Rename-Item -Path $unpack_folder -NewName $info.folder
        exit_on_error
        popd		
	}
}
###################################################
# 从 sourceforge.net 下载 boost 
function fetch_boost(){
	$remote_prefix=$BOOST_INFO.prefix+'_'+$BOOST_INFO.version.Replace('.','_')
    $uri="https://nchc.dl.sourceforge.net/project/boost/boost/$($BOOST_INFO.version)/$remote_prefix$($BOOST_INFO.package_suffix)"
	download_and_extract -info $BOOST_INFO -uri $uri 
	pushd $SOURCE_ROOT
	Rename-Item -Path $remote_prefix -NewName $BOOST_INFO.folder
    exit_on_error
    popd
}
# 下载 hdf5
function fetch_hdf5(){
    $package_prefix="CMake-"+$HDF5_INFO.folder
    $uri='https://support.hdfgroup.org/ftp/HDF5/releases',$HDF5_INFO.folder,'src',($package_prefix+$HDF5_INFO.package_suffix) -join '/'
    download_and_extract -info $HDF5_INFO -uri $uri
	pushd $SOURCE_ROOT
	Rename-Item -Path $package_prefix -NewName $HDF5_INFO.folder
    exit_on_error
    popd
}
# 下载 cmake 压缩包解压到 $TOOLS_ROOT
function fetch_cmake(){
    $uri= "https://cmake.org/files/v3.8/$($CMAKE_INFO.folder)$($CMAKE_INFO.package_suffix)"
    download_and_extract -info $CMAKE_INFO -uri $uri -targetRoot $TOOLS_ROOT	
}
# 下载 bzip2 1.0.6 
function fetch_bzip2_1_0_6(){
    $uri="http://www.bzip.org/$($BZIP2_1_0_6_INFO.version)/$($BZIP2_1_0_6_INFO.folder)$($BZIP2_1_0_6_INFO.package_suffix)"
    download_and_extract -info $BZIP2_1_0_6_INFO -uri $uri 
    modify_bzip2_1_0_6
}
#################################################################
function modify_bzip2_1_0_6(){
	$bzip2_makefile=[io.path]::combine($SOURCE_ROOT,$BZIP2_1_0_6_INFO.folder,"Makefile")
    exit_if_not_exist $bzip2_makefile -type Leaf
    if(! (Get-Content $bzip2_makefile|Select-String  -Pattern '^\s*CFLAGS\s*=\s*' | Select-String -Pattern '-fPIC') ){
        echo "修改 $bzip2_makefile,在编译选项中增加 -fPIC 参数"
        (Get-Content $bzip2_makefile) -replace '(^\s*CFLAGS\s*=)(.*$)','#modified by guyadong,add -fPIC
$1-fPIC $2' | Out-File $bzip2_makefile
        exit_on_error
    }	
}
#################################################################
function modify_snappy(){
	$snappy_cmake=[io.path]::combine($SOURCE_ROOT,$SNAPPY_INFO.folder,"CMakeLists.txt")
	echo "修改 $snappy_cmake ,删除 SHARED 参数"
    (Get-Content $snappy_cmake) -replace '(^\s*ADD_LIBRARY\s*\(\s*snappy\s*)SHARED','#modified by guyadong,remove SHARED
$1'| Out-File $snappy_cmake
	exit_on_error
}
######################################################
function modify_ssd(){
	$ssd_src=Join-Path -Path $SOURCE_ROOT -ChildPath $SSD_INFO.folder
	echo "(复制修改的补丁文件)copy patch file to $ssd_src"	
    cp -Path (Join-Path -Path $PATCH_ROOT -ChildPath $SSD_INFO.folder) -Destination $SOURCE_ROOT -Recurse -Force -Verbose
	exit_on_error 
}

function fetch_bzip2_1_0_5(){ fetch_from_github $BZIP2_INFO; }
function fetch_protobuf(){ fetch_from_github $PROTOBUF_INFO ; }
function fetch_gflags(){ fetch_from_github $GFLAGS_INFO ; }
function fetch_glog(){ fetch_from_github $GLOG_INFO ; }
function fetch_leveldb(){ fetch_from_github $LEVELDB_INFO ; }
function fetch_lmdb(){ fetch_from_github $LMDB_INFO ; }
function fetch_snappy(){ fetch_from_github $SNAPPY_INFO; modify_snappy ; }
function fetch_openblas(){ fetch_from_github $OPENBLAS_INFO ; }
function fetch_ssd(){ fetch_from_github $SSD_INFO ; modify_ssd; }
function fetch_opencv(){ fetch_from_github $OPENCV_INFO; }
function fetch_bzip2(){ fetch_bzip2_1_0_5 ; }

# 输出帮助信息
function print_help(){
    if($(chcp ) -match '\.*936$'){
	    echo "用法: $my_name [-names] [项目名称列表,...] [可选项...] 
下载并解压指定的项目，如果没有指定项目名称，则下载解压所有项目
    -names       项目名称列表(逗号分隔,忽略大小写)
                 可选的项目名称: $all_names 
选项:
	-verbose     显示详细信息
	-force       强制下载没有指定版本号的项目
	-help        显示帮助信息
作者: guyadong@gdface.net
"
    }else{
        echo "usage: $my_name [-names] [PROJECT_NAME,...] [options...] 
download and extract projects specified by project name,
all projects fetched without argument
    -names       prject names(split by comma,ignore case)
                 optional project names: $all_names 

options:
	-verbose     list verbosely
	-force       force download if package without version is exist  
	-help        print the message
author: guyadong@gdface.net
"
    }
}
if($help){
    print_help  
    exit 0
}
$all_names="cmake protobuf gflags glog leveldb lmdb snappy openblas boost hdf5 opencv bzip2 ssd"
$my_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
# 对于md5为空的项目，当本地存在压缩包时是否强制从网络下载
$FORCE_DOWNLOAD_IF_EXIST=$force
# 运行过程中是否显示显示详细的进行步骤
$VERBOSE_EXTRACT=$verbose
# 检查所有项目名称参数，如果是无效值则报错退出
echo $names| foreach {    
    if( $_ -and ! (Test-Path function:"fetch_$($_.ToUpper())") ){
        echo "(不识别的项目名称)unknow project name:$_"
        print_help
        exit -1
    }
}
# 创建 package,source,tools 根目录
mkdir_if_not_exist $PACKAGE_ROOT
mkdir_if_not_exist $SOURCE_ROOT
mkdir_if_not_exist $TOOLS_ROOT
# 顺序下载解压 $names 中指定的项目
echo $names| foreach {  
    if( $_){
        &"fetch_$($_.ToUpper())"  
    }    
}
