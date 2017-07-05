<#
下载caffe-ssd及其所有依赖库的源码以及cmake,msys2等工具，
下载的源码压缩包存放在 $PACKAGE_ROOT 文件夹下
并解压缩到 $SOURCE_ROOT 文件夹下，
如果压缩包已经存在则跳过下载直接解压缩
如果源码需要修改，则自动完成文件修改( modify_xxx 系列函数)
author: guyadong@gdface.net
#>
param(
[string[]]$names ,
[string]$modify_caffe,
[switch]$force,
[switch]$verbose,
[alias('list')]
[switch]$list_only,
[switch]$help
)

if(!$BUILD_VARS_INCLUDED){
. "$PSScriptRoot/build_vars.ps1"
}
. "$PSScriptRoot/modwin.ps1"

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
# $noUnpack 下载但不执行解压
# $noFolder 压缩包不是独立子文件夹结构
function download_and_extract([PSObject]$info,[string]$uri,[string]$targetRoot=$SOURCE_ROOT,[string]$sourceRoot=$PACKAGE_ROOT,[string]$md5Name,[string]$versionName,[switch]$noUnpack,[switch]$noFolder){
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
        if($list_only){
            throw "${NEED_DOWNLOAD_PREFIX}: download $uri and SAVE AS $package_path"
        }	
		remove_if_exist $package_path
		Write-Host "(下载)downloading" $info.prefix $version -ForegroundColor Yellow
        # 设置为Tls12 解决报错：
        # Invoke-WebRequest : 请求被中止: 未能创建 SSL/TLS 安全通道。
        # 参见 https://stackoverflow.com/questions/41618766/powershell-invoke-webrequest-fails-with-ssl-tls-secure-channel
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # 对 .exe 文件下载时改后缀为zip,以避免杀毒软件干扰
        $p=$(if($info.package_suffix -eq '.exe'){$package_path+'.zip'}else{$package_path}) 
        remove_if_exist $p
		Invoke-WebRequest -Uri $uri -OutFile $p -TimeoutSec 10
		exit_on_error
        if($info.package_suffix -eq '.exe'){
            Rename-Item $p -NewName $package_path
            Start-Sleep -Seconds 2
        }
        if( $md5 -and (md5sum $package_path) -ne $md5){
            Write-Host "$uri `nfail to download,try to manually download the url and SAVE AS $package_path" -ForegroundColor Yellow
            Write-Host "下载失败,请尝试手工下载" -ForegroundColor Yellow
            exit -1
        }
	}elseif($list_only){
        throw "${SKIP_DOWNLOAD_PREFIX}: $package_path"
    }	
    if(!$noUnpack){
	    remove_if_exist (Join-Path $targetRoot $info.folder)
	    Write-Host "(解压缩)extracting file from $package_path" -ForegroundColor Yellow
	    unpack $package_path -targetFolder $(if($noFolder){$(Join-Path $targetRoot -ChildPath $info.folder )}else{$targetRoot})	
    }
}
# 从github上下载源码
# 如果本地不存在指定的zip包，或$md5为空或$md5校验码不匹配则从github下载
# 如果本地存在指定的zip包，且 $md5 为空,则根据 $FORCE_DOWNLOAD_IF_EXIST 决定是否跳过下载直接解压
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
# 下载 jom 压缩包解压到 $TOOLS_ROOT
function fetch_jom(){
    $uri="http://download.qt.io/official_releases/$($JOM_INFO.prefix)/$($JOM_INFO.prefix)_$($JOM_INFO.version.Replace('.','_'))$($JOM_INFO.package_suffix)"
    download_and_extract -info $JOM_INFO -uri $uri -targetRoot $TOOLS_ROOT -noFolder
}
# 下载 mingw32 (MinGW 32位编译器) 压缩包解压到 $TOOLS_ROOT
function fetch_mingw32(){
    $poject=$MINGW32_INFO
    $uri= "https://nchc.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/$($poject.version)/threads-win32/dwarf/i686-$($poject.version)-release-win32-dwarf-rt_v5-rev0.7z"
    download_and_extract -info $poject -uri $uri -targetRoot $TOOLS_ROOT	
}
# 下载 mingw64 (MinGW 64位编译器) 压缩包解压到 $TOOLS_ROOT
function fetch_mingw64(){
    $poject=$MINGW64_INFO
    $uri= "https://nchc.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/$($poject.version)/threads-win32/sjlj/x86_64-$($poject.version)-release-win32-sjlj-rt_v5-rev0.7z"
    download_and_extract -info $poject -uri $uri -targetRoot $TOOLS_ROOT	
}
# 下载 msys2 压缩包并安装
# 安装 msys2 后,在 msys2 中安装 perl
function fetch_msys2(){
    # 检查是否安装了 msys2，如果没安装就下载安装
    if( ! $MSYS2_INSTALL_LOCATION ){
        $package="$($MSYS2_INFO.prefix)-$($MSYS2_INFO.version)$($MSYS2_INFO.package_suffix)"
        $arch=$MSYS2_INFO.version.Split('-')[0]
        $uri="http://repo.msys2.org/distrib/$arch/$package"
        download_and_extract -info $MSYS2_INFO -uri $uri -targetRoot $TOOLS_ROOT
        $MSYS2_INSTALL_LOCATION=$MSYS2_INFO.root
    }
    if($list_only){ return }
    # 如果没有安装 perl,在 MSYS2 中安装 perl
    Write-Host "(安装perl) install perl if not present"
    $bash=[io.path]::Combine($($MSYS2_INSTALL_LOCATION),'usr','bin','bash')
    cmd /c "$bash -l -c `"if [ ! `$(which perl) ] ;then pacman -S --noconfirm perl ;fi; perl --version`" 2>&1"
    exit_on_error "(perl安装失败，请重试)fail to install perl,please try again"
}
# 如果系统中没有安装解压缩工具(haozip,7z)就下载 7z 压缩包并解压到 $TOOLS_ROOT
function fetch_7z(){
    # 检查是否安装了 解压缩软件，如果没安装就下载安装
    if( ! $UNPACK_TOOL ){
        $package="$($7Z_INFO.folder)$($7Z_INFO.package_suffix)"
        $uri="http://7-zip.org/a/$package"
        download_and_extract -info $7Z_INFO -uri $uri -noUnpack
        # 将 .msi 解压到指定路径
        $target_folder=Join-Path $TOOLS_ROOT -ChildPath $7Z_INFO.folder
        remove_if_exist $target_folder
        cmd /c "msiexec /a `"$(Join-Path $PACKAGE_ROOT -ChildPath $package)`" /qn TARGETDIR=`"$target_folder`" 2>&1 "
        exit_on_error "(7-zip安装失败，请重试)fail to install 7-zip,please try again"
        # 将解开的 .msi 包中 Files/7-Zip 文件夹移到根目录，然后删除所有无用的文件
        $delitem=Get-ChildItem $target_folder
        Get-ChildItem ([io.path]::Combine($target_folder,'Files','7-Zip')) | Move-Item -Destination $target_folder
        $delitem |Remove-Item -Recurse 
        $UNPACK_TOOL = get_unpack_cmdexe
    }
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
        echo "function:$($MyInvocation.MyCommand) -> 修改 $bzip2_makefile,在编译选项中增加 -fPIC 参数"
        (Get-Content $bzip2_makefile) -replace '(^\s*CFLAGS\s*=)(.*$)','#modified by guyadong,add -fPIC
$1-fPIC $2' | Out-File $bzip2_makefile -Encoding ascii -Force
        exit_on_error
    }	
}
#################################################################
function modify_bzip2_1_0_5(){
	$bzip2_cmake=[io.path]::combine($SOURCE_ROOT,$BZIP2_INFO.folder,"CMakeLists.txt")
	echo "function:$($MyInvocation.MyCommand) -> 修改 $bzip2_cmake ,删除 SHARED 参数" 
    (Get-Content $bzip2_cmake) -replace '(^\s*ADD_LIBRARY\s*\(\s*bz2\s*)SHARED','#modified by guyadong,remove SHARED
$1'| Out-File $bzip2_cmake -Encoding ascii -Force
    (Get-Content $bzip2_cmake) -replace '^\s*GET_TARGET_PROPERTY\s*\(\s*BZIP2_LOCATION\s+bzip2\s+LOCATION\)\s*$','$0
# added by guyadong 
string(REGEX MATCH "Visual +Studio" vs_gen ${CMAKE_GENERATOR})
if( MSVC AND WIN32 AND vs_gen )
	string(REPLACE "$(Configuration)" "\${CMAKE_INSTALL_CONFIG_NAME}" BZIP2_LOCATION "${BZIP2_LOCATION}")
endif()
unset(vs_gen)
'| Out-File $bzip2_cmake -Encoding ascii -Force    
    (Get-Content $bzip2_cmake) -replace '(RENAME\s+bunzip2)(\s*\))','$1${CMAKE_EXECUTABLE_SUFFIX}$2 #modified by guyadong,add exe suffix'| Out-File $bzip2_cmake -Encoding ascii -Force
    (Get-Content $bzip2_cmake) -replace   '(RENAME\s+bzcat)(\s*\))','$1${CMAKE_EXECUTABLE_SUFFIX}$2 #modified by guyadong,add exe suffix'| Out-File $bzip2_cmake -Encoding ascii -Force
    exit_on_error
}
#################################################################
function modify_snappy(){
	$snappy_cmake=[io.path]::combine($SOURCE_ROOT,$SNAPPY_INFO.folder,"CMakeLists.txt")
	echo "function:$($MyInvocation.MyCommand) -> 修改 $snappy_cmake ,删除 SHARED 参数"
    (Get-Content $snappy_cmake) -replace '(^\s*ADD_LIBRARY\s*\(\s*snappy\s*)SHARED','#modified by guyadong,remove SHARED
$1'| Out-File $snappy_cmake -Encoding ascii -Force    
    $snappy_test_cc=[io.path]::combine($SOURCE_ROOT,$SNAPPY_INFO.folder,"snappy-test.cc")
    echo "function:$($MyInvocation.MyCommand) -> 修改 $snappy_test_cc ,解决msvc下编译错误"
    (Get-Content $snappy_test_cc -Raw ) -replace '(.*)(?!\()\s*(std::max)\s*(?!\))(.*)','// modified by guyadong
$1($2)$3' | Out-File $snappy_test_cc -Encoding ascii -Force
	exit_on_error
}
######################################################
function modify_ssd(){
	$ssd_src=Join-Path -Path $SOURCE_ROOT -ChildPath $SSD_INFO.folder
	echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $ssd_src"	
    cp -Path (Join-Path -Path $PATCH_ROOT -ChildPath $SSD_INFO.folder) -Destination $SOURCE_ROOT -Recurse -Force -Verbose
	exit_on_error 
}
# 基于 caffe 项目代码通用补丁函数, 
# 所有 caffe 系列项目fetch后 应先调用此函数做修补
# $caffe_root caffe 源码根目录
function modify_caffe_folder([string]$caffe_root){
    args_not_null_empty_undefined caffe_root
    exit_if_not_exist $caffe_root -type Container
    # 通过是不是有src/caffe 文件夹判断是不是 caffe 项目
    exit_if_not_exist ([io.path]::Combine($caffe_root,'src','caffe')) -type Container -msg "$caffe_root 好像不是个 caffe 源码文件夹"
    $cmakelists_root=Join-Path $caffe_root -ChildPath CMakeLists.txt
    exit_if_not_exist $cmakelists_root -type Leaf
    Write-Host "function:$($MyInvocation.MyCommand) ->  caffe 项目代码通用修复"
    $content=Get-Content $cmakelists_root
    $regex_disable_download='(^\s*include\s*\(\s*cmake/WindowsDownloadPrebuiltDependencies\.cmake\s*\))'
    if( $content -match $regex_disable_download){
        Write-Host "(禁止 Windows 预编译库下载) disable download prebuilt dependencies ($cmakelists_root)" 
        $content -replace $regex_disable_download,'#deleted by guyadong,disable download prebuilt dependencies
#$1'| Out-File $cmakelists_root -Encoding ascii -Force
        exit_on_error
    }
    $content=Get-Content $cmakelists_root
    $regex_protobuf='(^\s*caffe_option\s*\(\s*protobuf_MODULE_COMPATIBLE\s+.*\s+)(?:ON|OFF)\s+IF\s+MSVC\s*\)'
    if( $content -match $regex_protobuf){
        Write-Host "set protobuf_MODULE_COMPATIBLE always ON"
        $content -replace $regex_protobuf,'$1ON)#modify by guyadong,always set ON'| Out-File $cmakelists_root -Encoding ascii -Force
        exit_on_error
    }
    $dependencies_cmake= [io.path]::combine( $caffe_root,'cmake','Dependencies.cmake')
    $content=(Get-Content $dependencies_cmake) -join "`n"
    $regex_hdf5_block="(\n#\s*---\s*\[\s*HDF5.*\n)[\s\S]+(\nlist\s*\(\s*APPEND\s+Caffe_INCLUDE_DIRS\s+PUBLIC\s+\$\{HDF5_INCLUDE_DIRS\}\s*\))"
    $regex_hdf5_start="(\n#\s*---\s*\[\s*HDF5.*\n)"
    $regex_hdf5_body="([\s\S]+)"
    $regex_hdf5_end_1="\n\s*list\s*\(\s*APPEND\s+Caffe_INCLUDE_DIRS\s+PUBLIC\s+\$\{HDF5_INCLUDE_DIRS\}\s*\)"
    $regex_hdf5_end_2="\n\s*include_directories\s*\(.+\)"
    if($content -match $regex_hdf5_block){
        Write-Host "(修正 hdf5 依赖库) use hdf5 static library ($dependencies_cmake)"
        $content -replace $regex_hdf5_block,'$1#modified by guyadong 
# Find HDF5 always using static libraries
find_package(HDF5 COMPONENTS C HL REQUIRED)
set(HDF5_LIBRARIES hdf5-static)
set(HDF5_HL_LIBRARIES hdf5_hl-static)$2'| Out-File $dependencies_cmake -Encoding ascii -Force
        exit_on_error 
    }else{
        Write-Host "(没有找到 HDF5 相关代码)，found hdf5 flags in $dependencies_cmake" -ForegroundColor Yellow
        call_stack
        exit -1
    }
	echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $caffe_root"	
    cp -Path ([io.path]::Combine($PATCH_ROOT,'caffe_base','*')) -Destination $caffe_root -Recurse -Force -Verbose    
	exit_on_error 
}

