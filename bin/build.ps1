param(
[string[]]$names=$all_names ,
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[string]$gcc=$DEFAULT_GCC,
[switch]$revert,
[switch]$help
)
# 用命令行输入的参数初始化 $BUILD_INFO 变量 [PSObject]
$BUILD_INFO=New-Object PSObject -Property @{
    # 编译器类型 vs2013|vs2015|gcc
    compiler=$compiler
    # cpu体系 x86|x86_64
    arch=$arch
    # vs2015 环境变量
    env_vs2015='VS140COMNTOOLS'
    # vs2013 环境变量
    env_vs2013='VS120COMNTOOLS'
    # msvc安装路径 如:"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC"
    msvc_root=""
    # gcc安装路径 如:P:\MinGW\mingw64\bin
    gcc_location=$gcc
    # gcc版本号
    gcc_version=""
    # gcc 编译器全路径 如 P:\MinGW\mingw64\bin\gcc.exe
    gcc_c_compiler=""
    # g++ 编译器全路径 如 P:\MinGW\mingw64\bin\g++.exe
    gcc_cxx_compiler=""
    # cmake 参数定义
    cmake_vars_define=""
    # c编译器通用选项 (CMAKE_C_FLAGS)  参见 https://cmake.org/cmake/help/v3.8/variable/CMAKE_LANG_FLAGS.html
    c_flags=""
    # c++编译器通用选项 (CMAKE_CXX_FLAGS),同上
    cxx_flags=""
    # 可执行程序(exe)连接选项(CMAKE_EXE_LINKER_FLAGS) 参见 https://cmake.org/cmake/help/v3.8/variable/CMAKE_EXE_LINKER_FLAGS.html
    exe_linker_flags=""
    # make 工具文件名,msvc为nmake,mingw为make 
    make_exe=""
    # make 工具编译时的默认选项
    make_exe_option=""
}
# 生成调用 cmake 时的默认命令行参数
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name make_cmake_vars_define -Value {
        param([string]$c_flags,[string]$cxx_flags,[string]$exe_linker_flags)
        $vars=$this.cmake_vars_define
        if($this.c_flags -or $c_flags){
            $vars+=" -DCMAKE_C_FLAGS=""$($this.c_flags) $c_flags"""
        }
        if($this.cxx_flags -or $cxx_flags){
            $vars+=" -DCMAKE_CXX_FLAGS=""$($this.cxx_flags) $cxx_flags"""
        }
        if($this.exe_linker_flags -or $exe_linker_flags){
            $vars+=" -DCMAKE_EXE_LINKER_FLAGS=""$($this.exe_linker_flags) $exe_linker_flags"""
        }
        $vars
    }
# 判断编译器是不是 msvc
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name is_msvc -Value {
    $this.compiler -match 'vs\d+'
}
# 判断编译器是不是 msvc
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name is_gcc -Value {
    $this.compiler -eq 'gcc'
}
    
. "$PSScriptRoot/build_vars.ps1"
# 调用 where 在搜索路径中查找 $who 指定的可执行文件,
# 如果找到则返回第一个结果
# 如果没找到返回空 
function where_first($who){
    args_not_null_empty_undefined who    
    cmd /c "where $who >nul 2>nul"
    if($?){
        $w=$(cmd /c "where $who")
        if($w.Count -gt 1){$w[0]}else{$w}
    }
}

