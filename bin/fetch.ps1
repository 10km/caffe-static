<#
����caffe-ssd���������������Դ���Լ�cmake,msys2�ȹ��ߣ�
���ص�Դ��ѹ��������� $PACKAGE_ROOT �ļ�����
����ѹ���� $SOURCE_ROOT �ļ����£�
���ѹ�����Ѿ���������������ֱ�ӽ�ѹ��
���Դ����Ҫ�޸ģ����Զ�����ļ��޸�( modify_xxx ϵ�к���)
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

# $file �������ļ�·��
# $md5 md5У����
# ���$file������ ����$true
# ���$file���ļ����򱨴��˳�
# ���$file������checksum��$2ָ����md5����򷵻� $false,���򷵻�$true
# ���$file������md5Ϊ��ʱ����ȫ�ֱ���$FORCE_DOWNLOAD_IF_EXIST�����Ƿ���Ҫ����
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
		# $file���ļ����򱨴��˳�
		echo "invalid argument: package=$file is a folder!!!"
		call_stack
		exit -1
	}else{
		return $true
	}
}
# ���ز���ѹָ������Ŀ�ļ�
# $noUnpack ���ص���ִ�н�ѹ
# $noFolder ѹ�������Ƕ������ļ��нṹ
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
		Write-Host "(����)downloading" $info.prefix $version -ForegroundColor Yellow
        # ����ΪTls12 �������
        # Invoke-WebRequest : ������ֹ: δ�ܴ��� SSL/TLS ��ȫͨ����
        # �μ� https://stackoverflow.com/questions/41618766/powershell-invoke-webrequest-fails-with-ssl-tls-secure-channel
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # �� .exe �ļ�����ʱ�ĺ�׺Ϊzip,�Ա���ɱ���������
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
            Write-Host "����ʧ��,�볢���ֹ�����" -ForegroundColor Yellow
            exit -1
        }
	}elseif($list_only){
        throw "${SKIP_DOWNLOAD_PREFIX}: $package_path"
    }	
    if(!$noUnpack){
	    remove_if_exist (Join-Path $targetRoot $info.folder)
	    Write-Host "(��ѹ��)extracting file from $package_path" -ForegroundColor Yellow
	    unpack $package_path -targetFolder $(if($noFolder){$(Join-Path $targetRoot -ChildPath $info.folder )}else{$targetRoot})	
    }
}
# ��github������Դ��
# ������ز�����ָ����zip������$md5Ϊ�ջ�$md5У���벻ƥ�����github����
# ������ش���ָ����zip������ $md5 Ϊ��,����� $FORCE_DOWNLOAD_IF_EXIST �����Ƿ���������ֱ�ӽ�ѹ
# $info ��Ŀ������Ϣ $xxxx_INFO
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
# �� sourceforge.net ���� boost 
function fetch_boost(){
	$remote_prefix=$BOOST_INFO.prefix+'_'+$BOOST_INFO.version.Replace('.','_')
    $uri="https://nchc.dl.sourceforge.net/project/boost/boost/$($BOOST_INFO.version)/$remote_prefix$($BOOST_INFO.package_suffix)"
	download_and_extract -info $BOOST_INFO -uri $uri 
	pushd $SOURCE_ROOT
	Rename-Item -Path $remote_prefix -NewName $BOOST_INFO.folder
    exit_on_error
    popd
}
# ���� hdf5
function fetch_hdf5(){
    $package_prefix="CMake-"+$HDF5_INFO.folder
    $uri='https://support.hdfgroup.org/ftp/HDF5/releases',$HDF5_INFO.folder,'src',($package_prefix+$HDF5_INFO.package_suffix) -join '/'
    download_and_extract -info $HDF5_INFO -uri $uri
	pushd $SOURCE_ROOT
	Rename-Item -Path $package_prefix -NewName $HDF5_INFO.folder
    exit_on_error
    popd
}
# ���� cmake ѹ������ѹ�� $TOOLS_ROOT
function fetch_cmake(){
    $uri= "https://cmake.org/files/v3.8/$($CMAKE_INFO.folder)$($CMAKE_INFO.package_suffix)"
    download_and_extract -info $CMAKE_INFO -uri $uri -targetRoot $TOOLS_ROOT	
}
# ���� jom ѹ������ѹ�� $TOOLS_ROOT
function fetch_jom(){
    $uri="http://download.qt.io/official_releases/$($JOM_INFO.prefix)/$($JOM_INFO.prefix)_$($JOM_INFO.version.Replace('.','_'))$($JOM_INFO.package_suffix)"
    download_and_extract -info $JOM_INFO -uri $uri -targetRoot $TOOLS_ROOT -noFolder
}
# ���� mingw32 (MinGW 32λ������) ѹ������ѹ�� $TOOLS_ROOT
function fetch_mingw32(){
    $poject=$MINGW32_INFO
    $uri= "https://nchc.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/$($poject.version)/threads-win32/dwarf/i686-$($poject.version)-release-win32-dwarf-rt_v5-rev0.7z"
    download_and_extract -info $poject -uri $uri -targetRoot $TOOLS_ROOT	
}
# ���� mingw64 (MinGW 64λ������) ѹ������ѹ�� $TOOLS_ROOT
function fetch_mingw64(){
    $poject=$MINGW64_INFO
    $uri= "https://nchc.dl.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/$($poject.version)/threads-win32/sjlj/x86_64-$($poject.version)-release-win32-sjlj-rt_v5-rev0.7z"
    download_and_extract -info $poject -uri $uri -targetRoot $TOOLS_ROOT	
}
# ���� msys2 ѹ��������װ
# ��װ msys2 ��,�� msys2 �а�װ perl
function fetch_msys2(){
    # ����Ƿ�װ�� msys2�����û��װ�����ذ�װ
    if( ! $MSYS2_INSTALL_LOCATION ){
        $package="$($MSYS2_INFO.prefix)-$($MSYS2_INFO.version)$($MSYS2_INFO.package_suffix)"
        $arch=$MSYS2_INFO.version.Split('-')[0]
        $uri="http://repo.msys2.org/distrib/$arch/$package"
        download_and_extract -info $MSYS2_INFO -uri $uri -targetRoot $TOOLS_ROOT
        $MSYS2_INSTALL_LOCATION=$MSYS2_INFO.root
    }
    if($list_only){ return }
    # ���û�а�װ perl,�� MSYS2 �а�װ perl
    Write-Host "(��װperl) install perl if not present"
    $bash=[io.path]::Combine($($MSYS2_INSTALL_LOCATION),'usr','bin','bash')
    cmd /c "$bash -l -c `"if [ ! `$(which perl) ] ;then pacman -S --noconfirm perl ;fi; perl --version`" 2>&1"
    exit_on_error "(perl��װʧ�ܣ�������)fail to install perl,please try again"
}
# ���ϵͳ��û�а�װ��ѹ������(haozip,7z)������ 7z ѹ��������ѹ�� $TOOLS_ROOT
function fetch_7z(){
    # ����Ƿ�װ�� ��ѹ����������û��װ�����ذ�װ
    if( ! $UNPACK_TOOL ){
        $package="$($7Z_INFO.folder)$($7Z_INFO.package_suffix)"
        $uri="http://7-zip.org/a/$package"
        download_and_extract -info $7Z_INFO -uri $uri -noUnpack
        # �� .msi ��ѹ��ָ��·��
        $target_folder=Join-Path $TOOLS_ROOT -ChildPath $7Z_INFO.folder
        remove_if_exist $target_folder
        cmd /c "msiexec /a `"$(Join-Path $PACKAGE_ROOT -ChildPath $package)`" /qn TARGETDIR=`"$target_folder`" 2>&1 "
        exit_on_error "(7-zip��װʧ�ܣ�������)fail to install 7-zip,please try again"
        # ���⿪�� .msi ���� Files/7-Zip �ļ����Ƶ���Ŀ¼��Ȼ��ɾ���������õ��ļ�
        $delitem=Get-ChildItem $target_folder
        Get-ChildItem ([io.path]::Combine($target_folder,'Files','7-Zip')) | Move-Item -Destination $target_folder
        $delitem |Remove-Item -Recurse 
        $UNPACK_TOOL = get_unpack_cmdexe
    }
}
# ���� bzip2 1.0.6 
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
        echo "function:$($MyInvocation.MyCommand) -> �޸� $bzip2_makefile,�ڱ���ѡ�������� -fPIC ����"
        (Get-Content $bzip2_makefile) -replace '(^\s*CFLAGS\s*=)(.*$)','#modified by guyadong,add -fPIC
$1-fPIC $2' | Out-File $bzip2_makefile -Encoding ascii -Force
        exit_on_error
    }	
}
#################################################################
function modify_bzip2_1_0_5(){
	$bzip2_cmake=[io.path]::combine($SOURCE_ROOT,$BZIP2_INFO.folder,"CMakeLists.txt")
	echo "function:$($MyInvocation.MyCommand) -> �޸� $bzip2_cmake ,ɾ�� SHARED ����" 
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
	echo "function:$($MyInvocation.MyCommand) -> �޸� $snappy_cmake ,ɾ�� SHARED ����"
    (Get-Content $snappy_cmake) -replace '(^\s*ADD_LIBRARY\s*\(\s*snappy\s*)SHARED','#modified by guyadong,remove SHARED
$1'| Out-File $snappy_cmake -Encoding ascii -Force    
    $snappy_test_cc=[io.path]::combine($SOURCE_ROOT,$SNAPPY_INFO.folder,"snappy-test.cc")
    echo "function:$($MyInvocation.MyCommand) -> �޸� $snappy_test_cc ,���msvc�±������"
    (Get-Content $snappy_test_cc -Raw ) -replace '(.*)(?!\()\s*(std::max)\s*(?!\))(.*)','// modified by guyadong
$1($2)$3' | Out-File $snappy_test_cc -Encoding ascii -Force
	exit_on_error
}
######################################################
function modify_ssd(){
	$ssd_src=Join-Path -Path $SOURCE_ROOT -ChildPath $SSD_INFO.folder
	echo "function:$($MyInvocation.MyCommand) -> (�����޸ĵĲ����ļ�)copy patch file to $ssd_src"	
    cp -Path (Join-Path -Path $PATCH_ROOT -ChildPath $SSD_INFO.folder) -Destination $SOURCE_ROOT -Recurse -Force -Verbose
	exit_on_error 
}
# ���� caffe ��Ŀ����ͨ�ò�������, 
# ���� caffe ϵ����Ŀfetch�� Ӧ�ȵ��ô˺������޲�
# $caffe_root caffe Դ���Ŀ¼
function modify_caffe_folder([string]$caffe_root){
    args_not_null_empty_undefined caffe_root
    exit_if_not_exist $caffe_root -type Container
    # ͨ���ǲ�����src/caffe �ļ����ж��ǲ��� caffe ��Ŀ
    exit_if_not_exist ([io.path]::Combine($caffe_root,'src','caffe')) -type Container -msg "$caffe_root �����Ǹ� caffe Դ���ļ���"
    $cmakelists_root=Join-Path $caffe_root -ChildPath CMakeLists.txt
    exit_if_not_exist $cmakelists_root -type Leaf
    Write-Host "function:$($MyInvocation.MyCommand) ->  caffe ��Ŀ����ͨ���޸�"
    $content=Get-Content $cmakelists_root
    $regex_disable_download='(^\s*include\s*\(\s*cmake/WindowsDownloadPrebuiltDependencies\.cmake\s*\))'
    if( $content -match $regex_disable_download){
        Write-Host "(��ֹ Windows Ԥ���������) disable download prebuilt dependencies ($cmakelists_root)" 
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
        Write-Host "(���� hdf5 ������) use hdf5 static library ($dependencies_cmake)"
        $content -replace $regex_hdf5_block,'$1#modified by guyadong 
# Find HDF5 always using static libraries
find_package(HDF5 COMPONENTS C HL REQUIRED)
set(HDF5_LIBRARIES hdf5-static)
set(HDF5_HL_LIBRARIES hdf5_hl-static)$2'| Out-File $dependencies_cmake -Encoding ascii -Force
        exit_on_error 
    }else{
        Write-Host "(û���ҵ� HDF5 ��ش���)��found hdf5 flags in $dependencies_cmake" -ForegroundColor Yellow
        call_stack
        exit -1
    }
	echo "function:$($MyInvocation.MyCommand) -> (�����޸ĵĲ����ļ�)copy patch file to $caffe_root"	
    cp -Path ([io.path]::Combine($PATCH_ROOT,'caffe_base','*')) -Destination $caffe_root -Recurse -Force -Verbose    
	exit_on_error 
}