# 基于 BVLC/caffe windows brance 项目(https://github.com/BVLC/caffe/tree/windows)代码补丁函数,主要为了mingw编译
# $caffe_root caffe 源码根目录
function modify_bvlc_caffe_windows([string]$caffe_root){
    args_not_null_empty_undefined caffe_root
	echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $caffe_root"	
    cp -Path ([io.path]::Combine($PATCH_ROOT,'blvc_caffe_windows','*')) -Destination $caffe_root -Recurse -Force -Verbose    
	exit_on_error 
}
# 基于 caffe 项目代码通用补丁函数,用于修复与源码的cmake脚本
# 所有 caffe 系列项目fetch后 应先调用此函数做修补
function modify_caffe_base([PSObject]$caffe_base_project){
    args_not_null_empty_undefined caffe_base_project
    modify_caffe_folder (Join-Path -Path $SOURCE_ROOT -ChildPath $caffe_base_project.folder)
}
######################################################
function modify_leveldb(){
    $leveldb_src=Join-Path -Path $SOURCE_ROOT -ChildPath $LEVELDB_INFO.folder
    $patch_folder=Join-Path -Path $PATCH_ROOT -ChildPath $LEVELDB_INFO.folder
    $cmake_file='CMakeLists.txt'
	$leveldb_cmake=Join-Path -Path $leveldb_src -ChildPath $cmake_file
    if((Test-Path $patch_folder -PathType Container) -and (Test-Path (Join-Path -Path $leveldb_src -ChildPath $cmake_file) -PathType Leaf)){
	    echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $leveldb_src"	
        cp -Path $patch_folder -Destination $SOURCE_ROOT -Force -Verbose -Recurse
	    exit_on_error
    }
}
. "$PSScriptRoot/modwin.ps1"
function modify_lmdb(){
    $lmdb_src=[io.path]::Combine($SOURCE_ROOT,$LMDB_INFO.folder,'libraries','liblmdb')
    echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $lmdb_src"	
    cp -Path ([io.path]::combine($PATCH_ROOT,$LMDB_INFO.folder,"*")) -Destination $lmdb_src -Force -Verbose
    exit_on_error
}
function modify_openblas(){
    $openblas_src=Join-Path -Path $SOURCE_ROOT -ChildPath $OPENBLAS_INFO.folder
    $patch_folder=Join-Path -Path $PATCH_ROOT -ChildPath $OPENBLAS_INFO.folder
    echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $openblas_src"   
    cp -Path $patch_folder -Destination $SOURCE_ROOT -Force -Verbose -Recurse
    exit_on_error
}