# 测试 gcc 编译器($gcc_compiler)是否能生成$arch指定的代码(32/64位)
# 如果不能，则报错退出
function test_gcc_compiler_capacity([string]$gcc_compiler,[ValidateSet('x86','x86_64')][string]$arch){
    args_not_null_empty_undefined arch gcc_compiler
    # 检查是否为 gcc 编译器
    cmd /c "$gcc_compiler -dumpversion >nul 2>nul"
    exit_on_error "$gcc_compiler is not gcc compiler"
    if($arch -eq 'x86'){
        $c_flags='-m32'
    }elseif($arch -eq 'x86_64'){
        $c_flags='-m64'
    }
    $test=Join-Path $env:TEMP -ChildPath 'test-m32-m64-enable'
    # 在系统 temp 文件夹下生成一个临时 .c 文件
    echo "int main(){return 0;}`n" |Out-File "$test.c" -Encoding ascii -Force
    # 调用指定的编译器在命令行编译 .c 文件
    cmd /c "$gcc_compiler $test.c $c_flags -o $test >nul 2>nul"    
    exit_on_error "指定的编译器不能生成 $arch 代码($gcc_compiler can't build $arch code)"
    # 清除临时文件
    del "$test*" -Force
}
# 根据提供的编译器类型列表，按顺序在系统中侦测安装的编译器，
# 如果找到就返回找到的编译类型名,
# 如果没有找到任何一种编译器则报错退出
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
                if(!$gcc_exe){
                    # 如果系统中没有检测到 gcc 编译器则使用自带的 mingw 编译器
                    $mingw=$(if($BUILD_INFO.arch -eq 'x86'){$MINGW32_INFO}else{$MINGW64_INFO})                    
                    if(!(Test-Path $mingw.root -PathType Container)){
                        continue
                    }
                    $gcc_exe=Join-Path $mingw.root -ChildPath $gcc_exe
                }
            }  
            if(Test-Path $gcc_exe -PathType Leaf){
                $BUILD_INFO.gcc_version=cmd /c "$gcc_exe -dumpversion 2>&1" 
                exit_on_error 
                $BUILD_INFO.gcc_location= (Get-Item $gcc_exe).Directory
                $BUILD_INFO.gcc_c_compiler=$gcc_exe
                $BUILD_INFO.gcc_cxx_compiler=Join-Path $BUILD_INFO.gcc_location -ChildPath 'g++.exe'
                $BUILD_INFO.cmake_vars_define="-G ""MinGW Makefiles"" -DCMAKE_C_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_c_compiler)"" -DCMAKE_CXX_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_cxx_compiler)"" -DCMAKE_BUILD_TYPE:STRING=RELEASE"
                $BUILD_INFO.exe_linker_flags='-static -static-libstdc++ -static-libgcc'
                # 寻找 mingw32 中的 make.exe，一般名为 mingw32-make
                $find=(ls $BUILD_INFO.gcc_location -Filter *make.exe).BaseName
                if(!$find.Count){
                    throw "这是什么鬼?没有找到make工具啊(not found make tools)"
                }elseif($find.Count -eq 1){
                    $BUILD_INFO.make_exe=$find
                }else{
                    $BUILD_INFO.make_exe=$find[0]
                }                
                args_not_null_empty_undefined MAKE_JOBS
                $BUILD_INFO.make_exe_option="-j $MAKE_JOBS"
                if(!((Get-Item $gcc_exe).FullName -eq "$(where_first gcc)")){
                    # $BUILD_INFO.gcc_location 加入搜索路径
                    $env:path="$($BUILD_INFO.gcc_location);$env:path"
                }
                return $arg
            }            
        }
        Default { Write-Host "invalid compiler type:$arg" -ForegroundColor Red;call_stack;exit -1}
        }
    }
    Write-Host "(没有找到指定的任何一种编译器，你确定安装了么?)not found compiler:$args" -ForegroundColor Yellow
    exit -1
}
# 初始化 $BUILD_INFO 编译参数配置对象
function init_build_info(){
    Write-Host "初始化编译参数..."  -ForegroundColor Yellow
    # $BUILD_INFO.arch 为 auto时，设置为系统检查到的值
    if($BUILD_INFO.arch -eq 'auto'){
        args_not_null_empty_undefined HOST_PROCESSOR
        $BUILD_INFO.arch=$HOST_PROCESSOR
    }
    if($BUILD_INFO.gcc_location ){        
        $BUILD_INFO.compiler='gcc'
    }
    if($BUILD_INFO.compiler -eq 'auto'){
        $BUILD_INFO.compiler=detect_compiler  vs2013 vs2015 gcc
    }else{
        $BUILD_INFO.compiler=detect_compiler  $BUILD_INFO.compiler
    }

    if($BUILD_INFO.is_gcc()){
        if($BUILD_INFO.arch -eq 'x86'){
            $BUILD_INFO.c_flags=$BUILD_INFO.cxx_flags='-m32'
        }elseif($BUILD_INFO.arch -eq 'x86_64'){
            $BUILD_INFO.c_flags=$BUILD_INFO.cxx_flags='-m64'
        }
        test_gcc_compiler_capacity -gcc_compiler $BUILD_INFO.gcc_c_compiler -arch $BUILD_INFO.arch
    }    
    make_msvc_env
}
# 调用 vcvarsall.bat 创建msvc编译环境
# 当编译器选择 gcc 不会执行该函数
# 通过 $env:MSVC_ENV_MAKED 变量保证 该函数只会被调用一次
function make_msvc_env(){
    args_not_null_empty_undefined BUILD_INFO
    if( $env:MSVC_ENV_MAKED -ne $BUILD_INFO.arch -and $BUILD_INFO.is_msvc()){
        # visual studio 版本(2013|2015)
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
        $env:MSVC_ENV_MAKED=$BUILD_INFO.arch
        write-host "Visual Studio $vnum Command Prompt variables ($env:MSVC_ENV_MAKED) set." -ForegroundColor Yellow
    }
}

