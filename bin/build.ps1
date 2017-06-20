param(
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[string]$gcc=$DEFAULT_GCC,
[switch]$help
)
# ������������Ĳ�����ʼ�� $BUILD_INFO ���� [PSObject]
$BUILD_INFO=New-Object PSObject -Property @{
    # ���������� vs2013|vs2015|gcc
    compiler=$compiler
    # cpu��ϵ x86|x86_64
    arch=$arch
    # vs2015 ��������
    env_vs2015='VS140COMNTOOLS'
    # vs2013 ��������
    env_vs2013='VS120COMNTOOLS'
    # msvc��װ·�� ��:"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC"
    msvc_root=""
    # gcc��װ·�� ��:P:\MinGW\mingw64\bin
    gcc_location=$gcc
    # gcc�汾��
    gcc_version=""
    # gcc ������ȫ·�� �� P:\MinGW\mingw64\bin\gcc.exe
    gcc_c_compiler=""
    # g++ ������ȫ·�� �� P:\MinGW\mingw64\bin\g++.exe
    gcc_cxx_compiler=""
    # cmake ��������
    cmake_vars_define=""
    # make �����ļ���,msvcΪnmake,mingwΪmake 
    make_exe=""
    # make ���߱���ʱ��Ĭ��ѡ��
    make_exe_option=""
}
. "./build_vars.ps1"
# ���� where ������·���в��� $who ָ���Ŀ�ִ���ļ�,
# ����ҵ��򷵻ص�һ�����
# ���û�ҵ����ؿ� 
function where_first($who){
    args_not_null_empty_undefined who    
    cmd /c "where $who >nul 2>nul"
    if($?){
        $w=$(cmd /c "where $who")
        if($w.Count -gt 1){$w[0]}else{$w}
    }
}
# �����ṩ�ı����������б���˳����ϵͳ����ⰲװ�ı�������
# ����ҵ��ͷ����ҵ��ı���������,
# ���û���ҵ��κ�һ�ֱ������򱨴��˳�
function detect_compiler(){    
    foreach ( $arg in $args){
        switch -Regex ($arg){
        '^(vs2015|vs2013)$'{ 
            $vscomntools_name=$BUILD_INFO."env_$arg"
            args_not_null_empty_undefined vscomntools_name
            $vscomntools_value=(ls env:$vscomntools_name -ErrorAction SilentlyContinue).value
            $vc_root=(Get-Item $([io.path]::Combine($vscomntools_value,'..','..','VC')) -ErrorAction SilentlyContinue).FullName
            $cl_exe="$([io.path]::Combine($vc_root,'bin','cl.exe'))"
            
            if($vscomntools_value -and (Test-Path "$([io.path]::Combine($vc_root,'bin','cl.exe'))" -PathType Leaf)){
                $BUILD_INFO.msvc_root=$vc_root
                $BUILD_INFO.cmake_vars_define="-G ""NMake Makefiles"" -DCMAKE_BUILD_TYPE:STRING=RELEASE"   
                $BUILD_INFO.make_exe="nmake"  
                return $arg
            }
        }
        '^gcc$'{ 
            $gcc_exe='gcc.exe'
            if($BUILD_INFO.gcc_location){
                $gcc_exe=Join-Path $BUILD_INFO.gcc_location -ChildPath $gcc_exe
            }else{
                $gcc_exe=where_first $gcc_exe
                if(!$gcc_exe){continue}
            }            
            if(Test-Path $gcc_exe -PathType Leaf){
                $BUILD_INFO.gcc_version=cmd /c "$gcc_exe -dumpversion 2>&1" 
                exit_on_error 
                $BUILD_INFO.gcc_location= (Get-Item $gcc_exe).Directory
                $BUILD_INFO.gcc_c_compiler=$gcc_exe
                $BUILD_INFO.gcc_cxx_compiler=Join-Path $BUILD_INFO.gcc_location -ChildPath 'g++.exe'
                $BUILD_INFO.cmake_vars_define="-G ""MinGW Makefiles"" -DCMAKE_C_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_c_compiler)"" -DCMAKE_CXX_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_cxx_compiler)"" -DCMAKE_BUILD_TYPE:STRING=RELEASE"
                #$BUILD_INFO.make_exe=(ls $BUILD_INFO.gcc_location -Filter *make*.exe).Name
                $find=(ls $BUILD_INFO.gcc_location -Filter *make.exe).BaseName
                if(!$find.Count){
                    throw "����ʲô��?û���ҵ�make���߰�(not found make tools)"
                }elseif($find.Count -eq 1){
                    $BUILD_INFO.make_exe=$find
                }else{
                    $BUILD_INFO.make_exe=$find[0]
                }                
                args_not_null_empty_undefined MAKE_JOBS
                $BUILD_INFO.make_exe_option="-j $MAKE_JOBS"
                if(!((Get-Item $gcc_exe).FullName -eq "$(where_first gcc)")){
                    # $BUILD_INFO.gcc_location ��������·��
                    $env:path="$($BUILD_INFO.gcc_location);$env:path"
                }
                return $arg
            }            
        }
        Default { Write-Host "invalid compiler type:$arg" -ForegroundColor Red;call_stack;exit -1}
        }
    }
    Write-Host "(û���ҵ�ָ�����κ�һ�ֱ���������ȷ����װ��ô?)not found compiler:$args" -ForegroundColor Yellow
    exit -1
}
# ��ʼ�� $BUILD_INFO ����������ö���
function init_build_info(){
    Write-Host "��ʼ���������..."  -ForegroundColor Yellow
    if($BUILD_INFO.gcc_location ){        
        $BUILD_INFO.compiler='gcc'
    }
    if($BUILD_INFO.compiler -eq 'auto'){
        $BUILD_INFO.compiler=detect_compiler  vs2013 vs2015 gcc
    }else{
        $BUILD_INFO.compiler=detect_compiler  $BUILD_INFO.compiler
    }
    if($BUILD_INFO.arch -eq 'auto'){
        args_not_null_empty_undefined HOST_PROCESSOR
        $BUILD_INFO.arch=$HOST_PROCESSOR
    }
    make_msvc_env
}
# ���� vcvarsall.bat ����msvc���뻷��
# ��������ѡ�� gcc ����ִ�иú���
# ͨ�� $MSVC_ENV_MAKED ������֤ �ú���ֻ�ᱻ����һ��
function make_msvc_env(){
    args_not_null_empty_undefined BUILD_INFO
    if(!$script:MSVC_ENV_MAKED -and $BUILD_INFO.compiler -match 'vs(\d+)'){
        # visual studio �汾(2013|2015)
        $vnum=$Matches[1]
        $cmd="""$(Join-Path $($BUILD_INFO.msvc_root) -ChildPath vcvarsall.bat)"""
        if($BUILD_INFO.arch -eq 'x86'){
            $cmd+=' x86'
        }else{
            $cmd+=' x86_amd64'
        }        
        cmd /c "$cmd &set" |
        foreach {
          if ($_ -match "=") {
            $v = $_.split("=")
            Set-Item -Force -Path "env:$($v[0])"  -Value "$($v[1])"
          }
        }
        write-host "Visual Studio $vnum Command Prompt variables set." -ForegroundColor Yellow        
        $script:MSVC_ENV_MAKED=$true
    }
}