function fetch_bzip2_1_0_5(){ fetch_from_github $BZIP2_INFO; }
function fetch_protobuf(){ fetch_from_github $PROTOBUF_INFO ; }
function fetch_gflags(){ fetch_from_github $GFLAGS_INFO ; }
function fetch_glog(){ fetch_from_github $GLOG_INFO ; }
function fetch_leveldb(){ fetch_from_github $LEVELDB_INFO ; modify_leveldb }
function fetch_lmdb(){ fetch_from_github $LMDB_INFO ; modify_lmdb }
function fetch_snappy(){ fetch_from_github $SNAPPY_INFO; modify_snappy ; }
function fetch_openblas(){ fetch_from_github $OPENBLAS_INFO ; modify_openblas}
function fetch_ssd(){ fetch_from_github $SSD_INFO ; modify_ssd; }
function fetch_caffe_windows(){ 
    fetch_from_github $CAFFE_WINDOWS_INFO ; 
    modify_caffe_base $CAFFE_WINDOWS_INFO;
    modify_bvlc_caffe_windows (Join-Path -Path $SOURCE_ROOT -ChildPath $CAFFE_WINDOWS_INFO.folder) }
function fetch_opencv(){ fetch_from_github $OPENCV_INFO; }
function fetch_bzip2(){ fetch_bzip2_1_0_5 ; modify_bzip2_1_0_5 }