# 将分行的命令字符串去掉分行符组合成一行
# 分行符 可以为 '^' '\' 结尾
# 删除 #开头的注释行
function combine_multi_line([string]$cmd){
    args_not_null_empty_undefined cmd    
    ($cmd -replace '\s*#.*\n',''  ) -replace '\s*[\^\\]?\s*\r\n\s*',' ' 
}
# 静态编译 gflags 源码
function build_gflags(){
    $project=$GFLAGS_INFO
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    remove_if_exist CMakeCache.txt
    remove_if_exist CMakeFiles
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) . $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$($project.install_path())"" 
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
# 静态编译 glog 源码
function build_glog(){
    $project=$GLOG_INFO
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    remove_if_exist CMakeCache.txt
    remove_if_exist CMakeFiles
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) . $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=$($project.install_path()) 
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
# cmake静态编译 bzip2 1.0.5源码
function build_bzip2(){
    $project=$BZIP2_INFO
    $install_path=$project.install_path()
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $c_flags='/wd4996 /wd4267'
    }
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define($c_flags)) -DCMAKE_INSTALL_PREFIX=""$install_path""
        -DCMAKE_POLICY_DEFAULT_CMP0026=OLD
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
# 静态编译 boost 源码
function build_boost(){
    $project=$BOOST_INFO
    $install_path=$project.install_path()
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    #exit_if_not_exist $BZIP2_INSTALL_PATH "not found $BZIP2_INSTALL_PATH,please build $BZIP2_PREFIX"
    # 指定依赖库bzip2的位置,编译iostreams库时需要
    #export LIBRARY_PATH=$BZIP2_INSTALL_PATH/lib:$LIBRARY_PATH
    #export CPLUS_INCLUDE_PATH=$BZIP2_INSTALL_PATH/include:$CPLUS_INCLUDE_PATH

    # user-config.jam 位于boost 根目录下
    $pwd=$(cmd /c cd)
    $jam=Join-Path $pwd -ChildPath user-config.jam
    if($BUILD_INFO.is_gcc()){
        # 使用 gcc 编译器时用 user-config.jam 指定编译器路径
        # Out-File 默认生成的文件有bom头，所以生成 user-config.jam 时要指定 ASCII 编码(无bom)，否则会编译时读取文件报错：syntax error at EOF
        $env:BOOST_BUILD_PATH=$pwd
        echo "using gcc : $($BUILD_INFO.gcc_version) : $($BUILD_INFO.gcc_cxx_compiler.Replace('\','/') ) ;" | Out-File "$jam" -Encoding ASCII -Force
        cat "$jam"
        $toolset='toolset=gcc'
    }else{
        $env:BOOST_BUILD_PATH=''
        remove_if_exist "$jam"
        $toolset='toolset=msvc'
    }
    # 所有库列表
    # atomic chrono container context coroutine date_time exception filesystem 
    # graph graph_parallel iostreams locale log math mpi program_options python 
    # random regex serialization signals system test thread timer wave
    # --without-libraries指定不编译的库
    #./bootstrap.sh --without-libraries=python,mpi,graph,graph_parallel,wave
    # --with-libraries指定编译的库
    Write-Host "runing bootstrap..." -ForegroundColor Yellow
    cmd /c "bootstrap"
    exit_on_error
    Write-Host "b2 clean..." -ForegroundColor Yellow
    cmd /c "b2 --clean 2>&1"
    exit_on_error
    remove_if_exist "$install_path"    
    if($BUILD_INFO.arch -eq 'x86_64'){
        $address_model='address-model=64'
    }
    if($BUILD_INFO.compiler -eq 'vs2013'){
        $toolset='--toolset=msvc-12.0'
    }elseif($BUILD_INFO.compiler -eq 'vs2015'){
        $toolset='--toolset=msvc-14.0'
    }
    # --prefix 指定安装位置
    # --debug-configuration 编译时显示加载的配置信息
    # -q 参数指示出错就停止编译
    # link=static 只编译静态库
    # --with-<library> 编译安装指定的库<library>
    # -a 全部重新编译
    Write-Host "boost compiling..." -ForegroundColor Yellow
    $cmd=combine_multi_line "b2 --prefix=$install_path $address_model $toolset -a -q -d+3 --debug-configuration $toolset link=static  install 
        --with-date_time
        --with-system
        --with-thread
        --with-filesystem
        --with-regex 2>&1"
    cmd /c $cmd 
    exit_on_error
    popd
}
# 静态编译 protobuf 源码
function build_protobuf(){
    $project=$PROTOBUF_INFO
    $install_path=$project.install_path()
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) ../cmake $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
    	    -Dprotobuf_BUILD_TESTS=off 
			-Dprotobuf_BUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