# ���� BVLC/caffe windows brance ��Ŀ(https://github.com/BVLC/caffe/tree/windows)���벹������,��ҪΪ��mingw����
# $caffe_root caffe Դ���Ŀ¼
function modify_bvlc_caffe_windows([string]$caffe_root){
    args_not_null_empty_undefined caffe_root
	echo "function:$($MyInvocation.MyCommand) -> (�����޸ĵĲ����ļ�)copy patch file to $caffe_root"	
    cp -Path ([io.path]::Combine($PATCH_ROOT,'blvc_caffe_windows','*')) -Destination $caffe_root -Recurse -Force -Verbose    
	exit_on_error 
}
# ���� caffe ��Ŀ����ͨ�ò�������,�����޸���Դ���cmake�ű�
# ���� caffe ϵ����Ŀfetch�� Ӧ�ȵ��ô˺������޲�
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
	    echo "function:$($MyInvocation.MyCommand) -> (�����޸ĵĲ����ļ�)copy patch file to $leveldb_src"	
        cp -Path $patch_folder -Destination $SOURCE_ROOT -Force -Verbose -Recurse
	    exit_on_error
    }
}
. "$PSScriptRoot/modwin.ps1"
function modify_lmdb(){
    $lmdb_src=[io.path]::Combine($SOURCE_ROOT,$LMDB_INFO.folder,'libraries','liblmdb')
    echo "function:$($MyInvocation.MyCommand) -> (�����޸ĵĲ����ļ�)copy patch file to $lmdb_src"	
    cp -Path ([io.path]::combine($PATCH_ROOT,$LMDB_INFO.folder,"*")) -Destination $lmdb_src -Force -Verbose
    exit_on_error
}
function modify_openblas(){
    $openblas_src=Join-Path -Path $SOURCE_ROOT -ChildPath $OPENBLAS_INFO.folder
    $patch_folder=Join-Path -Path $PATCH_ROOT -ChildPath $OPENBLAS_INFO.folder
    echo "function:$($MyInvocation.MyCommand) -> (�����޸ĵĲ����ļ�)copy patch file to $openblas_src"   
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

# ���������Ϣ
function print_help(){
    if($(chcp ) -match '\.*936$'){
	    echo "�÷�: $my_name [-names] [��Ŀ�����б�,...] [��ѡ��...] 
���ز���ѹָ������Ŀ�����û��ָ����Ŀ���ƣ������ؽ�ѹ������Ŀ
    -n,-names       ��Ŀ�����б�(���ŷָ�,���Դ�Сд,�޿ո�)
                    ��ѡ����Ŀ����: $($all_names -join ',')
ѡ��:
    -modify_caffe   Ϊָ���� caffe Դ����²����ļ�,�μ����ű�Դ���� modify_caffe_folder ����
    -v,-verbose     ��ʾ��ϸ��Ϣ
    -f,-force       ǿ������û��ָ���汾�ŵ���Ŀ
    -list,-list_only ��ִ�����ؽ�ѹ��,ֻ�г���Ҫ���ص�������,�������������õ�ʱ��,
                    ���Ը��ݱ����г��ĵ�ַ�ֹ�����������
    -h,-help        ��ʾ������Ϣ
����: guyadong@gdface.net
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
# ������Ŀ�б�
$all_names="7z msys2 mingw32 mingw64 jom cmake protobuf gflags glog leveldb lmdb snappy openblas boost hdf5 opencv bzip2 ssd caffe_windows".Trim() -split '\s+'
# ��ǰ�ű�����
$my_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
# ����md5Ϊ�յ���Ŀ�������ش���ѹ����ʱ�Ƿ�ǿ�ƴ���������
$FORCE_DOWNLOAD_IF_EXIST=$force
# ���й������Ƿ���ʾ��ʾ��ϸ�Ľ��в���
$VERBOSE_EXTRACT=$verbose
$NEED_DOWNLOAD_PREFIX='dependend package'
$SKIP_DOWNLOAD_PREFIX='available package'
# ���������Ŀ���Ʋ������������Чֵ�򱨴��˳�
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
        Write-Host "(��ʶ�����Ŀ����)unknow project name:$_" -ForegroundColor Yellow
        print_help
        exit -1
    }
}
# ���� package,source,tools ��Ŀ¼
mkdir_if_not_exist $PACKAGE_ROOT
mkdir_if_not_exist $SOURCE_ROOT
mkdir_if_not_exist $TOOLS_ROOT
if($UNPACK_TOOL){
    fetch_7z
}
Write-Host "��ѹ������(unpack tool):$UNPACK_TOOL" -ForegroundColor Yellow
# ˳�����ؽ�ѹ $names ��ָ������Ŀ
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