# 输出帮助信息
function print_help(){
    if($(chcp ) -match '\.*936$'){
	    echo "用法: $my_name [-names] [项目名称列表,...] [可选项...] 
下载并解压指定的项目，如果没有指定项目名称，则下载解压所有项目
    -n,-names       项目名称列表(逗号分隔,忽略大小写,无空格)
                    可选的项目名称: $($all_names -join ',')
选项:
    -modify_caffe   为指定的 caffe 源码更新补丁文件,参见本脚本源码中 modify_caffe_folder 函数
    -v,-verbose     显示详细信息
    -f,-force       强制下载没有指定版本号的项目
    -list,-list_only 不执行下载解压缩,只列出需要下载的依赖包,当网络条件不好的时候,
                    可以根据表中列出的地址手工下载依赖包
    -h,-help        显示帮助信息
作者: guyadong@gdface.net
"
    }else{
        echo "usage: $my_name [-names] [PROJECT_NAME,...] [options...] 
download and extract projects specified by project name,
all projects fetched without argument
    -n,-names       prject names(split by comma,ignore case,without blank)
                    optional project names: $($all_names -join ',') 

options:
    -modify_caffe   update path for caffe base project,see also 'modify_caffe_folder' function in myself source
    -v,-verbose     list verbosely
    -f,-force       force download if package without version is exist  
    -list,-list_only without fetching ,only output dependent package list which need download.
    -h,-help        print the message
author: guyadong@gdface.net
"
    }
}
# 所有项目列表
$all_names="7z msys2 mingw32 mingw64 jom cmake protobuf gflags glog leveldb lmdb snappy openblas boost hdf5 opencv bzip2 ssd caffe_windows".Trim() -split '\s+'
# 当前脚本名称
$my_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
# 对于md5为空的项目，当本地存在压缩包时是否强制从网络下载
$FORCE_DOWNLOAD_IF_EXIST=$force
# 运行过程中是否显示显示详细的进行步骤
$VERBOSE_EXTRACT=$verbose
$NEED_DOWNLOAD_PREFIX='dependend package'
$SKIP_DOWNLOAD_PREFIX='available package'
# 检查所有项目名称参数，如果是无效值则报错退出
if($help){
    print_help  
    exit 0
}
if($modify_caffe){
    modify_caffe_folder $modify_caffe
    exit 0    
}
if(! $names){
    $names= $all_names
}
echo $names| foreach {    
    if( $_ -and ! (Test-Path function:"fetch_$($_.ToLower())") ){
        Write-Host "(不识别的项目名称)unknow project name:$_" -ForegroundColor Yellow
        print_help
        exit -1
    }
}
# 创建 package,source,tools 根目录
mkdir_if_not_exist $PACKAGE_ROOT
mkdir_if_not_exist $SOURCE_ROOT
mkdir_if_not_exist $TOOLS_ROOT
if($UNPACK_TOOL){
    fetch_7z
}
Write-Host "解压缩工具(unpack tool):$UNPACK_TOOL" -ForegroundColor Yellow
# 顺序下载解压 $names 中指定的项目
echo $names| foreach {
    trap{
        if($_.Exception.Message.StartsWith($NEED_DOWNLOAD_PREFIX)){
            Write-Host $_
            continue            
        }elseif($_.Exception.Message.StartsWith($SKIP_DOWNLOAD_PREFIX)){
            Write-Host $_
            continue
        }
        break;
    }  
    if( $_){
        &"fetch_$($_.ToLower())"  
    }    
}
