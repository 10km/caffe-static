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