#!/bin/bash
shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars
: << !
下载caffe-ssd及其所有依赖库的源码以及cmake工具，
下载的源码压缩包存放在$PACKAGE_ROOT文件夹下
并解压缩到 $SOURCE_ROOT 文件夹下，
如果压缩已经存在则跳过下载直接解压缩
!


# 如果文件存在且checksum与$2指定的md5相等则返回 1,否则返回0
# $1 待检查的文件路径
# $2 md5校验码
need_download(){
	if [ $# -eq 2 ]
	then
		if [ -f $1 ]; then
			echo "File already exists. Checking md5..."
			local os=`uname -s`
			if [ $(which md5sum) ]
			then 
				local checksum=`md5sum $1 | awk '{ print $1 }'`
			elif [ "$os" = "Darwin" ]; then
				local checksum=`cat $1 | md5`
			else 
				echo "not found md5sum"; 
				exit -1
			fi
			exit_on_error
			if [ "$checksum" = "$2" ]; then
				echo "Checksum is correct. No need to download $1."
				return 1
			else
				echo "Checksum is incorrect. Need to download again $1"
			fi
		else
			return 0
		fi
	else 
		echo invalid argument:
		echo $*
		exit -1
	fi
}
# 从github上下载源码
# 如果本地不存在指定的zip包，或$md5为空或$md5校验码不匹配则从github下载
# 如果本地存在指定的zip包，且$md5为空,则根据$FORCE_DOWNLOAD_IF_EXIST决定是否跳过下载直接解压
# $1 项目名称
fetch_from_github(){
	if [ $# -eq 1 ]
	then
		eval $(declare_project_local_vars $1)
		if [ -z "$prefix" ];
		then
			echo "invalid argument:$1"
			exit -1
		fi
		local package="$folder.zip"
		if [ -z "$md5" ] || need_download $PACKAGE_ROOT/$package $md5
		then
			if [ -n "$md5" ] || [ $FORCE_DOWNLOAD_IF_EXIST -eq 1 ] 
			then
				echo "${FUNCNAME[0]}:(下载源码)downloading $prefix $version source"
				remove_if_exist $PACKAGE_ROOT/$package
				wget --no-check-certificate https://github.com/$owner/$prefix/archive/$package_prefix$version.zip -O $PACKAGE_ROOT/$package
				exit_on_error
			fi
		fi
		remove_if_exist $SOURCE_ROOT/$folder
		echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
		unzip $UNZIP_VERBOSE $PACKAGE_ROOT/$package -d $SOURCE_ROOT
		exit_on_error
		if [ -n "$package_prefix" ] && [ -d "$SOURCE_ROOT/$prefix-$package_prefix$version" ]
		then
			echo rename $prefix-$package_prefix$version to $folder
			mv $SOURCE_ROOT/$prefix-$package_prefix$version $SOURCE_ROOT/$folder
		fi
	else
		echo invalid argument:
		echo $*
		exit -1
	fi
}
###################################################
fetch_boost(){
	eval $(declare_project_local_vars $BOOST_PREFIX)
	local package="$folder.tar.gz"
	local remote_prefix="${prefix}_${version//./_}"
	if need_download $PACKAGE_ROOT/$package $md5
	then
		remove_if_exist $PACKAGE_ROOT/$package
		echo "${FUNCNAME[0]}:(下载源码)downloading $version $version source"
		wget --no-check-certificate https://nchc.dl.sourceforge.net/project/boost/boost/$version/$remote_prefix.tar.gz -O $PACKAGE_ROOT/$package
		exit_on_error
	fi
	remove_if_exist $SOURCE_ROOT/$folder
	echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
	tar zxf$VERBOSE_EXTRACT $PACKAGE_ROOT/$package -C $SOURCE_ROOT
	mv $SOURCE_ROOT/$remote_prefix $SOURCE_ROOT/$folder
	exit_on_error
}

######################################################
fetch_hdf5(){
	eval $(declare_project_local_vars $HDF5_PREFIX)
	local package="$folder.tar.gz"
	local package_prefix="CMake-$folder"
	if need_download $PACKAGE_ROOT/$package $md5
	then
		remove_if_exist $PACKAGE_ROOT/$package
		echo "${FUNCNAME[0]}:(下载源码)downloading $prefix $version source"
		wget --no-check-certificate https://support.hdfgroup.org/ftp/HDF5/releases/$folder/src/$package_prefix.tar.gz -O $PACKAGE_ROOT/$package
		exit_on_error
	fi
	remove_if_exist $SOURCE_ROOT/$folder
	echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
	tar zxf$VERBOSE_EXTRACT $PACKAGE_ROOT/$package -C $SOURCE_ROOT
	exit_on_error
	echo rename $package_prefix to $folder
	mv $SOURCE_ROOT/$package_prefix $SOURCE_ROOT/$folder
	exit_on_error
}

#########################################################
fetch_opencv249(){
	eval $(declare_project_local_vars $OPENCV_PREFIX)
	local package="$folder.zip"
	if need_download $PACKAGE_ROOT/$package $md5
	then
		remove_if_exist $PACKAGE_ROOT/$package
		echo "${FUNCNAME[0]}:(下载源码)downloading $prefix $version source"
		wget --no-check-certificate https://nchc.dl.sourceforge.net/project/opencvlibrary/opencv-unix/$version/$package -O $PACKAGE_ROOT/$package
		exit_on_error
	fi
	remove_if_exist $SOURCE_ROOT/$folder 
	echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
	unzip $UNZIP_VERBOSE $PACKAGE_ROOT/$package -d $SOURCE_ROOT
	exit_on_error
}

######################################################
# bzip2官网下载 1.0.6版本
fetch_bzip2_1_0_6(){
#	eval $(declare_project_local_vars $BZIP2_PREFIX)
	local version="1.0.6"
	local folder=$BZIP2_PREFIX-$version
	local package="$folder.tar.gz"
	local md5=$BZIP2_TAR_GZ_MD5_1_0_6
	if need_download $PACKAGE_ROOT/$package $md5
	then
		echo "${FUNCNAME[0]}:(下载源码)downloading bzip2 $version source"
		wget --no-check-certificate http://www.bzip.org/$version/$package -O $PACKAGE_ROOT/$package
		exit_on_error
	fi
	remove_if_exist $SOURCE_ROOT/$folder
	echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
	tar zxf$VERBOSE_EXTRACT $PACKAGE_ROOT/$package -C $SOURCE_ROOT
	exit_on_error
	local bzip2_makefile=$SOURCE_ROOT/$folder/Makefile
	# 修改Makefile,在编译选项中增加-fPIC参数
	if [ -z "$(grep '^\s*CFLAGS\s*=' $bzip2_makefile | grep '\-fPIC')" ] 
	then
		echo "${FUNCNAME[0]}:add -fPIC to CFLAGS in $bzip2_makefile"
		sed -i -r 's/(^\s*CFLAGS\s*=)(.*$)/#modified by guyadong,add -fPIC\n\1-fPIC \2/g' $bzip2_makefile
		exit_on_error
	else
		echo "${FUNCNAME[0]}:found -fPIC in CFLAGS,no need modify $bzip2_makefile"
	fi
}
# 从github下载 1.0.5版本(支持cmake编译)
fetch_bzip2_1_0_5(){ 
	fetch_from_github "$BZIP2_PREFIX" ; 
	modify_bzip2_1_0_5
}
######################################################
# git clone方式下载caffe-ssd源码
fetch_ssd_clone(){
	eval $(declare_project_local_vars SSD)
	remove_if_exist $SOURCE_ROOT/$folder
	echo "$prefix代码clone到 $SOURCE_ROOT/$folder 文件夹下"
	git clone --recursive https://github.com/weiliu89/caffe.git $SOURCE_ROOT/$folder
	exit_on_error

	pushd $SOURCE_ROOT/$folder
	# 选择ssd分支
	git checkout ssd
	exit_on_error
	popd
}
# download zip方式下载caffe-ssd源码
fetch_ssd_zip(){
	eval $(declare_project_local_vars SSD)
	local package="$folder.zip"
	if [ $FORCE_DOWNLOAD_IF_EXIST -eq 1 ] || [ ! -f $PACKAGE_ROOT/$package ]
	then
		remove_if_exist $PACKAGE_ROOT/$package
		echo "${FUNCNAME[0]}:(下载源码)downloading $prefix $version source"
		wget --no-check-certificate https://github.com/weiliu89/caffe/archive/ssd.zip -O $PACKAGE_ROOT/$package
		exit_on_error
	fi

	remove_if_exist $SOURCE_ROOT/$folder
	echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
	unzip $UNZIP_VERBOSE $PACKAGE_ROOT/$package -d $SOURCE_ROOT
	exit_on_error
}

# 下载cmake
fetch_cmake(){
	eval $(declare_project_local_vars CMAKE)
	local package="$folder.tar.gz"
	if need_download $PACKAGE_ROOT/$package "$md5"
	then
		remove_if_exist $PACKAGE_ROOT/$package
		echo "${FUNCNAME[0]}:(下载cmake)downloading $package"
		wget --no-check-certificate https://cmake.org/files/v3.8/$package -P $PACKAGE_ROOT
		exit_on_error 
	fi
	echo "(解压缩文件)extracting file from $PACKAGE_ROOT/$package"
	remove_if_exist $TOOLS_ROOT/$folder
	tar zxf$VERBOSE_EXTRACT $PACKAGE_ROOT/$package -C $TOOLS_ROOT
	exit_on_error
}

######################################################
modify_snappy(){
	eval $(declare_project_local_vars $SNAPPY_PREFIX)
	local snappy_cmake=$SOURCE_ROOT/$folder/CMakeLists.txt
	echo "${FUNCNAME[0]}:修改$snappy_cmake,删除 SHARED 参数"
	sed -i -r 's/(^\s*ADD_LIBRARY\s*\(\s*snappy\s*)SHARED/#modified by guyadong,remove SHARED\n\1/g' $snappy_cmake
	exit_on_error
}
######################################################
modify_ssd(){
	eval $(declare_project_local_vars SSD)
	echo "${FUNCNAME[0]}:(复制修改的补丁文件)copy patch file to $SOURCE_ROOT/$folder"	
	pushd $SOURCE_ROOT/$folder
	cp -Pr$VERBOSE_EXTRACT $PATCH_ROOT/$folder/* .
	exit_on_error 
	popd
}
# 修改bzip2 1.0.5代码
modify_bzip2_1_0_5(){
	eval $(declare_project_local_vars $BZIP2_PREFIX)
	local bzip2_c=$SOURCE_ROOT/$folder/bzip2.c
	# 修改 bzip2.c,将#include语句的路径分隔符改为unix格式'/' 
	echo "${FUNCNAME[0]}:修改'#include <sys\stat.h>'为'#include <sys/stat.h>' in $bzip2_c"
	sed -i -r 's:^\s*#\s*include\s*<sys\\stat.h>\s*$:// modified by guyadong for cross compiling with MinGW \n#   include <sys/stat.h>:g'  $bzip2_c
	exit_on_error
	local bzip2_cmake=$SOURCE_ROOT/$folder/CMakeLists.txt
	echo "${FUNCNAME[0]}:修改$bzip2_cmake,删除 SHARED 参数"
	sed -i -r 's/(^\s*ADD_LIBRARY\s*\(\s*bz2\s*)SHARED/#modified by guyadong,remove SHARED\n\1/g' $bzip2_cmake
}
# 修改 lmdb 代码,增加 CMakeLists.txt
modify_lmdb(){
	eval $(declare_project_local_vars $LMDB_PREFIX)
	echo "${FUNCNAME[0]}:(复制修改的补丁文件)copy patch file to $SOURCE_ROOT/$folder/libraries/liblmdb"		
	cp -Pr$VERBOSE_EXTRACT $PATCH_ROOT/$folder/CMakeLists.txt $SOURCE_ROOT/$folder/libraries/liblmdb
}

fetch_protobuf(){ fetch_from_github "protobuf" ; }
fetch_gflags(){ fetch_from_github "gflags" ; }
fetch_glog(){ fetch_from_github "glog" ; }
fetch_leveldb(){ fetch_from_github "leveldb" ; }
fetch_lmdb(){ fetch_from_github "lmdb" ; modify_lmdb ; }
fetch_snappy(){ fetch_from_github "snappy" ; modify_snappy ; }
fetch_openblas(){ fetch_from_github "OpenBLAS" ; }
fetch_ssd(){ fetch_ssd_zip ; modify_ssd; }
fetch_opencv(){ fetch_from_github "opencv" ; }
fetch_bzip2(){ fetch_bzip2_1_0_5 ; }

# 输出帮助信息
print_help(){
	cat <<EOF
usage: $(basename $0) [PROJECT_NAME...]
download and extract projects specified by project name,
all projects fetched without argument
optional project names: $all_names (ignore case)

options:
	-v,--verbose     list verbosely
	-f,--force       force download if package without version is exist  
	-h,--help        print the message
author: guyadong@gdface.net
EOF
}
# 对于md5为空的项目，当本地存在压缩包时是否强制从网络下载,为1强制下载,为0不下载
FORCE_DOWNLOAD_IF_EXIST=0
# 运行过程中是否显示显示详细的进行步骤 "v" 显示，为空不显示
VERBOSE_EXTRACT=""
all_names="cmake protobuf gflags glog leveldb lmdb snappy openblas boost hdf5 opencv bzip2 ssd"
# 需要fetch的项目列表
fetch_projects=""	
# 命令行参数解析
formated_args=$(getopt -o hfv --long help,force -n $(basename $0) -- "$@")
if [ $? != 0 ] ; then echo "terminating..." >&2 ; exit 1 ; fi
eval set -- "$formated_args"
while true ; do
	case "$1" in
		-h|--help) print_help ; exit 0 ;;
		-f|--force) FORCE_DOWNLOAD_IF_EXIST=1; shift ;;
		-v|--verbose) VERBOSE_EXTRACT=v; shift ;;
		--) shift ; break ;;
		*) echo "internal error!" ; exit 1 ;;
	esac
done
# 根据 VERBOSE_EXTRACT 设置 unzip 解压缩时是否显示解压缩过程
[ -n "$VERBOSE_EXTRACT" ] && UNZIP_VERBOSE=""
[ -z "$VERBOSE_EXTRACT" ] && UNZIP_VERBOSE="-q"
# 检查所有项目名称参数，如果是无效值则报错退出
for prj in "$@" 
do
	f=fetch_$prj
	# 判断是否有效的项目名称
	if [ -z $(typeset -F $f) ]
	then
		echo "(不识别的项目名称)unkonw project name:$prj"
		print_help
		exit -1
	fi
	fetch_projects="$fetch_projects $prj"
done
# 如果没有提供参数，则下载所有项目 
if [ -z "$fetch_projects" ]
then
	fetch_projects="$all_names"
fi
for prj in $fetch_projects
do
	f=fetch_$prj
	# 判断是否有效的项目名称
	if [ -z $(typeset -F $f) ]
	then
		echo "unkonw project name:$prj"
		print_help
		exit -1
	fi
done

# 创建 package,source,tools 根目录
mkdir_if_not_exist $PACKAGE_ROOT
mkdir_if_not_exist $SOURCE_ROOT
mkdir_if_not_exist $TOOLS_ROOT

# 顺序下载解压 $fetch_projects中指定的项目
for prj in $fetch_projects
do
	fetch_$prj
done