# �����е������ַ���ȥ�����з���ϳ�һ��
# ���з� ����Ϊ '^' '\' ��β
function combine_multi_line([string]$cmd){
    args_not_null_empty_undefined cmd
    $cmd -replace '\s*[\^\\]?\s*\r\n\s*',' ' 
}
# ��̬���� gflags Դ��
function build_gflags(){
    $project=$GFLAGS_INFO
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    remove_if_exist CMakeCache.txt
    remove_if_exist CMakeFiles
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) . $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=""$($project.install_path())"" 
        -DBUILD_SHARED_LIBS=off         
	    -DBUILD_STATIC_LIBS=on 
	    -DBUILD_gflags_LIB=on 
        -DREGISTER_INSTALL_PREFIX=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$project.install_path()"
    cmd /c "$($BUILD_INFO.make_exe) clean 2>&1"
    exit_on_error
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
}
# ��̬���� glog Դ��
function build_glog(){
    $project=$GLOG_INFO
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    remove_if_exist CMakeCache.txt
    remove_if_exist CMakeFiles
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) . $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=$($project.install_path()) 
        -Dgflags_DIR=$gflags_DIR 
	    -DBUILD_SHARED_LIBS=off 2>&1"
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$project.install_path()"
    cmd /c "$($BUILD_INFO.make_exe) clean 2>&1"
    exit_on_error
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
}
# cmake��̬���� bzip2 1.0.5Դ��
function build_bzip2(){
    $project=$BZIP2_INFO
    $install_path=$project.install_path()
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=""$install_path""
        -DBUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
# ��̬���� boost Դ��
function build_boost(){
    $project=$BOOST_INFO
    $install_path=$project.install_path()
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    #exit_if_not_exist $BZIP2_INSTALL_PATH "not found $BZIP2_INSTALL_PATH,please build $BZIP2_PREFIX"
    # ָ��������bzip2��λ��,����iostreams��ʱ��Ҫ
    #export LIBRARY_PATH=$BZIP2_INSTALL_PATH/lib:$LIBRARY_PATH
    #export CPLUS_INCLUDE_PATH=$BZIP2_INSTALL_PATH/include:$CPLUS_INCLUDE_PATH

    # user-config.jam λ��boost ��Ŀ¼��
    $pwd=$(cmd /c cd)
    $jam=Join-Path $pwd -ChildPath user-config.jam
    if($BUILD_INFO.compiler -eq 'gcc'){
        # ʹ�� gcc ������ʱ�� user-config.jam ָ��������·��
        # Out-File Ĭ�����ɵ��ļ���bomͷ���������� user-config.jam ʱҪָ�� ASCII ����(��bom)����������ʱ��ȡ�ļ�����syntax error at EOF
        $env:BOOST_BUILD_PATH=$pwd
        echo "using gcc : $($BUILD_INFO.gcc_version) : $($BUILD_INFO.gcc_cxx_compiler.Replace('\','/') ) ;" | Out-File "$jam" -Encoding ASCII -Force
        cat "$jam"
        $toolset='toolset=gcc'
    }else{
        $env:BOOST_BUILD_PATH=''
        remove_if_exist "$jam"
        $toolset='toolset=msvc'
    }
    # ���п��б�
    # atomic chrono container context coroutine date_time exception filesystem 
    # graph graph_parallel iostreams locale log math mpi program_options python 
    # random regex serialization signals system test thread timer wave
    # --without-librariesָ��������Ŀ�
    #./bootstrap.sh --without-libraries=python,mpi,graph,graph_parallel,wave
    # --with-librariesָ������Ŀ�
    Write-Host "runing bootstrap..." -ForegroundColor Yellow
    cmd /c "bootstrap"
    exit_on_error
    Write-Host "b2 clean..." -ForegroundColor Yellow
    cmd /c "b2 --clean 2>&1"
    exit_on_error
    remove_if_exist "$install_path"    
    # --prefix ָ����װλ��
    # --debug-configuration ����ʱ��ʾ���ص�������Ϣ
    # -q ����ָʾ�����ֹͣ����
    # link=static ֻ���뾲̬��
    # --with-<library> ���밲װָ���Ŀ�<library>
    # -a ȫ�����±���
    Write-Host "boost compiling..." -ForegroundColor Yellow
    $cmd=combine_multi_line "b2 --prefix=$install_path -a -q -d+3 --debug-configuration $toolset link=static  install 
        --with-system
        --with-thread
        --with-filesystem
        --with-regex 2>&1"
    cmd /c $cmd 
    exit_on_error
    popd
}
# ��̬���� protobuf Դ��
function build_protobuf(){
    $project=$PROTOBUF_INFO
    $install_path=$project.install_path()
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    if($BUILD_INFO.compiler -eq 'gcc'){
        $cmake_exe_linker_flags='-DCMAKE_EXE_LINKER_FLAGS="-static -static-libstdc++ -static-libgcc"'
    }
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) ../cmake $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
    	    -Dprotobuf_BUILD_TESTS=off 
			-Dprotobuf_BUILD_SHARED_LIBS=off
			$cmake_exe_linker_flags 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
# ��̬���� hdf5 Դ��
function build_hdf5(){
    $project=$HDF5_INFO
    $install_path=$project.install_path()
    pushd $([io.path]::Combine($SOURCE_ROOT,$project.folder,$project.folder))
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
        -DBUILD_SHARED_LIBS=off 
		-DBUILD_TESTING=off 
		-DHDF5_BUILD_FORTRAN=off 
		-DHDF5_BUILD_EXAMPLES=off 
		-DHDF5_BUILD_TOOLS=off 
		-DHDF5_DISABLE_COMPILER_WARNINGS=on 
		-DSKIP_HDF5_FORTRAN_SHARED=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
# ��̬���� snappy Դ��
function build_snappy(){
    $project=$SNAPPY_INFO
    $install_path=$project.install_path()
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"

    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
        -DGflags_DIR=$gflags_DIR 
        -DBUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
# ��̬���� opencv Դ��
function build_opencv(){
    $project=$BZIP2_INFO
    $install_path=$project.install_path()
    # ��������� FFMPEG ����Ҫ bzip2
    #bzip2_libraries=$BZIP2_INSTALL_PATH/lib/libbz2.a
    #exit_if_not_exist $bzip2_libraries "not found $bzip2_libraries,please build $BZIP2_PREFIX"

    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    # ��������� FFMPEG , cmakeʱ����Ҫָ�� BZIP2_LIBRARIES
	#	-DBZIP2_LIBRARIES=$BZIP2_INSTALL_PATH/lib/libbz2.a 
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
			-DBUILD_DOCS=off 
			-DBUILD_SHARED_LIBS=off 
			-DBUILD_PACKAGE=on 
			-DBUILD_PERF_TESTS=off 
			-DBUILD_FAT_JAVA_LIB=off 
			-DBUILD_TESTS=off 
			-DBUILD_TIFF=on 
			-DBUILD_JASPER=on 
			-DBUILD_JPEG=on 
			-DBUILD_OPENEXR=on 
			-DBUILD_PNG=on 
			-DBUILD_ZLIB=on 
			-DBUILD_opencv_apps=off 
			-DBUILD_opencv_calib3d=off 
			-DBUILD_opencv_contrib=off 
			-DBUILD_opencv_features2d=off 
			-DBUILD_opencv_flann=off 
			-DBUILD_opencv_gpu=off 
			-DBUILD_opencv_java=off 
			-DBUILD_opencv_legacy=off 
			-DBUILD_opencv_ml=off 
			-DBUILD_opencv_nonfree=off 
			-DBUILD_opencv_objdetect=off 
			-DBUILD_opencv_ocl=off 
			-DBUILD_opencv_photo=off 
			-DBUILD_opencv_python=off 
			-DBUILD_opencv_stitching=off 
			-DBUILD_opencv_superres=off 
			-DBUILD_opencv_ts=off 
			-DBUILD_opencv_video=off 
			-DBUILD_opencv_videostab=off 
			-DBUILD_opencv_world=off 
			-DBUILD_opencv_lengcy=off 
			-DWITH_JASPER=on 
			-DWITH_JPEG=on 
			-DWITH_1394=off 
			-DWITH_OPENEXR=on 
			-DWITH_PNG=on 
			-DWITH_TIFF=on 
			-DWITH_1394=off 
			-DWITH_EIGEN=off 
			-DWITH_FFMPEG=off 
			-DWITH_GIGEAPI=off 
			-DWITH_GSTREAMER=off 
			-DWITH_GTK=off 
			-DWITH_PVAPI=off 
			-DWITH_V4L=off 
			-DWITH_LIBV4L=off 
			-DWITH_CUDA=off 
			-DWITH_CUFFT=off 
			-DWITH_OPENCL=off 
			-DWITH_OPENCLAMDBLAS=off 
			-DWITH_OPENCLAMDFFT=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
init_build_info
$BUILD_INFO

#build_gflags
#build_glog
#build_bzip2
#build_boost
#build_protobuf
#build_hdf5
build_snappy