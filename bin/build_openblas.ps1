<#
编译openblas 动态库，
author: guyadong@gdface.net
#>
param(
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[string]$TARGET,
[switch]$DYNAMIC_ARCH,
[switch]$USE_THREAD,
[string]$gcc=$DEFAULT_GCC,
[switch]$revert,
[alias('md')]
[switch]$msvc_shared_runtime,
[switch]$debug,
[switch]$help
)
if(! $BUILD_INFO){
. "$PSScriptRoot/build_info.ps1"
}
# 编译 OpenBLAS 动态库,在 MSYS2 中编译，需要 msys2 支持
function build_openblas(){
    $project=$OPENBLAS_INFO
    # 检查是否有安装 msys2 如果没有安装则退出
    if( ! $MSYS2_INSTALL_LOCATION ){
        throw "没有安装MSYS2,不能编译OpenBLAS,MSYS2 not installed,please install,run : ./fetch.ps1 msys2"
    }
    $binary=$(if($BUILD_INFO.arch -eq 'x86'){32}else{64})    
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
    # 不用 msys2_shell.cmd 执行脚本是因为返回的exit code总是0，无法判断脚本是否正确执行
    #$msys2bash=[io.path]::Combine($MSYS2_INSTALL_LOCATION,'msys2_shell.cmd')
    $install_path=unix_path($project.install_path())
    #  USE_FOR_MSVC 宏定义用于控制编译 openblas 静态库代码时不使用 libmsvcrt.a 中的函数
    #　参见 $openblase_source/Makefile.system 中 USE_FOR_MSVC 定义说明    
    $use_for_msvc=$(if($BUILD_INFO.is_msvc()){' export USE_FOR_MSVC=1 ; '}else{''})
    #$debug_build=$(if($BUILD_INFO.build_type -eq 'debug'){'DEBUG=1'}else{''})
    # openblas 编译release版本,不受$BUILD_INFO.build_type控制,
    $debug_build='DEBUG=0'
    args_not_null_empty_undefined MAKE_JOBS
    remove_if_exist "$install_path"
    # MSYS2 下的gcc 编译脚本 (bash)
    # 任何一步出错即退出脚本 exit code = -1
    # 每一行必须 ; 号结尾(最后一行除外)
    # #号开头注释行会被 combine_multi_line 函数删除,不会出现在运行脚本中
    $bashcmd="export PATH=$(unix_path($mingw_bin)):`$PATH ;$use_for_msvc
        # 切换到 OpenBLAS 源码文件夹 
        cd `"$(unix_path $src_root)`" ; 
        # 先执行make clean
        echo start make clean,please waiting...;
        $mingw_make clean ;
        if [ ! `$? ];then exit -1;fi; 
        # BINARY 用于指定编译32位还是64位代码 -j 选项用于指定多线程编译
        $mingw_make -j $MAKE_JOBS BINARY=$binary $debug_build NOFORTRAN=1 NO_LAPACKE=1 NO_SHARED=1 ; 
        if [ ! `$? ];then exit -1;fi;
        # 安装到 $install_path 指定的位置
        $mingw_make install PREFIX=`"$install_path`" NO_LAPACKE=1"
    $cmd=combine_multi_line "$msys2bash -l -c `"$bashcmd`" 2>&1"
    #$cmd="$msys2bash -where $src_root -l -c `"$bashcmd`" 2>&1"
    Write-Host "(OpenBLAS 编译中...)compiling OpenBLAS by MinGW $mingw_version ($mingw_bin)" -ForegroundColor Yellow
    cmd /c $cmd
    exit_on_error
}
