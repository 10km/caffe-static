<#
自动编译caffe-ssd及其依赖的所有库，
如果指定项目的源码不存在,则自动调用fetch.ps1 下载源码
author: guyadong@gdface.net
#>
param(
[alias('names')]
[string[]]$build_project_names,
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[alias('custom')]
[string]$custom_caffe_folder,
[alias('prefix')]
[string]$custom_install_prefix,
[alias('skip')]
[switch]$custom_skip_patch,
[ValidateSet('nmake','jom','sln')]
[string]$msvc_project='jom',
[ValidateSet('make','eclipse')]
[string]$gcc_project='make',
[string]$gcc=$DEFAULT_GCC,
[switch]$revert,
[alias('md')]
[switch]$msvc_shared_runtime,
[switch]$openblas_no_dynamic_arch,
[switch]$openblas_no_use_thread,
[int]$openblas_num_threads=24,
[switch]$caffe_gpu,
[string]$caffe_cudnn_root,
[switch]$caffe_use_dynamic_openblas,
[switch]$debug,
[switch]$build_reserved,
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
    # Visual Studio 版本号 (2013/2015...)
    vs_version=""
    vc_version=@{ 'vs2013'='vc120' 
                  'vs2015'='vc140'}
    msvc_project=$msvc_project
    # MSVC 连接选项使用 /MD
    msvc_shared_runtime=$msvc_shared_runtime
    # gcc安装路径 如:P:\MinGW\mingw64\bin
    gcc_location=$gcc
    # gcc版本号
    gcc_version=""
    # gcc 编译器全路径 如 P:\MinGW\mingw64\bin\gcc.exe
    gcc_c_compiler=""
    # g++ 编译器全路径 如 P:\MinGW\mingw64\bin\g++.exe
    gcc_cxx_compiler=""
    gcc_project=$gcc_project
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
    # install 任务名称,使用msbuild编译msvc工程时名称为'INSTALL.vcxproj'
    make_install_target='install'
    # 编译类型
    build_type=$(if($debug){'debug'}else{'release'})
    # 项目编译成功后是否清除 build文件夹
    remove_build= ! $build_reserved
    # 环境变量快照,由成员 save_env_snapshoot 保存
    # 为保证每个 build_xxxx 函数执行时，环境变量互不干扰，
    # 在开始编译前调用 restore_env_snapshoot 将此变量中保存的所有环境变量恢复到 save_env_snapshoot 调用时的状态
    env_snapshoot=$null
}
# $BUILD_INFO 成员方法 
# 生成调用 cmake 时的默认命令行参数
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name make_cmake_vars_define -Value {
    param([string]$c_flags,[string]$cxx_flags,[string]$exe_linker_flags)
    $vars=$this.cmake_vars_define
    if($this.c_flags -or $c_flags){
        $vars+=" -DCMAKE_C_FLAGS=""$($this.c_flags) $c_flags """
    }
    if($this.cxx_flags -or $cxx_flags){
        $vars+=" -DCMAKE_CXX_FLAGS=""$($this.cxx_flags) $cxx_flags """
    }
    if($this.exe_linker_flags -or $exe_linker_flags){
        $vars+=" -DCMAKE_EXE_LINKER_FLAGS=""$($this.exe_linker_flags) $exe_linker_flags """
    }
    $vars
}
# $BUILD_INFO 成员方法 
# 判断编译器是不是 msvc
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name is_msvc -Value {
    $this.compiler -match 'vs\d+'
}
# $BUILD_INFO 成员方法 
# 判断编译器是不是 msvc
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name is_gcc -Value {
    $this.compiler -eq 'gcc'
}
# $BUILD_INFO 成员方法 
# 进入项目文件夹，如果没有指定 $no_build 清空 build 文件夹,并进入 build文件夹
# 调用者必须将 项目配置对象(如 BOOST_INFO)保存在 $project 变量中
# $no_build 不创建 build 文件夹
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name begin_build -Value {
    param([string[]]$sub_folders,[switch]$no_build,[string]$project_root)
    args_not_null_empty_undefined project
    Write-Host "(开始编译)building $($project.prefix) $($project.version)" -ForegroundColor Yellow
    if($project_root){
        exit_if_not_exist $project_root -type Container
    }else{
        [string[]]$paths=$SOURCE_ROOT,$project.folder
        $paths+=$sub_folders
        $project_root=([io.path]::Combine($paths))
    }
    pushd $project_root
    if(! $no_build){
        $build="build.$($this.compiler)"
        clean_folder $build
        pushd "$build"
    }
    $BUILD_INFO.restore_env_snapshoot()
}
# $BUILD_INFO 成员方法 
# 退出项目文件夹，清空 build 文件夹,必须与 prepare_build 配对使用
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name end_build -Value {
    $build="build.$($this.compiler)"
    if( (pwd).path.endsWith($build)){
        popd
        if($this.remove_build){
            remove_if_exist $build
        }        
    }
    popd
}
# $BUILD_INFO 成员方法 
# 保存所有当前环境变量到 env_snapshoot
# 该函数只能被调用一次
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name save_env_snapshoot -Value {
    if($this.env_snapshoot){
        call_stack
        throw "(本函数只允许被调用一次),the function can only be called once "
    }
    $this.env_snapshoot=cmd /c set
}
# $BUILD_INFO 成员方法 
# 恢复 env_snapshoot 中保存的环境变量
# 该函数只能在调用 save_env_snapshoot 后被调用
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name restore_env_snapshoot -Value {
    if(!$this.env_snapshoot){
        call_stack
        throw "(该函数只能在调用 save_env_snapshoot 后被调用),the function must be called after 'save_env_snapshoot' called  "
    }
    $this.env_snapshoot|
    foreach {
        if ($_ -match "=") {
        $v = $_.split("=")
        Set-Item -Force -Path "env:$($v[0])"  -Value "$($v[1])"
        }
    }
}
# include 公共全局变量    
. "$PSScriptRoot/build_vars.ps1"

