<#
����openblas ��̬�⣬
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
# ���� OpenBLAS ��̬��,�� MSYS2 �б��룬��Ҫ msys2 ֧��
function build_openblas(){
    $project=$OPENBLAS_INFO
    # ����Ƿ��а�װ msys2 ���û�а�װ���˳�
    if( ! $MSYS2_INSTALL_LOCATION ){
        throw "û�а�װMSYS2,���ܱ���OpenBLAS,MSYS2 not installed,please install,run : ./fetch.ps1 msys2"
    }
    $binary=$(if($BUILD_INFO.arch -eq 'x86'){32}else{64})    
    $mingw_make="mingw32-make"
    if($BUILD_INFO.is_gcc()){
        $mingw_bin=$BUILD_INFO.gcc_location
        $mingw_make=$BUILD_INFO.make_exe
        $mingw_version=$BUILD_INFO.gcc_version
    }elseif($BUILD_INFO.arch -eq 'x86'){
        $mingw_bin= Join-Path $MINGW32_POSIX_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(û�а�װ mingw32 ������),mingw32 not found,install it by running ./fetch.ps1 mingw32"
        $mingw_version=$MINGW32_POSIX_INFO.version
    }else{
        $mingw_bin= Join-Path $MINGW64_POSIX_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(û�а�װ mingw64 ������),mingw64 not found,install it by running ./fetch.ps1 mingw64"
        $mingw_version=$MINGW64_POSIX_INFO.version
    }    
    $src_root=Join-Path -Path $SOURCE_ROOT -ChildPath $project.folder
    $msys2bash=[io.path]::Combine($MSYS2_INSTALL_LOCATION,'usr','bin','bash')
    # ���� msys2_shell.cmd ִ�нű�����Ϊ���ص�exit code����0���޷��жϽű��Ƿ���ȷִ��
    #$msys2bash=[io.path]::Combine($MSYS2_INSTALL_LOCATION,'msys2_shell.cmd')
    $install_path=unix_path($project.install_path())
    #  USE_FOR_MSVC �궨�����ڿ��Ʊ��� openblas ��̬�����ʱ��ʹ�� libmsvcrt.a �еĺ���
    #���μ� $openblase_source/Makefile.system �� USE_FOR_MSVC ����˵��    
    $use_for_msvc=$(if($BUILD_INFO.is_msvc()){' export USE_FOR_MSVC=1 ; '}else{''})
    #$debug_build=$(if($BUILD_INFO.build_type -eq 'debug'){'DEBUG=1'}else{''})
    # openblas ����release�汾,����$BUILD_INFO.build_type����,
    $debug_build='DEBUG=0'
    args_not_null_empty_undefined MAKE_JOBS
    remove_if_exist "$install_path"
    # MSYS2 �µ�gcc ����ű� (bash)
    # �κ�һ�������˳��ű� exit code = -1
    # ÿһ�б��� ; �Ž�β(���һ�г���)
    # #�ſ�ͷע���лᱻ combine_multi_line ����ɾ��,������������нű���
    $bashcmd="export PATH=$(unix_path($mingw_bin)):`$PATH ;$use_for_msvc
        # �л��� OpenBLAS Դ���ļ��� 
        cd `"$(unix_path $src_root)`" ; 
        # ��ִ��make clean
        echo start make clean,please waiting...;
        $mingw_make clean ;
        if [ ! `$? ];then exit -1;fi; 
        # BINARY ����ָ������32λ����64λ���� -j ѡ������ָ�����̱߳���
        $mingw_make -j $MAKE_JOBS BINARY=$binary $debug_build NOFORTRAN=1 NO_LAPACKE=1 NO_SHARED=1 ; 
        if [ ! `$? ];then exit -1;fi;
        # ��װ�� $install_path ָ����λ��
        $mingw_make install PREFIX=`"$install_path`" NO_LAPACKE=1"
    $cmd=combine_multi_line "$msys2bash -l -c `"$bashcmd`" 2>&1"
    #$cmd="$msys2bash -where $src_root -l -c `"$bashcmd`" 2>&1"
    Write-Host "(OpenBLAS ������...)compiling OpenBLAS by MinGW $mingw_version ($mingw_bin)" -ForegroundColor Yellow
    cmd /c $cmd
    exit_on_error
}