# 静态编译 hdf5 源码
function build_hdf5(){
    $project=$HDF5_INFO
    $install_path=$project.install_path()
    pushd $([io.path]::Combine($SOURCE_ROOT,$project.folder,$project.folder))
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
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
# 静态编译 snappy 源码
function build_snappy(){
    $project=$SNAPPY_INFO
    $install_path=$project.install_path()
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
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
# 静态编译 opencv 源码
function build_opencv(){
    $project=$OPENCV_INFO
    $install_path=$project.install_path()
    # 如果不编译 FFMPEG 不需要 bzip2
    #bzip2_libraries=$BZIP2_INSTALL_PATH/lib/libbz2.a
    #exit_if_not_exist $bzip2_libraries "not found $bzip2_libraries,please build $BZIP2_PREFIX"

    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    if($BUILD_INFO.is_msvc()){
        $build_with_static_crt='-DBUILD_WITH_STATIC_CRT=on'
    }elseif($BUILD_INFO.is_gcc()){
        $build_fat_java_lib='-DBUILD_FAT_JAVA_LIB=off'
    }
    # 如果不编译 FFMPEG , cmake时不需要指定 BZIP2_LIBRARIES
	#	-DBZIP2_LIBRARIES=$BZIP2_INSTALL_PATH/lib/libbz2.a 
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
            $build_with_static_crt
            $build_fat_java_lib
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
            -DWITH_DSHOW=off
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
			-DWITH_GSTREAMER_0_10=off 
			-DWITH_PVAPI=off 
			-DWITH_CUDA=off 
			-DWITH_CUFFT=off 
			-DWITH_OPENCL=off 
			-DWITH_OPENCLAMDBLAS=off 
			-DWITH_OPENCLAMDFFT=off 
            -DWITH_QT=off
            -DWITH_VFW=off
            -DWITH_VTK=off
            -DWITH_XIMEA=off
            -DWITH_WIN32UI=off 
            2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
    rm  build.gcc -Force -Recurse
    popd
}
# cmake静态编译 leveldb(bureau14)源码
function build_leveldb(){
    $project=$LEVELDB_INFO
    $install_path=$project.install_path()
    $boost_root=$BOOST_INFO.install_path()
    exit_if_not_exist "$boost_root"  -type Container -msg "not found $boost_root,please build $($BOOST_INFO.prefix)"

    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path""
        -DBOOST_ROOT=$boost_root
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
# 静态编译 OpenBLAS 源码,在 MSYS2 中编译，需要 msys2 支持
function build_openblas(){
    $project=$OPENBLAS_INFO
    # 检查是否有安装 msys2 如果没有安装则退出
    if( ! $MSYS2_INSTALL_LOCATION ){
        throw "没有安装MSYS2,不能编译OpenBLAS,MSYS2 not installed,please install,run : ./fetch.ps1 msys2"
    }
    $BINARY=$(if($BUILD_INFO.arch -eq 'x86'){32}else{64})    
    $mingw_make="mingw32-make"
    if($BUILD_INFO.is_gcc()){
        $mingw_bin=$BUILD_INFO.gcc_location
        $mingw_make=$BUILD_INFO.make_exe
        $mingw_version=$BUILD_INFO.gcc_version
    }elseif($BUILD_INFO.arch -eq 'x86'){
        $mingw_bin= Join-Path $MINGW32_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(没有安装 mingw32 编译器),mingw32 not installed,run ./fetch.ps1 mingw32 to install it "
        $mingw_version=$MINGW32_INFO.version
    }else{
        $mingw_bin= Join-Path $MINGW64_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(没有安装 mingw64 编译器),mingw64 not installed,run ./fetch.ps1 mingw64 to install it "
        $mingw_version=$MINGW64_INFO.version
    }    
    $src_root=Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder
    $msys2bash=[io.path]::Combine($MSYS2_INSTALL_LOCATION,'usr','bin','bash')
    # 不用 msys2_shell.cmd 执行脚本是因为返回的exit code总是0，无法判断脚本是否正确执行
    #$msys2bash=[io.path]::Combine($MSYS2_INSTALL_LOCATION,'msys2_shell.cmd')
    $install_path=unix_path($project.install_path())
    args_not_null_empty_undefined MAKE_JOBS
    remove_if_exist "$install_path"
    # MSYS2 下的gcc 编译脚本 (bash)
    # 任何一步出错即退出脚本 exit code = -1
    # 每一行必须 ; 号结尾(最后一行除外)
    # #号开头注释行会被 combine_multi_line 函数删除，不会出现在运行脚本中
    $bashcmd="export PATH=$(unix_path($mingw_bin)):`$PATH ;
        # 切换到 OpenBLAS 源码文件夹 
        cd $(unix_path $src_root) ; 
        # 先执行make clean
        echo start make clean,please waiting...;
        $mingw_make clean ;
        if [ ! `$? ];then exit -1;fi; 
        # BINARY用于指定编译32位还是64位代码 -j 选项用于指定多线程编译
        $mingw_make -j $MAKE_JOBS BINARY=$BINARY NOFORTRAN=1 NO_LAPACKE=1 NO_SHARED=1 ; 
        if [ ! `$? ];then exit -1;fi;
        # 安装到 $install_path 指定的位置
        $mingw_make install PREFIX=$install_path NO_LAPACKE=1 NO_SHARED=1"
    $cmd=combine_multi_line "$msys2bash -l -c `"$bashcmd`" 2>&1"
    #$cmd="$msys2bash -where $src_root -l -c `"$bashcmd`" 2>&1"
    Write-Host "(OpenBLAS 编译中...)compiling OpenBLAS by MinGW $mingw_version ($mingw_bin)" -ForegroundColor Yellow
    cmd /c $cmd
    exit_on_error
}
# cmake静态编译 lmdb 源码
function build_lmdb(){
    $project=$LMDB_INFO
    $install_path=$project.install_path()
    pushd ([io.path]::Combine($SOURCE_ROOT,$project.folder,'libraries','liblmdb'))
    clean_folder build.gcc
    pushd build.gcc
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path""  
        -DCLOSE_WARNING=on
        -DBUILD_TEST=off
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
# 输出帮助信息
function print_help(){
    if($(chcp ) -match '\.*936$'){
	    echo "用法: $my_name [-names] [项目名称列表,...] [可选项...] 
编译安装指定的项目,如果没有指定项目名称，则编译所有项目
    -n,-names       项目名称列表(逗号分隔,忽略大小写)
                    可选的项目名称: $all_names 
选项:
	-c,-compiler    指定编译器类型,可选值: vs2013,vs2015,gcc,默认 auto(自动侦测)
                    指定为gcc时,如果没有检测到MinGW编译器,则使用本系统自带的MinGW编译器
    -a,-arch        指定目标代码类型(x86,x86_64),默认auto(自动侦测)
    -g,-gcc         指定MingGW编译器的安装路径(bin文件夹),指定此值后，编译器类型(-compiler)自动设置为gcc
    -r,-revert      对项目强制执行fetch,将项目代码恢复到初始状态 
	-h,-help        显示帮助信息
作者: guyadong@gdface.net
"
    }else{
        echo "usage: $my_name [-names] [PROJECT_NAME,...] [options...] 
build & install projects specified by project name,
all projects builded if no name argument
    -n,-names       prject names(split by comma,ignore case)
                    optional project names: $all_names 

options:
	-c,-compiler    compiler type,valid value:'vs2013','vs2015','gcc',default 'auto' 
    -a,-arch        target processor architecture: 'x86','x86_64',default 'auto'
    -g,-gcc         MinGW compiler location('bin' folder,such as 'P:\MinGW\mingw64\bin'),
                    the '-compiler' option will be overwrited  to 'gcc' if this option defined 
    -r,-revert      force fetch the project,revert source code
	-h,-help        print the message
author: guyadong@gdface.net
"
    }
}
# 所有项目列表字符串数组
$all_names="gflags glog bzip2 boost leveldb lmdb snappy openblas hdf5 opencv protobuf ssd".Trim() -split '\s+'
# 当前脚本名称
$my_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
if($help){
    print_help  
    exit 0
}
# 多线程编译参数 make -j 
$MAKE_JOBS=get_logic_core_count
init_build_info
Write-Host 操作系统:$HOST_OS,$HOST_PROCESSOR -ForegroundColor Yellow
Write-Host 编译器配置: -ForegroundColor Yellow
$BUILD_INFO
#build_gflags
#build_glog
#build_bzip2
#build_boost
#build_protobuf
#build_hdf5
#build_snappy
#build_opencv
#build_leveldb_bureau14
#build_openblas
#build_lmdb

echo $names| foreach {    
    if( ! (Test-Path function:"build_$($_.ToLower())") ){
        echo "(不识别的项目名称)unknow project name:$_"
        print_help
        exit -1
    }
}
$fetch_names=@()
if($revert){
    $fetch_names=$names
}else{
    echo $names| foreach {
        # 如果源码文件夹不存在,则需要fetch该项目   
        $info=Get-Variable "$($_.ToLower())_INFO" -ValueOnly
        if(  ! (Test-Path (Join-Path $SOURCE_ROOT -ChildPath $info.folder) -PathType Container)){
            $fetch_names+=$_
        }
    }
}
if($fetch_names.Count){
    if($revert){
        &$PSScriptRoot/fetch.ps1 $fetch_names -force
    }else{
        &$PSScriptRoot/fetch.ps1 $fetch_names
    }    
}
# 顺序编译 $names 中指定的项目
echo $names| foreach {  
    &build_$($_.ToLower())      
}