# 调用 where 在搜索路径中查找 $who 指定的可执行文件,
# 如果找到则返回第一个结果
# 如果没找到返回空 
function where_first($who){
    args_not_null_empty_undefined who    
    (get-command $who  -ErrorAction SilentlyContinue| Select-Object Definition -First 1).Definition
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
                switch($BUILD_INFO.msvc_project){
                'nmake'{
                    $generator='NMake Makefiles'
                    $BUILD_INFO.make_exe='nmake'
                }
                'jom'{
                    exit_if_not_exist $JOM_INFO.root -type Container -msg '(没有安装 jom),not found jom,please install it by running ./fetch.ps1 jom'
                    $generator='NMake Makefiles JOM'
                    $BUILD_INFO.make_exe='jom'
                    args_not_null_empty_undefined MAKE_JOBS
                    $BUILD_INFO.make_exe_option="-j $MAKE_JOBS"
                }
                'sln'{
                    $gp_map=@{
                        vs2013='Visual Studio 12 2013'
                        vs2015='Visual Studio 14 2015'
                        vs2017='Visual Studio 15 2017'
                    }
                    $gs_map=@{
                        x86=''
                        x86_64=' Win64'
                        arm=' ARM'
                    }
                    $generator='{0}{1}' -f $gp_map.$arg,$gs_map.$($BUILD_INFO.arch)
                    $BUILD_INFO.make_exe='msbuild'
                    $BUILD_INFO.make_exe_option="/maxcpucount /t:build /p:Configuration=$($BUILD_INFO.build_type)"
                    $BUILD_INFO.make_install_target='INSTALL.vcxproj'
                }
                default{ call_stack; throw "(无效工程类型)invalid project type:$($BUILD_INFO.msvc_project)"}
                }
                if(! $BUILD_INFO.msvc_shared_runtime){
                    $cmake_user_make_rules_override="-DCMAKE_USER_MAKE_RULES_OVERRIDE=`"$(Join-Path $BIN_ROOT -ChildPath compiler_flag_overrides.cmake)`""   
                }
                                
                $BUILD_INFO.cmake_vars_define="-G `"$generator`" -DCMAKE_BUILD_TYPE:STRING=$($BUILD_INFO.build_type) $cmake_user_make_rules_override"   
                $null = $arg -match 'vs(\d+)'
                $BUILD_INFO.vs_version=$Matches[1] 
                  
                return $arg
            }
        }
        '^gcc$'{ 
            $gcc_exe='gcc.exe'
            $gxx_exe='g++.exe'
            #$gcc_exe='i686-w64-mingw32-gcc.exe'
            #$gxx_exe='i686-w64-mingw32-g++.exe'
            if($BUILD_INFO.gcc_location){
                $gcc_exe=Join-Path $BUILD_INFO.gcc_location -ChildPath $gcc_exe
            }else{
                $gcc_exe=where_first $gcc_exe
                if(!$gcc_exe){
                    # 如果系统中没有检测到 gcc 编译器则使用自带的 mingw 编译器
                    $mingw=$(if($BUILD_INFO.arch -eq 'x86'){$MINGW32_POSIX_INFO}else{$MINGW64_POSIX_INFO})                    
                    if(!(Test-Path $mingw.root -PathType Container)){
                        continue
                    }
                    $gcc_exe=Join-Path $mingw.root -ChildPath $gcc_exe
                }
            }  
            if(Test-Path $gcc_exe -PathType Leaf){
                $gcc_exe=(Get-Item $gcc_exe).FullName
                $BUILD_INFO.gcc_version=cmd /c "$gcc_exe -dumpversion 2>&1" 
                exit_on_error 
                $BUILD_INFO.gcc_location= (Get-Item $gcc_exe).Directory
                $BUILD_INFO.gcc_c_compiler=$gcc_exe
                $BUILD_INFO.gcc_cxx_compiler=Join-Path $BUILD_INFO.gcc_location -ChildPath $gxx_exe
                switch($BUILD_INFO.gcc_project){
                'make'{
                    $generator='MinGW Makefiles'
                    }
                'eclipse'{
                    $generator='Eclipse CDT4 - MinGW Makefiles'
                    }
                default{ call_stack; throw "(无效工程类型)invalid project type:$($BUILD_INFO.gcc_project)"}
                }
                exit_if_not_exist $BUILD_INFO.gcc_cxx_compiler -type Leaf -msg "(没找到g++编译器)not found g++ in $BUILD_INFO.gcc_location"
                $BUILD_INFO.cmake_vars_define="-G `"$generator`" -DCMAKE_C_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_c_compiler)"" -DCMAKE_CXX_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_cxx_compiler)"" -DCMAKE_BUILD_TYPE:STRING=$($BUILD_INFO.build_type)"
                $BUILD_INFO.exe_linker_flags='-static -static-libstdc++ -static-libgcc'
                # 寻找 mingw32 中的 make.exe，一般名为 mingw32-make
                $find=(ls $BUILD_INFO.gcc_location -Filter *make.exe|Select-Object -Property BaseName|Select-Object -First 1 ).BaseName
                if(!$find){
                    throw "这是什么鬼?没有找到make工具啊(not found make tools)"
                }else{
                    $BUILD_INFO.make_exe=$find
                    Write-Host "make tools:" $BUILD_INFO.make_exe -ForegroundColor Yellow
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
# 针对当前编译器 忽略 $BUILD_INFO  中指定名称属性(置为 $null ),并输出提示信息
# 该函数只能在编译已经确定之后调用
function ignore_arguments_by_compiler(){
    echo $args | foreach{
        if($_ -is [array]){
            if($_.count -ne 2){
                call_stack
                throw "(数组型参数长度必须为2),the argument with [arrray] type must have 2 elements"
            }
            $property=$_[0]
            $param=$_[1]
        }else{
            $property=$param=$_
        }        
        if((Get-Member -inputobject $BUILD_INFO -name $property )  -eq $null){            
            call_stack
            throw  "(未定义属性)undefined property '$property'"
        }                
        if($BUILD_INFO.$property){
            Write-Host "(忽略参数)ignore the argument '-$param' while $($BUILD_INFO.compiler) compiler"
            $BUILD_INFO.$property=$null
        }
    }
}
# 初始化 $BUILD_INFO 编译参数配置对象
function init_build_info(){
    Write-Host "初始化编译参数..."  -ForegroundColor Yellow
    # $BUILD_INFO.arch 为 auto时，设置为系统检查到的值
    if($BUILD_INFO.arch -eq 'auto'){
        args_not_null_empty_undefined HOST_PROCESSOR
        $BUILD_INFO.arch=$HOST_PROCESSOR
    }
    if($BUILD_INFO.gcc_location -and $BUILD_INFO.compiler -ne 'gcc'){        
        $BUILD_INFO.compiler='gcc'
        Write-Host "(重置参数)force set option '-compiler' to 'gcc' while use '-gcc' option" -ForegroundColor Yellow
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
        ignore_arguments_by_compiler msvc_shared_runtime msvc_project
    }elseif($BUILD_INFO.is_msvc()){
        ignore_arguments_by_compiler gcc_project gcc_location,gcc
    }    
    make_msvc_env
    $BUILD_INFO.save_env_snapshoot()
}
# 调用 vcvarsall.bat 创建msvc编译环境
# 当编译器选择 gcc 不会执行该函数
# 通过 $env:MSVC_ENV_MAKED 变量保证 该函数只会被调用一次
function make_msvc_env(){
    args_not_null_empty_undefined BUILD_INFO
    if( $BUILD_INFO.is_msvc()){
        if($BUILD_INFO.msvc_project -eq 'jom'){
            #  将jom加入搜索路径
            if( "$(where_first jom)" -ne (Get-Command $JOM_INFO.exe ).Definition){
                $env:Path="$($JOM_INFO.root);$env:Path"
            }
        }
    }
    if( $env:MSVC_ENV_MAKED -ne $BUILD_INFO.arch -and $BUILD_INFO.is_msvc()){
        if($BUILD_INFO.msvc_project -eq 'jom'){
            #  将jom加入搜索路径
            if( "$(where_first jom)" -ne (Get-Command $JOM_INFO.exe ).Definition){
                $env:Path="$($JOM_INFO.root);$env:Path"
            }
        }
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
        write-host "Visual Studio $($BUILD_INFO.vs_version) Command Prompt variables ($env:MSVC_ENV_MAKED) set." -ForegroundColor Yellow
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
    $BUILD_INFO.begin_build()
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$($project.install_path())"" 
        -DBUILD_SHARED_LIBS=off         
	    -DBUILD_STATIC_LIBS=on 
	    -DBUILD_gflags_LIB=on 
        -DREGISTER_INSTALL_PREFIX=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$project.install_path()"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 glog 源码
function build_glog(){
    $project=$GLOG_INFO
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $env:CXXFLAGS='/wd4290 /wd4267 /wd4722'
        $env:CFLAGS  ='/wd4290 /wd4267 /wd4722'
    }
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=$($project.install_path()) 
        -Dgflags_DIR=$gflags_DIR 
	    -DBUILD_SHARED_LIBS=off 2>&1"
    cmd /c $cmd
    exit_on_error
    $env:CXXFLAGS=''
    $env:CFLAGS  =''
    remove_if_exist "$project.install_path()"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# cmake静态编译 bzip2 1.0.5源码
function build_bzip2(){
    $project=$BZIP2_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $env:CXXFLAGS='/wd4996 /wd4267 /wd4244'
        $env:CFLAGS  ='/wd4996 /wd4267 /wd4244'
    }
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path""
        -DCMAKE_POLICY_DEFAULT_CMP0026=OLD
        -DBUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    $env:CXXFLAGS=''
    $env:CFLAGS  =''
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 boost 源码
function build_boost(){
    $project=$BOOST_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build($null,$true)

    #exit_if_not_exist $BZIP2_INSTALL_PATH "not found $BZIP2_INSTALL_PATH,please build $BZIP2_PREFIX"
    # 指定依赖库bzip2的位置,编译iostreams库时需要
    #export LIBRARY_PATH=$BZIP2_INSTALL_PATH/lib:$LIBRARY_PATH
    #export CPLUS_INCLUDE_PATH=$BZIP2_INSTALL_PATH/include:$CPLUS_INCLUDE_PATH

    # user-config.jam 位于boost 根目录下
    $jam=Join-Path $(pwd) -ChildPath user-config.jam
    $cxxflags=''
    $cflags=''
    # 根据$BUILD_INFO指定的编译器类型设置 toolset
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
        if($BUILD_INFO.compiler -eq 'vs2013'){
            $toolset='toolset=msvc-12.0'
            # 解决 .\boost/type_traits/common_types.h(42) : fatal error C1001: 编译发生内部错误
            # vs2013 update 5 无此问题
            $cxxflags='cxxflags=-DBOOST_NO_CXX11_VARIADIC_TEMPLATES'
        }elseif($BUILD_INFO.compiler -eq 'vs2015'){
            $toolset='toolset=msvc-14.0'
        }
    }
    # address-model=64 指定生成64位版本
    if($BUILD_INFO.arch -eq 'x86_64'){
        $address_model='address-model=64'
    }else{
        $address_model='address-model=32'
    }
    # runtime-link 指定生成 静态库或动态库
    if($BUILD_INFO.msvc_shared_runtime){
        $runtime_link="runtime-link=shared"
    }else{
        $runtime_link='runtime-link=static'
    }
    
    Write-Host "runing bootstrap..." -ForegroundColor Yellow
    cmd /c "bootstrap"
    exit_on_error
    Write-Host "bjam clean..." -ForegroundColor Yellow
    cmd /c "bjam --clean 2>&1"
    exit_on_error
    remove_if_exist "$install_path"    
    # 所有库列表
    # atomic chrono container context coroutine date_time exception filesystem 
    # graph graph_parallel iostreams locale log math mpi program_options python 
    # random regex serialization signals system test thread timer wave
    # --without-<library>指定不编译的库
    # --with-<library> 编译安装指定的库<library>
    # --prefix 指定安装位置
    # --debug-configuration 编译时显示加载的配置信息
    # -q 参数指示出错就停止编译
    # link=static 只编译静态库
    # -a 全部重新编译
    # -jx 并发编译线程数
    # -d+3 log信息显示级别
    Write-Host "boost compiling..." -ForegroundColor Yellow
    args_not_null_empty_undefined MAKE_JOBS
    $cmd=combine_multi_line "bjam --prefix=$install_path -a -q -d+3 -j$MAKE_JOBS --debug-configuration   
        --with-date_time
        --with-system
        --with-thread
        --with-filesystem
        --with-regex 
        link=static 
        variant=$($BUILD_INFO.build_type) $runtime_link $toolset $address_model $cxxflags $cflags
        install 2>&1"
    cmd /c $cmd 
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 protobuf 源码
function build_protobuf(){
    $project=$PROTOBUF_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.msvc_shared_runtime){
        $protobuf_msvc_static_runtime="-Dprotobuf_MSVC_STATIC_RUNTIME=off"
    }
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) ../cmake $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
    	    -Dprotobuf_BUILD_TESTS=off 
            $protobuf_msvc_static_runtime
			-Dprotobuf_BUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 hdf5 源码
function build_hdf5(){
    $project=$HDF5_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build($project.folder)
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
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 snappy 源码
function build_snappy(){
    $project=$SNAPPY_INFO
    $install_path=$project.install_path()
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $env:CXXFLAGS='/wd4819 /wd4267 /wd4244 /wd4018 /wd4005'
        $env:CFLAGS  ='/wd4819 /wd4267 /wd4244 /wd4018 /wd4005'
    }
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
        -DGflags_DIR=$gflags_DIR 
        -DBUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    $env:CXXFLAGS=''
    $env:CFLAGS  =''
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 opencv 源码
function build_opencv(){
    $project=$OPENCV_INFO
    $install_path=$project.install_path()
    # 如果不编译 FFMPEG 不需要 bzip2
    #bzip2_libraries=$BZIP2_INSTALL_PATH/lib/libbz2.a
    #exit_if_not_exist $bzip2_libraries "not found $bzip2_libraries,please build $BZIP2_PREFIX"
 
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        $build_with_static_crt="-DBUILD_WITH_STATIC_CRT=$(if($BUILD_INFO.msvc_shared_runtime){'off'}else{'on'})"
    }elseif($BUILD_INFO.is_gcc()){
        $build_fat_java_lib='-DBUILD_FAT_JAVA_LIB=off'
    }
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $env:CXXFLAGS='/wd4819'
        $env:CFLAGS  ='/wd4819'
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
    $env:CXXFLAGS=''
    $env:CFLAGS  =''
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# cmake静态编译 leveldb(bureau14)源码
function build_leveldb(){
    $project=$LEVELDB_INFO
    $install_path=$project.install_path()
    $boost_root=$BOOST_INFO.install_path()
    exit_if_not_exist "$boost_root"  -type Container -msg "not found $boost_root,please build $($BOOST_INFO.prefix)"
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $env:CXXFLAGS='/wd4312 /wd4244 /wd4018'
    }else{
        # 奇葩, port/port.h 居然没有找到MinGW编译器预定义的宏,只能在这里手工补上定义
        $cxxflags='-DWIN32 -D_WIN32'
    }
    $boost_use_static_runtime=$(if( $BUILD_INFO.msvc_shared_runtime){'off'}else{'on'})
    # BOOST_ROOT BOOST_INCLUDEDIR BOOST_LIBRARYDIR Boost_NO_SYSTEM_PATHS Boost_USE_STATIC_RUNTIME 参见 https://cmake.org/cmake/help/v3.8/module/FindBoost.html
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define('',$cxxflags)) -DCMAKE_INSTALL_PREFIX=""$install_path""
        -DBOOST_ROOT=`"$boost_root`"
        -DBOOST_INCLUDEDIR=`"$(Join-Path $boost_root -ChildPath include)`"
        -DBOOST_LIBRARYDIR=`"$(Join-Path $boost_root -ChildPath lib)`"
	    -DBoost_NO_SYSTEM_PATHS=on 
        -DBoost_USE_STATIC_RUNTIME=$boost_use_static_runtime
        -DBUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    $env:CXXFLAGS=''
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 静态编译 OpenBLAS 源码,在 MSYS2 中编译，需要 msys2 支持
function build_openblas(){
    $project=$OPENBLAS_INFO
    # 检查是否有安装 msys2 如果没有安装则退出
    if( ! $MSYS2_INSTALL_LOCATION ){
        throw "没有安装MSYS2,不能编译OpenBLAS,MSYS2 not installed,please install,run : ./fetch.ps1 msys2"
    }
    $binary=$(if($BUILD_INFO.arch -eq 'x86'){'BINARY=32'}else{'BINARY=64'})    
    $mingw_make="mingw32-make"
    if($BUILD_INFO.is_gcc()){
        $mingw_bin=$BUILD_INFO.gcc_location
        $mingw_make=$BUILD_INFO.make_exe
        $mingw_version=$BUILD_INFO.gcc_version
    }elseif($BUILD_INFO.arch -eq 'x86'){
        $mingw_bin= Join-Path $MINGW32_POSIX_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(没有安装 mingw32 编译器),mingw32 not found,install it by running ./fetch.ps1 mingw32"
        $mingw_version=$MINGW32_POSIX_INFO.version
    }else{
        $mingw_bin= Join-Path $MINGW64_POSIX_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(没有安装 mingw64 编译器),mingw64 not found,install it by running ./fetch.ps1 mingw64"
        $mingw_version=$MINGW64_POSIX_INFO.version
    }    
    $src_root=Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder
    $msys2bash=[io.path]::Combine($MSYS2_INSTALL_LOCATION,'usr','bin','bash')
    $install_path=unix_path($project.install_path())
    #$debug_build=$(if($BUILD_INFO.build_type -eq 'debug'){'DEBUG=1'}else{''})
    # openblas 编译release版本,不受$BUILD_INFO.build_type控制,
    $debug_build='DEBUG=0'
    if($openblas_no_dynamic_arch){
        $dynamic_arch=''
    }else{
        $dynamic_arch='DYNAMIC_ARCH=1'
    }
    
    if($openblas_no_use_thread){
        $use_thread='USE_THREAD=0'
        $num_threads=''
    }else{
        $use_thread='USE_THREAD=1'
        $num_threads="NUM_THREADS=$openblas_num_threads"
    }
    
    args_not_null_empty_undefined MAKE_JOBS
    remove_if_exist "$install_path"
    # MSYS2 下的gcc 编译脚本 (bash)
    # 任何一步出错即退出脚本 exit code = -1
    # 每一行必须 ; 号结尾(最后一行除外)
    # #号开头注释行会被 combine_multi_line 函数删除,不会出现在运行脚本中
    $bashcmd="export PATH=$(unix_path($mingw_bin)):`$PATH ;
        # 切换到 OpenBLAS 源码文件夹 
        cd `"$(unix_path $src_root)`" ; 
        # 先执行make clean
        echo start make clean,please waiting...;
        $mingw_make clean ;
        if [ ! `$? ];then exit -1;fi; 
        # BINARY 用于指定编译32位还是64位代码 -j 选项用于指定多线程编译
        $mingw_make -j $MAKE_JOBS NOFORTRAN=1 $binary $debug_build  $dynamic_arch $use_thread $num_threads; 
        if [ ! `$? ];then exit -1;fi;
        # 删除安装路径
        rm `"$install_path`" -fr;
        #if [ ! `$? ];then exit -1;fi;
        # 安装到指定的位置 $install_path 
        $mingw_make install PREFIX=`"$install_path`" NO_LAPACKE=1 "
    $cmd=combine_multi_line "$msys2bash -l -c `"$bashcmd`" 2>&1"
    Write-Host "(OpenBLAS 编译中...)compiling OpenBLAS by MinGW $mingw_version ($mingw_bin)" -ForegroundColor Yellow
    cmd /c $cmd
    exit_on_error
}
# cmake静态编译 lmdb 源码
function build_lmdb(){
    $project=$LMDB_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build(@('libraries','liblmdb'))
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path""  
        -DCLOSE_WARNING=on
        -DBUILD_TEST=off
        -DBUILD_SHARED_LIBS=off 2>&1" 
    cmd /c $cmd
    exit_on_error
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 检查指定的组件是否已经编译安装
# 如果缺少，则将错误信息添加到 $error_msg 
function check_component([string]$folder,[PSObject]$info,[ref][string[]]$error_msg){
    args_not_null_empty_undefined folder info error_msg
    $null=(! (exist_file $folder)) -and ( $error_msg.Value+="(缺少 $($info.prefix) ),not found $folder,please build it by running ./build.ps1 $($info.prefix)")
}
# 返回 openblas 安装路径
function find_openblas([ref][string[]]$error_msg){
    if($BUILD_INFO.is_gcc()){
        check_component $OPENBLAS_INFO.install_path() $OPENBLAS_INFO ([ref]$error_msg)
        return $OPENBLAS_INFO.install_path()
    }
    # MSVC 编译时,使用 OpenBLAS 动态库,不关心 OpenBLAS 的编译器版本号
    $f=ls $INSTALL_PREFIX_ROOT -Filter "$(install_suffix $OPENBLAS_INFO.prefix)*_$($BUILD_INFO.arch)"
    if(!$f){
        $error_msg.Value+="(缺少 $($info.prefix) ),not found $folder,please build it by running ./build.ps1 $($info.prefix)"
    }else{
        $f[0].FullName
    }
    
}
# cmake静态编译 caffe 系列源码(windows下编译)
function build_caffe_windows([PSObject]$project){
    args_not_null_empty_undefined project
    if($project.prefix -ne 'caffe'){
        throw "not project caffe based $project"
    }
    $install_path=$project.install_path()
    # 调用 check_component 函数依次检查编译 caffe 所需的依赖库是否齐全
    # 保存错误信息的数组,调用check_component时如果有错，错误保存到数组
    [string[]]$error_message=@()
    check_component $GFLAGS_INFO.install_path() $GFLAGS_INFO ([ref]$error_message)
    check_component $GLOG_INFO.install_path() $GLOG_INFO ([ref]$error_message)
    # hdf5 cmake 位置  
    $hdf5_cmake_dir="$($HDF5_INFO.install_path())/cmake"
    check_component $hdf5_cmake_dir $HDF5_INFO ([ref]$error_message)
    check_component $BOOST_INFO.install_path() $BOOST_INFO ([ref]$error_message)
    #check_component $OPENBLAS_INFO.install_path() $OPENBLAS_INFO ([ref]$error_message)
    $openblas_install_path=find_openblas ([ref]$error_message)
    check_component $PROTOBUF_INFO.install_path() $PROTOBUF_INFO ([ref]$error_message)
    # protobuf lib 路径
    $protobuf_lib="$($PROTOBUF_INFO.install_path())/lib"
    check_component $SNAPPY_INFO.install_path() $SNAPPY_INFO ([ref]$error_message)
    check_component $LMDB_INFO.install_path() $LMDB_INFO ([ref]$error_message)
    check_component $LEVELDB_INFO.install_path() $LEVELDB_INFO ([ref]$error_message)
    # opencv 配置文件(OpenCVConfig.cmake)所在路径
    $opencv_cmake_dir="$($OPENCV_INFO.install_path())"
    check_component $opencv_cmake_dir $OPENCV_INFO ([ref]$error_message)
    # 缺少依赖库时报错退出
    if($error_message.count){
        echo $error_message
        exit -1
    }
    if($caffe_gpu -and $BUILD_INFO.is_gcc()){
        Write-Host '(CUDA 不支持MinGW编译)MinGW unsuppored compiler for CUDA'  -ForegroundColor Yellow
        Write-Host 'see also http://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html#system-requirements'
        exit -1
    }
    # GPU/CPU模式编译开关
    $cpu_only=$(if($caffe_gpu){'OFF'}else{'ON'})
    # 指定cuDNN安装位置
    if($caffe_gpu -and $caffe_cudnn_root){
        exit_if_not_exist $caffe_cudnn_root -type Container
        $cudnn_root="-DCUDNN_ROOT=$caffe_cudnn_root"
    }else{
        $cudnn_root=''
    }
    $BUILD_INFO.begin_build($null,$false,$project.root)
    # 指定 OpenBLAS 安装路径 参见 $caffe_source/cmake/Modules/FindOpenBLAS.cmake
    $env:OpenBLAS_HOME=$openblas_install_path
    # 指定 lmdb 安装路径 参见 $caffe_source/cmake/Modules/FindLMDB.cmake.cmake
    $env:LMDB_DIR=$LMDB_INFO.install_path()
    # 指定 leveldb 安装路径 参见 $caffe_source/cmake/Modules/FindLevelDB.cmake.cmake
    $env:LEVELDB_ROOT=$LEVELDB_INFO.install_path()
    # GLOG_ROOT_DIR 参见 $caffe_source/cmake/Modules/FindGlog.cmake
    # GFLAGS_ROOT_DIR 参见 $caffe_source/cmake/Modules/FindGFlags.cmake
    # HDF5_ROOT 参见 https://cmake.org/cmake/help/v3.8/module/FindHDF5.html
    # BOOST_ROOT BOOST_INCLUDEDIR BOOST_LIBRARYDIR Boost_NO_SYSTEM_PATHS Boost_USE_STATIC_LIBS Boost_USE_STATIC_RUNTIME 参见 https://cmake.org/cmake/help/v3.8/module/FindBoost.html
    # SNAPPY_ROOT_DIR 参见 $caffe_source/cmake/Modules/FindSnappy.cmake
    # COPY_PREREQUISITES=off 关闭 windows 版预编译库下载 参见 $caffe_source/CMakeLists.txt
    # OpenCV_DIR 参见https://cmake.org/cmake/help/v3.8/command/find_package.html
    if($BUILD_INFO.is_msvc()){
        # MSVC 关闭编译警告
        $close_warning='/wd4996 /wd4267 /wd4244 /wd4018 /wd4800 /wd4661 /wd4812 /wd4309 /wd4305 /wd4819'
    }else{
        $close_warning=''    
    }

    # MinGW编译时,指定使用静态库,参见 openblas_install_path/cmake/openblas/OpenBLASConfig.cmake
    $openblas_use_static=$(if($BUILD_INFO.is_gcc() -and !$caffe_use_dynamic_openblas){'-DOpenBlas_USE_STATIC=on'}else{''})
        
    # msvc和mingw编译出来的protobuf版本install文件结构不完全相同
    # $protobuf_dir 定义 protobuf-config.cmake所在文件夹 
    if($BUILD_INFO.is_msvc()){
        $protobuf_dir=Join-Path $PROTOBUF_INFO.install_path() -ChildPath cmake
    }else{
        $protobuf_dir=[io.path]::Combine($PROTOBUF_INFO.install_path(),'lib','cmake','protobuf')
    }
    $boost_use_static_runtime=$(if( $BUILD_INFO.msvc_shared_runtime){'off'}else{'on'})
    $env:CXXFLAGS="$close_warning"
    $env:CFLAGS  ="$close_warning"
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define('','',$exe_link_opetion)) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
        $openblas_use_static
        -DCOPY_PREREQUISITES=off
        -DINSTALL_PREREQUISITES=off
	    -DGLOG_ROOT_DIR=`"$($GLOG_INFO.install_path())`"
	    -DGFLAGS_ROOT_DIR=`"$($GFLAGS_INFO.install_path())`" 
	    -DHDF5_ROOT=`"$($HDF5_INFO.install_path())`"
        -DHDF5_USE_STATIC_LIBRARIES=on
	    -DBOOST_ROOT=`"$($BOOST_INFO.install_path())`" 
        -DBOOST_INCLUDEDIR=`"$(Join-Path $($BOOST_INFO.install_path()) -ChildPath include)`"
        -DBOOST_LIBRARYDIR=`"$(Join-Path $($BOOST_INFO.install_path()) -ChildPath lib)`"
	    -DBoost_NO_SYSTEM_PATHS=on 
        -DBoost_USE_STATIC_LIBS=on
        -DBoost_USE_STATIC_RUNTIME=$boost_use_static_runtime
	    -DSNAPPY_ROOT_DIR=`"$($SNAPPY_INFO.install_path())`"
	    -DOpenCV_DIR=`"$opencv_cmake_dir`" 
        -Dprotobuf_MODULE_COMPATIBLE=on
        -DProtobuf_DIR=`"$protobuf_dir`"
	    -DCPU_ONLY=$cpu_only
        $cudnn_root
	    -DBLAS=Open 
	    -DBUILD_SHARED_LIBS=off 
	    -DBUILD_docs=off 
	    -DBUILD_python=off 
	    -DBUILD_python_layer=off 
	    -DUSE_LEVELDB=on 
	    -DUSE_LMDB=on 
	    -DUSE_OPENCV=on  2>&1" 
    cmd /c $cmd
    exit_on_error
    $env:CXXFLAGS=''
    $env:CFLAGS=''
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# 初始化自定义 caffe 项目信息
# 将自定义caffe信息写入 $CAFFE_CUSTOM_INFO
function init_custom_custom_info(){
    args_not_null_empty_undefined custom_caffe_folder
    if(! $custom_skip_patch){
        .\fetch.ps1 -modify_caffe $custom_caffe_folder
        exit_on_error
    }
    $cmakelists_root=Join-Path $custom_caffe_folder -ChildPath CMakeLists.txt
    $content=Get-Content $cmakelists_root
    $regex_find_project='^\s*project\s*\(\s*(\w+)\s+.*\)'
    $project_line=($content -match $regex_find_project) 
    if( $project_line ){
        $null=$project_line[0] -match $regex_find_project
        $CAFFE_CUSTOM_INFO.prefix=$Matches[1]
    }
    if($custom_install_prefix){
        $CAFFE_CUSTOM_INFO.install_prefix=$custom_install_prefix
    }else{
        $CAFFE_CUSTOM_INFO.install_prefix=Join-Path $INSTALL_PREFIX_ROOT -ChildPath $(install_suffix "$($CAFFE_CUSTOM_INFO.folder.replace('-','_'))")
    }
    $CAFFE_CUSTOM_INFO.root=$custom_caffe_folder
}
# 输出帮助信息
function print_help(){
    if($(chcp ) -match '\.*936$'){
	    echo "用法: $current_script_name [-names] [项目名称列表,...] [可选项...] 
编译安装指定的项目,如果没有指定项目名称，则编译所有项目
    -names,-build_project_names
                    项目名称列表(逗号分隔,忽略大小写,无空格)
                    可选的项目名称: $($all_project_names -join ',')
                    caffe_windows :官方caffe项目windows分支 https://github.com/BVLC/caffe.git branch:windows
                    conner99_ssd  :conner99的ssd windows版本  https://github.com/conner99/caffe.git branch:ssd-microsoft 
    -custom,-custom_caffe_folder
                    指定编译的caffe项目文件夹
    -prefix,-custom_install_prefix
                    caffe 项目安装路径,默认安装到 $INSTALL_PREFIX_ROOT,仅在指定-custom_caffe_folder时有效
    -skip,-custom_skip_patch
                    跳过补丁更新,默认每次build前都会执行补丁更新,仅在指定-custom_caffe_folder时有效
                    参见 fetch.ps1 中 modify_caffe_folder 函数
选项:
    -c,-compiler    指定编译器类型,可选值: vs2013,vs2015,gcc,默认 auto(自动侦测)
                    指定为gcc时,如果没有检测到MinGW编译器,则使用本系统自带的MinGW编译器
    -a,-arch        指定目标代码类型(x86,x86_64),默认auto(自动侦测)
    -g,-gcc         指定MingGW编译器的安装路径(bin文件夹),指定此值后，编译器类型(-compiler)自动设置为gcc
    -r,-revert      对项目强制执行fetch,将项目代码恢复到初始状态 
    -msvc_project   指定cmake 生成的MSVC工程类型及编译工具,默认为 JOM,仅在使用MSVC编译时有效
                    nmake: NMake Makefiles ,nmake 单线程编译
                    jom  : NMake Makefiles JOM,jom 并行编译,CPU满功率运行,比nmake提高数倍的速度
                    sln  : Visual Studio工程(.sln),MSBuild 并行编译
    -md,-msvc_shared_runtime  
                    MSVC编译时使用 /MD 连接选项,默认 /MT
    -gcc_project    指定MinGW编译时cmake 生成工程类型,默认为 make,仅在使用 MinGW 编译时有效
                    make    : MinGW Makefiles, 用于 mingw32-make 编译的 Makefile
                    eclipse : Eclipse CDT4 - MinGW Makefiles,Eclipse工程
    -openblas_no_dynamic_arch
                    OpenBLAS编译选项,指定不使用动态核心模式(DYNAMIC_ARCH),默认使用 DYNAMIC_ARCH
                    DYNAMIC_ARCH是指OpenBLAS 库中同时包含支持多种 cpu 核心架构的代码,
                    OpenBLAS可以在运行时自动切换到合适的架构代码(编译耗时较长)
                    指定此选项时,则会自动检测当前 cpu ,编译出适合当前 cpu 架构的库(编译时间较短),
                    在其他不同架构的cpu上运行可能会存在指令集兼容性问题
                    关于 OpenBLAS 的选项更详细的说明参见 OpenBLAS 源码文件夹下的 GotoBLAS_02QuickInstall.txt,Makefile.rule,USAGE.md等文件
    -openblas_no_use_thread 
                    OpenBLAS编译选项,指定不使用多线程,默认使用多线程模式
    -openblas_num_threads 
                    OpenBLAS编译选项,多线程模式时最大线程数,如果不指定则定义为当前cpu的核心数
    -caffe_gpu      编译GPU版本(CPU_ONLY=OFF)，默认编译CPU_ONLY版本,
                    指定此选项时，需要系统安装CUDA
    -caffe_cudnn_root
                    指定cuDNN安装路径，对应 CUDNN_ROOT in cmake/Cuda.cmake,只在指定了-caffe_gpu时有效
    -caffe_use_dynamic_openblas
                    指定编译 caffe 时使用 OpenBLAS 动态库,MingGW编译时有效,默认MinGW编译时使用 OpenBLAS 静态库
    -debug          编译Debug版本,默认Release
    -build_reserved 编译安装后保存编译生成的工程文件及中间文件
    -h,-help        显示帮助信息
作者: guyadong@gdface.net
"
    }else{
        echo "usage: $current_script_name [-names] [PROJECT_NAME,...] [options...] 
build & install projects specified by project names,
all projects builded if no name argument
    -names,-build_project_names
                    prject names(split by comma,ignore case,without blank)
                    optional project names: $($all_project_names -join ',')
                    caffe_windows :BVLC/caffe(windows) branch https://github.com/BVLC/caffe.git branch:windows
                    conner99_ssd  :conner99/ssd(windows)  https://github.com/conner99/caffe branch:ssd-microsoft 
    -custom,-custom_caffe_folder
                    caffe folder for building
    -prefix,-custom_install_prefix
                    default is $INSTALL_PREFIX_ROOT,effective only when -custom_caffe_folder defined
    -skip,-custom_skip_patch
                    no patch for caffe,effective only when -custom_caffe_folder defined                    
                    see also the 'modify_caffe_folder' function in fetch.ps1 
options:
    -c,-compiler    compiler type,valid value:'vs2013','vs2015','gcc',default 'auto' 
    -a,-arch        target processor architecture: 'x86','x86_64',default 'auto'
    -g,-gcc         MinGW compiler location('bin' folder,such as 'P:\MinGW\mingw64\bin'),
                    the '-compiler' option will be overwrited  to 'gcc' if this option defined 
    -r,-revert      force fetch the project,revert source code
    -j,-jom         jom parallel build with multiple CPU,effective only when MSVC
    -msvc_project   project file type generated by cmake,default JOM,effective only when MSVC
                    nmake: NMake Makefiles ,serial build by nmake 
                    jom  : NMake Makefiles JOM,parallel build by jom 
                    sln  : Visual Studio工程(.sln),parallel build by MSBuild
    -md,-msvc_shared_runtime  
                    use /MD link option,default /MT ,effective only when MSVC
    -gcc_project    project file type generated by cmake,default 'make',effective only when MinGW
                    make    : MinGW Makefiles
                    eclipse : Eclipse CDT4 - MinGW Makefiles
    -openblas_no_dynamic_arch
                    OpenBLAS build option ,set  DYNAMIC_ARCH = 0 ,default set DYNAMIC_ARCH=1
                    while DYNAMIC_ARCH=1,all kernel will be included in the library and dynamically switched
                    the best architecutre at run time.
    -openblas_no_use_thread 
                    OpenBLAS build option,set USE_THREAD=0 ,default set USE_THREAD=1
                    while USE_THREAD=1,OpenBLAS will work in multi-threaded mode。
    -openblas_num_threads 
                    OpenBLAS build option,set NUM_THREADS to number that you specify, define maximum number of threads.
                    by default,it's automatically detected and set be number of logical cores
                    For more detail,see also GotoBLAS_02QuickInstall.txt,Makefile.rule,USAGE.md in OpenBLAS source folder
    -caffe_gpu      CPU_ONLY=OFF， default CPU_ONLY=ON,
                    need CUDA support if selected the option
    -caffe_cudnn_root
                    set CUDNN_ROOT in cmake/Cuda.cmake,effective only when -caffe_gpu selected
    -caffe_use_dynamic_openblas
                    use OpenBLAS dynamic library when build caffe project,effective only when MinGW,
                    by default OpenBLAS static library used when MinGW
    -debug          Debug building, default is Release
    -build_reserved reserve thd build folder while project building finished
	-h,-help        print the message
author: guyadong@gdface.net
"
    }
}
# 确保 $input 中的字符串不重复且顺序与 $available_names 中的一致,
# 不包含在 $available_names 中的字符串加在最后
function sorted_project([string[]]$available_names){
    args_not_null_empty_undefined available_names
    $pipeline_data = @($Input)
    $unique_input=$pipeline_data |Sort-Object | Get-Unique
    $sorted_names=@()
    $available_names | foreach{
        if($unique_input -contains $_){
            $sorted_names+=$_
        }
    }
    $pipeline_data|foreach{
        if($sorted_names -notcontains $_){
            $sorted_names+=$_
        }
    }
    $sorted_names
}
$caffe_name='caffe_windows'
$caffe_projects="$caffe_name conner99_ssd".Trim() -split '\s+'
$dependencies_projects='gflags glog bzip2 boost leveldb lmdb snappy openblas hdf5 opencv protobuf'.Trim() -split '\s+' 
# 所有项目列表字符串数组
$all_project_names=$dependencies_projects + $caffe_projects

# 当前脚本名称
$current_script_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
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

# 没有指定 names 参数时编译所有项目
if(! $build_project_names){
    if($custom_caffe_folder){
        $build_project_names=@($caffe_name)
    }else{
        $build_project_names= $all_project_names
    }    
}
# 因为各个项目之间有前后依赖关系,所以这里对输入的名字顺序重新排列，确保正确的依赖关系
$build_project_names=$build_project_names | sorted_project $all_project_names
$build_project_names| foreach {    
    if( (! (Test-Path function:"build_$($_.ToLower())")) -and (! ($caffe_projects -contains $_))){
        echo "(不识别的项目名称)unknow project name:$_"
        print_help
        exit -1
    }
}

$fetch_names=@()
if($revert){
    $fetch_names=$build_project_names
}else{
    $build_project_names| foreach {
        if($_ -ne $caffe_name -or !$custom_caffe_folder){
            # 如果源码文件夹不存在,则需要fetch该项目   
            $info=Get-Variable "$($_.ToLower())_INFO" -ValueOnly
            if(  ! (Test-Path (Join-Path $SOURCE_ROOT -ChildPath $info.folder) -PathType Container)){
                $fetch_names+=$_
            }
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

# 顺序编译 $build_project_names 中指定的项目
$build_project_names| foreach {
    if($caffe_projects -contains $_){
        $info_prefix=$_
        if($custom_caffe_folder){
            init_custom_custom_info
            $info_prefix='CAFFE_CUSTOM'
        }
        build_caffe_windows(Get-Variable "$($info_prefix.ToUpper())_INFO" -ValueOnly)
    }
    else{
        &build_$($_.ToLower())      
    }     
}