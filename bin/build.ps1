param(
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[string]$gcc=$DEFAULT_GCC,
[switch]$help
)
. "./build_vars.ps1"
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
                if(!$gcc_exe){continue}
            }            
            if(Test-Path $gcc_exe -PathType Leaf){
                $BUILD_INFO.gcc_version=cmd /c "$gcc_exe -dumpversion 2>&1" 
                exit_on_error 
                $BUILD_INFO.gcc_location= (Get-Item $gcc_exe).Directory
                $BUILD_INFO.gcc_c_compiler=$gcc_exe
                $BUILD_INFO.gcc_cxx_compiler=Join-Path $BUILD_INFO.gcc_location -ChildPath 'g++.exe'
                $BUILD_INFO.cmake_vars_define="-G ""MinGW Makefiles"" -DCMAKE_C_COMPILER:FILEPATH=$($BUILD_INFO.gcc_c_compiler) -DCMAKE_CXX_COMPILER:FILEPATH=$($BUILD_INFO.gcc_cxx_compiler) -DCMAKE_BUILD_TYPE:STRING=RELEASE"
                #$BUILD_INFO.make_exe=(ls $BUILD_INFO.gcc_location -Filter *make*.exe).Name
                $BUILD_INFO.make_exe='make'
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
# 调用 vcvarsall.bat 创建msvc编译环境
# 当编译器选择 gcc 不会执行该函数
# 通过 $MSVC_ENV_MAKED 变量保证 该函数只会被调用一次
function make_msvc_env(){
    args_not_null_empty_undefined BUILD_INFO
    if(!$script:MSVC_ENV_MAKED -and $BUILD_INFO.compiler -match 'vs(\d+)'){
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
        write-host "Visual Studio $vnum Command Prompt variables set." -ForegroundColor Yellow        
        $script:MSVC_ENV_MAKED=$true
    }
}
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
    # make 工具文件名,msvc为nmake,mingw为make 
    make_exe=""
    # make 工具编译时的默认选项
    make_exe_option=""
}

# 静态编译 gflags 源码
function build_flags(){
    $project=$GFLAGS_INFO
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder)
    remove_if_exist CMakeCache.txt
    remove_if_exist CMakeFiles
    cmd /c "$($CMAKE_INFO.exe) . $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=$($project.install_path()) ^
	    -DBUILD_SHARED_LIBS=off ^
	    -DBUILD_STATIC_LIBS=on ^
	    -DBUILD_gflags_LIB=on ^
	    -DINSTALL_STATIC_LIBS=on ^
	    -DINSTALL_SHARED_LIBS=off ^
	    -DREGISTER_INSTALL_PREFIX=off 2>&1"
    exit_on_error
    remove_if_exist $project.install_path()
    cmd /c "$($BUILD_INFO.make_exe) clean 2>&1"
    exit_on_error
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
}

init_build_info
$BUILD_INFO

build_flags