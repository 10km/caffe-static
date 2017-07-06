
. "$PSScriptRoot/build_funs.ps1"
$BUILD_VARS_INCLUDED=$true
function get_os_processor(){
    try { 
        # �ȳ���ִ��linux�����жϲ���ϵͳ,�����쳣ʱִ��windows��ָ��
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
# ���ɰ�װ·������׺
function install_suffix([string]$prefix){
    args_not_null_empty_undefined prefix HOST_OS BUILD_INFO
    if($BUILD_INFO.is_msvc()){
        $link=$(if($BUILD_INFO.msvc_shared_runtime){'_md'}else{'_mt'})
        $c=$BUILD_INFO.vc_version.$($BUILD_INFO.compiler)
    }else{
        $link=''
        $c=$BUILD_INFO.compiler+($BUILD_INFO.gcc_version -replace '[^\w]','')
    }
    
    $debug=$(if($BUILD_INFO.build_type -eq 'debug' ){'_d'}else{''})
    return "${prefix}_${HOST_OS}_${c}_$($BUILD_INFO.arch)$link$debug"
}
# ���ݹ�ϣ���ṩ����Ϣ����project info����
function create_project_info([hashtable]$hash,[switch]$no_install_path){
	args_not_null_empty_undefined hash INSTALL_PREFIX_ROOT
    $info= New-Object PSObject  -Property $hash
    # û�ж��� prefix �Ĳ�����install_path
    if($info.prefix -and !$no_install_path){
        Add-Member -InputObject $info -MemberType ScriptMethod -Name install_path -Value {
            # ��������� install_prefix �Ҳ�Ϊ���򷵻ش�ֵ
            if($this.install_prefix){
                $this.install_prefix}
            else{
                # caffe ��Ŀ��װ·��ǰ��������
                $p=$this.prefix
                if($this.prefix -eq 'caffe' -and $this.owner){
                    $p="$($this.owner)_$p"                                        
                }
                $(Join-Path -ChildPath $(install_suffix $p) -Path $INSTALL_PREFIX_ROOT)
            }
        }
    }
    $f=$info.prefix
    # ���û�ж���汾�ţ���folder��prefix��ͬ
    if($info.version){
       $f+="-"+$info.version
    }
	if(! $info.folder){
		Add-Member -InputObject $info -NotePropertyName folder -NotePropertyValue $f
	}
    return $info
}
# Ĭ�ϵ�GCC��������װ·��
#DEFAULT_GCC=
# ����ϵͳ,CPU����
$HOST_OS,$HOST_PROCESSOR=get_os_processor
# �ű�����·��
$BIN_ROOT=$(Get-Item $MyInvocation.MyCommand.Definition).Directory
# ��Ŀ��Ŀ¼
$DEPENDS_ROOT=$BIN_ROOT.Parent.FullName
# ��װ��Ŀ¼
$INSTALL_PREFIX_ROOT=Join-Path -ChildPath release -Path $DEPENDS_ROOT
# Դ���Ŀ¼
$SOURCE_ROOT=Join-Path -ChildPath source -Path $DEPENDS_ROOT
# ѹ������Ŀ¼
$PACKAGE_ROOT=Join-Path -ChildPath package -Path $DEPENDS_ROOT 
# �����ļ���Ŀ¼
$PATCH_ROOT=Join-Path -ChildPath patch -Path $DEPENDS_ROOT 
# �����������Ŀ¼
$TOOLS_ROOT=Join-Path -ChildPath tools -Path $DEPENDS_ROOT 


##################################��Ŀ������Ϣ
$PROTOBUF_INFO= create_project_info @{
	prefix="protobuf"
	version="3.3.1"
	md5="9377e414994fa6165ecb58a41cca3b40"
	owner="google"
	package_prefix="v"
}

$GLOG_INFO= create_project_info @{
	prefix="glog"
	version="0.3.5"
	md5="454766d0124951091c95bad33dafeacd"
	owner="google"
	package_prefix="v"
}

$GFLAGS_INFO= create_project_info @{
	prefix="gflags"
	version="2.2.0"
	md5="f3d31a4225a7e0e6cac50b2b65525317"
	version_2_1_2="2.1.2"
	md5_2_1_2="5cb0a1b38740ed596edb7f86cd5b3bd8"
	owner="gflags"
	package_prefix="v"
}

$leveldb_google_hash= @{
	prefix="leveldb"
	version="1.18"
	md5="06e9f4984e40ccf27af366d5bec0580a"
	owner="google"
	package_prefix="v"
}
$leveldb_zeux_hash= @{
	prefix="leveldb"
	version="master"
	owner="zeux"
}
# https://github.com/bureau14/leveldb
$leveldb_bureau14_hash= @{
	prefix="leveldb"
	version="master"
	owner="bureau14"
}

$LEVELDB_INFO= create_project_info $leveldb_bureau14_hash

$SNAPPY_INFO= create_project_info @{
	prefix="snappy"
	version="master"
	owner="google"
	package_prefix=""
}
$SNAPPY_1_1_4_INFO= create_project_info @{
	prefix="snappy"
	version="1.1.4"
	md5="b9bdbb6818d9c66b31edb6c037fef3d0"
	owner="google"
	package_prefix=""
}
$OPENBLAS_INFO= create_project_info @{
	prefix="OpenBLAS"
	version="0.2.18"
	md5="4ca49eb1c45b3ca82a0034ed3cc2cef1"
	owner="xianyi"
	package_prefix="v"
}

$LMDB_INFO= create_project_info @{
	prefix="lmdb"
	version="0.9.21"
	md5="a47ddf0fade922e8335226726be5e6c4"
	owner="LMDB"
	package_prefix="LMDB_"
}

# 1.0.5 zip ��(github����)
$BZIP2_INFO= create_project_info @{
	prefix="bzip2"
	version="1.0.5"
	md5="052fec5cdcf9ae26026c3e85cea5f573"
	owner="LuaDist"
	package_prefix=""
}

# 1.0.6 tar.gz��(���� bzip2.org ����)
$BZIP2_1_0_6_INFO= create_project_info @{
	prefix="bzip2"
	version="1.0.6"
	md5="00b516f4704d4a7cb50a1d97e6e8e15b"
	package_prefix=""
    package_suffix=".tar.gz"
}

$BOOST_1_58_INFO= create_project_info @{
	prefix="boost"
	version="1.58.0"
	md5="5a5d5614d9a07672e1ab2a250b5defc5"
    package_suffix=".tar.gz"
}
$BOOST_1_62_INFO= create_project_info @{
	prefix="boost"
	version="1.62.0"
	md5="6f4571e7c5a66ccc3323da6c24be8f05"
    package_suffix=".tar.gz"
}
$BOOST_INFO=$BOOST_1_62_INFO
$HDF5_INFO= create_project_info @{
	prefix="hdf5"
	version="1.8.16"
	md5="a7559a329dfe74e2dac7d5e2d224b1c2"
    package_suffix=".tar.gz"
}

$OPENCV_INFO= create_project_info @{
	prefix="opencv"
	version_2_4_9="2.4.9"
	md5_2_4_9="7f958389e71c77abdf5efe1da988b80c"
	version="2.4.13.2"
	md5="e48803864e77fc8ae7114be4de732d80"
	owner="opencv"
	package_prefix=""
}

$SSD_INFO= create_project_info @{
	prefix="caffe"
    version="ssd"
    owner="weiliu89"	
}
#https://github.com/conner99/caffe.git brance:ssd-microsoft 
$CONNER99_SSD_INFO= create_project_info @{
	prefix="caffe"
    version="ssd-microsoft"
    owner="conner99"	
}
$CAFFE_WINDOWS_INFO= create_project_info @{
	prefix="caffe"
    version="windows"
    owner="BVLC"	
}

# �Զ��� caffe ��Ŀ���ö��� 
$CAFFE_CUSTOM_INFO= create_project_info @{
	prefix='caffe'
    version='custom'
    # ��װ·��
    install_prefix=$null
    # Դ��·��
    root=$null
}
$cmake_hash_linux=@{
    prefix="cmake"
    version="3.8.2"
	md5="ab02cf61915e1ad15b8523347ad37c46"
	folder="cmake-3.8.2-Linux-x86_64"
    package_suffix=".tar.gz"
}
$cmake_hash_windows=@{
    prefix="cmake"
    version="3.8.2"
    md5="8b28478c3c19d0e8ff895e8f4fd0c5b6"
    folder="cmake-3.8.2-win32-x86"
    package_suffix=".zip"
}
$CMAKE_INFO= create_project_info $cmake_hash_windows -no_install_path
# ���root����
Add-Member -InputObject $CMAKE_INFO -NotePropertyName root -NotePropertyValue (Join-Path -ChildPath $CMAKE_INFO.folder -Path $TOOLS_ROOT )
# ���exe����
Add-Member -InputObject $CMAKE_INFO -NotePropertyName exe -NotePropertyValue ([io.path]::combine($CMAKE_INFO.root,"bin","cmake"))

$MSYS2_INFO_X86= create_project_info @{
    prefix="msys2-base"
    version="i686-20161025"
    md5="2799d84b4188b8faa772be6f80db9f45"
    folder="msys32"
    package_suffix=".tar.xz"
} -no_install_path
$MSYS2_INFO_X86_64= create_project_info @{
    prefix="msys2-base"
    version="x86_64-20161025"
    md5="c1598fe0591981611387abee5089dd1f"
    folder="msys64"
    package_suffix=".tar.xz"
} -no_install_path
# ���root����
Add-Member -InputObject $MSYS2_INFO_X86 -NotePropertyName root -NotePropertyValue (Join-Path -ChildPath $MSYS2_INFO_X86.folder -Path $TOOLS_ROOT )
Add-Member -InputObject $MSYS2_INFO_X86_64 -NotePropertyName root -NotePropertyValue (Join-Path -ChildPath $MSYS2_INFO_X86_64.folder -Path $TOOLS_ROOT )
$MSYS2_INFO= Get-Variable "MSYS2_INFO_$HOST_PROCESSOR" -ValueOnly 

# msys2��װ��Ŀ¼,�п������û��Լ���װ�ģ�Ҳ�����Ǳ�ϵͳ��װ��
$MSYS2_INSTALL_LOCATION=get_msys2_location
$MINGW32_POSIX_INFO= create_project_info @{
    prefix="mingw32"
    version="5.4.0"
    md5="9e748a2033063099b4a79bfea759610b"
    folder="mingw32"
    package_suffix=".7z"
} -no_install_path
$MINGW64_POSIX_INFO= create_project_info @{
    prefix="mingw64"
    version="5.4.0"
    md5="0e605e8ab54db04783f550e7df6ac7fc"
    folder="mingw64"
    package_suffix=".7z"
} -no_install_path
# ���root����
Add-Member -InputObject $MINGW32_POSIX_INFO -NotePropertyName root -NotePropertyValue (Join-Path -ChildPath $MINGW32_POSIX_INFO.folder -Path $TOOLS_ROOT )
Add-Member -InputObject $MINGW64_POSIX_INFO -NotePropertyName root -NotePropertyValue (Join-Path -ChildPath $MINGW64_POSIX_INFO.folder -Path $TOOLS_ROOT )

$7Z_INFO_X86= create_project_info @{
    prefix="7z"
    version="1604"
    md5="8cfd1629f23dfdad978349c93241ef6d"
    folder="7z1604"
    package_suffix=".msi"
} -no_install_path
$7Z_INFO_X86_64= create_project_info @{
    prefix="7Z"
    version="1604"
    md5="caf2855194340b982a9ef697aca17fa9"
    folder="7z1604-x64"
    package_suffix=".msi"
} -no_install_path
$7Z_INFO=Get-Variable "7Z_INFO_$HOST_PROCESSOR" -ValueOnly 
# ���root����
Add-Member -InputObject $7Z_INFO_X86 -NotePropertyName root -NotePropertyValue (Join-Path -Path $TOOLS_ROOT -ChildPath $7Z_INFO_X86.folder  )
Add-Member -InputObject $7Z_INFO_X86_64 -NotePropertyName root -NotePropertyValue (Join-Path -Path $TOOLS_ROOT -ChildPath $7Z_INFO_X86_64.folder )
$JOM_INFO= create_project_info @{
    prefix="jom"
    version="1.1.2"
    md5="7dfc3ba65f640a32a54e8e047f98209c"
    package_suffix=".zip"
} -no_install_path
# ���root����
Add-Member -InputObject $JOM_INFO -NotePropertyName root -NotePropertyValue (Join-Path  -Path $TOOLS_ROOT -ChildPath $JOM_INFO.folder )
# ���exe����
Add-Member -InputObject $JOM_INFO -NotePropertyName exe -NotePropertyValue (Join-Path $JOM_INFO.root -ChildPath "jom" )

# ָ�������ѹ����
# ����ָ����exe����֧�����������еİ汾,
# ����7z�� GUI�汾�Ŀ�ִ���ļ��� 7zfm.exe,�����а汾����7z.exe
# ��ѹ(HaoZip)��GUI�汾�Ŀ�ִ���ļ��� HaoZip.exe,�����а汾���� HaoZipC.exe
# ��������ô�ֵ���ű���ͨ�� assoc,ftype������ң����п��ܲ��Ҳ���
#$UNPACK_TOOL="C:\Program Files\7-Zip\7z.exe"
#$UNPACK_TOOL="C:\Program Files\2345Soft\HaoZip\HaoZipC.exe"
$UNPACK_TOOL=get_unpack_cmdexe
