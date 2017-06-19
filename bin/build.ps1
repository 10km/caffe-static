param(
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[string]$gcc=$DEFAULT_GCC,
[switch]$help
)
. "./build_vars.ps1"
# ����where ������·���в��� $who ָ���Ŀ�ִ���ļ�,
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
                $BUILD_INFO.cmake_vars_define="-G ""MinGW Makefiles"" -DCMAKE_C_COMPILER:FILEPATH=$($BUILD_INFO.gcc_c_compiler) -DCMAKE_CXX_COMPILER:FILEPATH=$($BUILD_INFO.gcc_cxx_compiler) -DCMAKE_BUILD_TYPE:STRING=RELEASE"
                $BUILD_INFO.make_exe=(ls $BUILD_INFO.gcc_location -Filter *make*.exe).Name
                args_not_null_empty_undefined MAKE_JOBS
                $BUILD_INFO.make_exe_option="-j $MAKE_JOBS"
                if(!((Get-Item $gcc_exe).FullName -eq "$(where_first gcc)")){
                    # $BUILD_INFO.gcc_location ��������·��
                    $env:path="$($BUILD_INFO.gcc_location);$env:path"
                }
                return $arg
            }
            
        }
        Default { echo "invalid compiler type:$arg";call_stack;exit -1}
        }
    }
    echo "(û���ҵ�ָ�����κ�һ�ֱ���������ȷ����װ��ô?)not found compiler:$args"
    exit -1
}
# ��ʼ�� $BUILD_INFO ����������ö���
function init_build_info(){
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
    }else{
        $script:HOST_PROCESSOR=$BUILD_INFO.arch
    }
    make_msvc_env
}
# ���� vcvarsall.bat ����msvc���뻷��
# ��������ѡ�� gcc ����ִ�иú���
# ͨ�� $MSVC_ENV_MAKED ������֤ �ú���ֻ�ᱻ����һ��
function make_msvc_env(){
    args_not_null_empty_undefined BUILD_INFO
    if(!$script:MSVC_ENV_MAKED -and $BUILD_INFO.compiler -match 'vs(\d+)'){
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
# ������������Ĳ�����ʼ�� $BUILD_INFO ���� [PSObject]
$BUILD_INFO=New-Object PSObject -Property @{
    compiler=$compiler
    arch=$arch
    env_vs2015='VS140COMNTOOLS'
    env_vs2013='VS120COMNTOOLS'
    msvc_root=""
    gcc_location=$gcc
    gcc_version=""
    gcc_c_compiler=""
    gcc_cxx_compiler=""
    # cmake ��������
    cmake_vars_define=""
    make_exe=""
    make_exe_option=""
}

# ��̬���� gflags Դ��
function build_flags(){
    pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $GFLAGS_INFO.folder)
    remove_if_exist CMakeCache.txt
    remove_if_exist CMakeFiles
    cmd /c "$($CMAKE_INFO.exe) . $($BUILD_INFO.cmake_vars_define) -DCMAKE_INSTALL_PREFIX=$($GFLAGS_INFO.install_path()) ^
	    -DBUILD_SHARED_LIBS=off ^
	    -DBUILD_STATIC_LIBS=on ^
	    -DBUILD_gflags_LIB=on ^
	    -DINSTALL_STATIC_LIBS=on ^
	    -DINSTALL_SHARED_LIBS=off ^
	    -DREGISTER_INSTALL_PREFIX=off 2>&1"
    exit_on_error
    remove_if_exist $GFLAGS_INFO.install_path()
    cmd /c "$($BUILD_INFO.make_exe) clean 2>&1"
    exit_on_error
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) install 2>&1"
    exit_on_error
    popd
}

init_build_info
$BUILD_INFO

build_flags