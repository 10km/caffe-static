<#
�Զ�����caffe-ssd�������������п⣬
���ָ����Ŀ��Դ�벻����,���Զ�����fetch.ps1 ����Դ��
author: guyadong@gdface.net
#>
param(
[string[]]$names,
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[ValidateSet('nmake','jom','sln')]
[string]$msvc_project='jom',
[string]$gcc=$DEFAULT_GCC,
[switch]$revert,
[alias('md')]
[switch]$msvc_shared_runtime,
[switch]$debug,
[switch]$build_reserved,
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
    # Visual Studio �汾�� (2013/2015...)
    vs_version=""
    vc_version=@{ 'vs2013'='vc120' 
                  'vs2015'='vc140'}
    msvc_project=$msvc_project
    # MSVC ����ѡ��ʹ�� /MD
    msvc_shared_runtime=$msvc_shared_runtime
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
    # c������ͨ��ѡ�� (CMAKE_C_FLAGS)  �μ� https://cmake.org/cmake/help/v3.8/variable/CMAKE_LANG_FLAGS.html
    c_flags=""
    # c++������ͨ��ѡ�� (CMAKE_CXX_FLAGS),ͬ��
    cxx_flags=""
    # ��ִ�г���(exe)����ѡ��(CMAKE_EXE_LINKER_FLAGS) �μ� https://cmake.org/cmake/help/v3.8/variable/CMAKE_EXE_LINKER_FLAGS.html
    exe_linker_flags=""
    # make �����ļ���,msvcΪnmake,mingwΪmake 
    make_exe=""
    nmake_parallel=$jom
    # make ���߱���ʱ��Ĭ��ѡ��
    make_exe_option=""
    # install ��������,ʹ��msbuild����msvc����ʱ����Ϊ'install.vcxproj'
    make_install_target='install'
    # ��Ŀ����ɹ����Ƿ���� build�ļ���
    build_type=$(if($debug){'debug'}else{'release'})
    remove_build= ! $build_reserved
    # ������������,�ɳ�Ա save_env_snapshoot ����
    # Ϊ��֤ÿ�� build_xxxx ����ִ��ʱ�����������������ţ�
    # �ڿ�ʼ����ǰ���� restore_env_snapshoot ���˱����б�������л��������ָ��� save_env_snapshoot ����ʱ��״̬
    env_snapshoot=$null
}
# $BUILD_INFO ��Ա���� 
# ���ɵ��� cmake ʱ��Ĭ�������в���
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
# $BUILD_INFO ��Ա���� 
# �жϱ������ǲ��� msvc
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name is_msvc -Value {
    $this.compiler -match 'vs\d+'
}
# $BUILD_INFO ��Ա���� 
# �жϱ������ǲ��� msvc
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name is_gcc -Value {
    $this.compiler -eq 'gcc'
}
# $BUILD_INFO ��Ա���� 
# ������Ŀ�ļ��У����û��ָ�� $no_build ��� build �ļ���,������ build�ļ���
# �����߱��뽫 ��Ŀ���ö���(�� BOOST_INFO)������ $project ������
# $no_build ������ build �ļ���
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name begin_build -Value {
    param([string[]]$sub_folders,[switch]$no_build)
    args_not_null_empty_undefined project
    Write-Host "(��ʼ����)building $($project.prefix) $($project.version)" -ForegroundColor Yellow
    [string[]]$paths=$SOURCE_ROOT,$project.folder
    $paths+=$sub_folders
    pushd ([io.path]::Combine($paths))
    if(! $no_build){
        $build="build.$($this.compiler)"
        clean_folder $build
        pushd "$build"
    }
    $BUILD_INFO.restore_env_snapshoot()
}
# $BUILD_INFO ��Ա���� 
# �˳���Ŀ�ļ��У���� build �ļ���,������ prepare_build ���ʹ��
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
# $BUILD_INFO ��Ա���� 
# �������е�ǰ���������� env_snapshoot
# �ú���ֻ�ܱ�����һ��
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name save_env_snapshoot -Value {
    if($this.env_snapshoot){
        call_stack
        throw "(������ֻ��������һ��),the function can only be called once "
    }
    $this.env_snapshoot=cmd /c set
}
# $BUILD_INFO ��Ա���� 
# �ָ� env_snapshoot �б���Ļ�������
# �ú���ֻ���ڵ��� save_env_snapshoot �󱻵���
Add-Member -InputObject $BUILD_INFO -MemberType ScriptMethod -Name restore_env_snapshoot -Value {
    if(!$this.env_snapshoot){
        call_stack
        throw "(�ú���ֻ���ڵ��� save_env_snapshoot �󱻵���),the function must be called after 'save_env_snapshoot' called  "
    }
    $this.env_snapshoot|
    foreach {
        if ($_ -match "=") {
        $v = $_.split("=")
        Set-Item -Force -Path "env:$($v[0])"  -Value "$($v[1])"
        }
    }
}
# include ����ȫ�ֱ���    
. "$PSScriptRoot/build_vars.ps1"

# ���� where ������·���в��� $who ָ���Ŀ�ִ���ļ�,
# ����ҵ��򷵻ص�һ�����
# ���û�ҵ����ؿ� 
function where_first($who){
    args_not_null_empty_undefined who    
    (get-command $who  -ErrorAction SilentlyContinue| Select-Object Definition -First 1).Definition
}

# ���� gcc ������($gcc_compiler)�Ƿ�������$archָ���Ĵ���(32/64λ)
# ������ܣ��򱨴��˳�
function test_gcc_compiler_capacity([string]$gcc_compiler,[ValidateSet('x86','x86_64')][string]$arch){
    args_not_null_empty_undefined arch gcc_compiler
    # ����Ƿ�Ϊ gcc ������
    cmd /c "$gcc_compiler -dumpversion >nul 2>nul"
    exit_on_error "$gcc_compiler is not gcc compiler"
    if($arch -eq 'x86'){
        $c_flags='-m32'
    }elseif($arch -eq 'x86_64'){
        $c_flags='-m64'
    }
    $test=Join-Path $env:TEMP -ChildPath 'test-m32-m64-enable'
    # ��ϵͳ temp �ļ���������һ����ʱ .c �ļ�
    echo "int main(){return 0;}`n" |Out-File "$test.c" -Encoding ascii -Force
    # ����ָ���ı������������б��� .c �ļ�
    cmd /c "$gcc_compiler $test.c $c_flags -o $test >nul 2>nul"    
    exit_on_error "ָ���ı������������� $arch ����($gcc_compiler can't build $arch code)"
    # �����ʱ�ļ�
    del "$test*" -Force
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
                switch($BUILD_INFO.msvc_project){
                'nmake'{
                    $generator='NMake Makefiles'
                    $BUILD_INFO.make_exe='nmake'
                }
                'jom'{
                    exit_if_not_exist $JOM_INFO.root -type Container -msg '(û�а�װ jom),not found jom,please install it by running ./fetch.ps1 jom'
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
                default{ call_stack; throw "(��Ч��������)invalid project type:$($BUILD_INFO.msvc_project)"}
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
            if($BUILD_INFO.gcc_location){
                $gcc_exe=Join-Path $BUILD_INFO.gcc_location -ChildPath $gcc_exe
            }else{
                $gcc_exe=where_first $gcc_exe
                if(!$gcc_exe){
                    # ���ϵͳ��û�м�⵽ gcc ��������ʹ���Դ��� mingw ������
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
                exit_if_not_exist $BUILD_INFO.gcc_cxx_compiler -type Leaf -msg "(û�ҵ�g++������)not found g++ in $BUILD_INFO.gcc_location"
                $BUILD_INFO.cmake_vars_define="-G ""MinGW Makefiles"" -DCMAKE_C_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_c_compiler)"" -DCMAKE_CXX_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_cxx_compiler)"" -DCMAKE_BUILD_TYPE:STRING=$($BUILD_INFO.build_type)"
                $BUILD_INFO.exe_linker_flags='-static -static-libstdc++ -static-libgcc'
                # Ѱ�� mingw32 �е� make.exe��һ����Ϊ mingw32-make
                $find=(ls $BUILD_INFO.gcc_location -Filter *make.exe|Select-Object -Property BaseName|Select-Object -First 1 ).BaseName
                if(!$find){
                    throw "����ʲô��?û���ҵ�make���߰�(not found make tools)"
                }else{
                    $BUILD_INFO.make_exe=$find
                    Write-Host "make tools:" $BUILD_INFO.make_exe -ForegroundColor Yellow
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
# ��Ե�ǰ������ ���� $BUILD_INFO  ��ָ����������(��Ϊ $null ),�������ʾ��Ϣ
# �ú���ֻ���ڱ����Ѿ�ȷ��֮�����
function ignore_arguments_by_compiler(){
    echo $args | foreach{
        if($_ -is [array]){
            if($_.count -ne 2){
                call_stack
                throw "(�����Ͳ������ȱ���Ϊ2),the argument with [arrray] type must have 2 elements"
            }
            $property=$_[0]
            $param=$_[1]
        }else{
            $property=$param=$_
        }        
        if((Get-Member -inputobject $BUILD_INFO -name $property )  -eq $null){            
            call_stack
            throw  "(δ��������)undefined property '$property'"
        }                
        if($BUILD_INFO.$property){
            Write-Host "(���Բ���)ignore the argument '-$param' while $($BUILD_INFO.compiler) compiler"
            $BUILD_INFO.$property=$null
        }
    }
}
# ��ʼ�� $BUILD_INFO ����������ö���
function init_build_info(){
    Write-Host "��ʼ���������..."  -ForegroundColor Yellow
    # $BUILD_INFO.arch Ϊ autoʱ������Ϊϵͳ��鵽��ֵ
    if($BUILD_INFO.arch -eq 'auto'){
        args_not_null_empty_undefined HOST_PROCESSOR
        $BUILD_INFO.arch=$HOST_PROCESSOR
    }
    if($BUILD_INFO.gcc_location ){        
        $BUILD_INFO.compiler='gcc'
        Write-Host "(���ò���)force set option '-compiler' to 'gcc' while use '-gcc' option" -ForegroundColor Yellow
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
    }    
    make_msvc_env
    $BUILD_INFO.save_env_snapshoot()
}
# ���� vcvarsall.bat ����msvc���뻷��
# ��������ѡ�� gcc ����ִ�иú���
# ͨ�� $env:MSVC_ENV_MAKED ������֤ �ú���ֻ�ᱻ����һ��
function make_msvc_env(){
    args_not_null_empty_undefined BUILD_INFO
    if( $BUILD_INFO.is_msvc()){
        if($BUILD_INFO.msvc_project -eq 'jom'){
            #  ��jom��������·��
            if( "$(where_first jom)" -ne (Get-Command $JOM_INFO.exe ).Definition){
                $env:Path="$($JOM_INFO.root);$env:Path"
            }
        }
    }
    if( $env:MSVC_ENV_MAKED -ne $BUILD_INFO.arch -and $BUILD_INFO.is_msvc()){
        if($BUILD_INFO.msvc_project -eq 'jom'){
            #  ��jom��������·��
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

# �����е������ַ���ȥ�����з���ϳ�һ��
# ���з� ����Ϊ '^' '\' ��β
# ɾ�� #��ͷ��ע����
function combine_multi_line([string]$cmd){
    args_not_null_empty_undefined cmd    
    ($cmd -replace '\s*#.*\n',''  ) -replace '\s*[\^\\]?\s*\r\n\s*',' ' 
}
# ��̬���� gflags Դ��
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
# ��̬���� glog Դ��
function build_glog(){
    $project=$GLOG_INFO
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC �رձ��뾯��
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
# cmake��̬���� bzip2 1.0.5Դ��
function build_bzip2(){
    $project=$BZIP2_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC �رձ��뾯��
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
# ��̬���� boost Դ��
function build_boost(){
    $project=$BOOST_INFO
    $install_path=$project.install_path()
    $BUILD_INFO.begin_build($null,$true)

    #exit_if_not_exist $BZIP2_INSTALL_PATH "not found $BZIP2_INSTALL_PATH,please build $BZIP2_PREFIX"
    # ָ��������bzip2��λ��,����iostreams��ʱ��Ҫ
    #export LIBRARY_PATH=$BZIP2_INSTALL_PATH/lib:$LIBRARY_PATH
    #export CPLUS_INCLUDE_PATH=$BZIP2_INSTALL_PATH/include:$CPLUS_INCLUDE_PATH

    # user-config.jam λ��boost ��Ŀ¼��
    $jam=Join-Path $(pwd) -ChildPath user-config.jam
    if($BUILD_INFO.is_gcc()){
        # ʹ�� gcc ������ʱ�� user-config.jam ָ��������·��
        # Out-File Ĭ�����ɵ��ļ���bomͷ���������� user-config.jam ʱҪָ�� ASCII ����(��bom)����������ʱ��ȡ�ļ�����syntax error at EOF
        $env:BOOST_BUILD_PATH=$pwd
        echo "using gcc : $($BUILD_INFO.gcc_version) : $($BUILD_INFO.gcc_cxx_compiler.Replace('\','/') ) ;" | Out-File "$jam" -Encoding ASCII -Force
        cat "$jam"
        $toolset='toolset=gcc'
    }else{
        $env:BOOST_BUILD_PATH=''
        remove_if_exist "$jam"
        if($BUILD_INFO.compiler -eq 'vs2013'){
            $toolset='toolset=msvc-12.0'
        }elseif($BUILD_INFO.compiler -eq 'vs2015'){
            $toolset='toolset=msvc-14.0'
        }
    }
    if($BUILD_INFO.arch -eq 'x86_64'){
        $address_model='address-model=64'
    }
    
    if($BUILD_INFO.msvc_shared_runtime){
        $runtime_link="runtime-link=shared"
    }else{
        $runtime_link='runtime-link=static'
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
    Write-Host "bjam clean..." -ForegroundColor Yellow
    cmd /c "bjam --clean 2>&1"
    exit_on_error
    remove_if_exist "$install_path"    

    # --prefix ָ����װλ��
    # --debug-configuration ����ʱ��ʾ���ص�������Ϣ
    # -q ����ָʾ�����ֹͣ����
    # link=static ֻ���뾲̬��
    # --with-<library> ���밲װָ���Ŀ�<library>
    # -a ȫ�����±���
    # -jx ���������߳���
    Write-Host "boost compiling..." -ForegroundColor Yellow
    args_not_null_empty_undefined MAKE_JOBS
    $cmd=combine_multi_line "bjam --prefix=$install_path -a -q -d+3 -j$MAKE_JOBS --debug-configuration   
        --with-date_time
        --with-system
        --with-thread
        --with-filesystem
        --with-regex 
        link=static 
        variant=$($BUILD_INFO.build_type) $runtime_link $toolset $address_model 
        install 2>&1"
    cmd /c $cmd 
    exit_on_error
    $BUILD_INFO.end_build()
}
# ��̬���� protobuf Դ��
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
# ��̬���� hdf5 Դ��
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
# ��̬���� snappy Դ��
function build_snappy(){
    $project=$SNAPPY_INFO
    $install_path=$project.install_path()
    $gflags_DIR=[io.path]::combine($($GFLAGS_INFO.install_path()),'cmake')
    exit_if_not_exist "$gflags_DIR"  -type Container -msg "not found $gflags_DIR,please build $($GFLAGS_INFO.prefix)"
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC �رձ��뾯��
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
# ��̬���� opencv Դ��
function build_opencv(){
    $project=$OPENCV_INFO
    $install_path=$project.install_path()
    # ��������� FFMPEG ����Ҫ bzip2
    #bzip2_libraries=$BZIP2_INSTALL_PATH/lib/libbz2.a
    #exit_if_not_exist $bzip2_libraries "not found $bzip2_libraries,please build $BZIP2_PREFIX"
 
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        $build_with_static_crt="-DBUILD_WITH_STATIC_CRT=$(if($BUILD_INFO.msvc_shared_runtime){'off'}else{'on'})"
    }elseif($BUILD_INFO.is_gcc()){
        $build_fat_java_lib='-DBUILD_FAT_JAVA_LIB=off'
    }
    if($BUILD_INFO.is_msvc()){
        # MSVC �رձ��뾯��
        $env:CXXFLAGS='/wd4819'
        $env:CFLAGS  ='/wd4819'
    }
    # ��������� FFMPEG , cmakeʱ����Ҫָ�� BZIP2_LIBRARIES
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
# cmake��̬���� leveldb(bureau14)Դ��
function build_leveldb(){
    $project=$LEVELDB_INFO
    $install_path=$project.install_path()
    $boost_root=$BOOST_INFO.install_path()
    exit_if_not_exist "$boost_root"  -type Container -msg "not found $boost_root,please build $($BOOST_INFO.prefix)"
    $BUILD_INFO.begin_build()
    if($BUILD_INFO.is_msvc()){
        # MSVC �رձ��뾯��
        $env:CXXFLAGS='/wd4312 /wd4244 /wd4018'
        $env:CFLAGS  ='/wd4312 /wd4244 /wd4018'
    }
    $boost_use_static_runtime=$(if( $BUILD_INFO.msvc_shared_runtime){'off'}else{'on'})
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define()) -DCMAKE_INSTALL_PREFIX=""$install_path""
        -DBOOST_ROOT=`"$boost_root`"
	    -DBoost_NO_SYSTEM_PATHS=on 
        -DBoost_USE_STATIC_RUNTIME=$boost_use_static_runtime
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
# ��̬���� OpenBLAS Դ��,�� MSYS2 �б��룬��Ҫ msys2 ֧��
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
        $mingw_bin= Join-Path $MINGW32_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(û�а�װ mingw32 ������),mingw32 not found,install it by running ./fetch.ps1 mingw32"
        $mingw_version=$MINGW32_INFO.version
    }else{
        $mingw_bin= Join-Path $MINGW64_INFO.root -ChildPath 'bin'
        exit_if_not_exist $mingw_bin -type Container -msg "(û�а�װ mingw64 ������),mingw64 not found,install it by running ./fetch.ps1 mingw64"
        $mingw_version=$MINGW64_INFO.version
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
        $mingw_make install PREFIX=`"$install_path`" NO_LAPACKE=1 NO_SHARED=1"
    $cmd=combine_multi_line "$msys2bash -l -c `"$bashcmd`" 2>&1"
    #$cmd="$msys2bash -where $src_root -l -c `"$bashcmd`" 2>&1"
    Write-Host "(OpenBLAS ������...)compiling OpenBLAS by MinGW $mingw_version ($mingw_bin)" -ForegroundColor Yellow
    cmd /c $cmd
    exit_on_error
}
# cmake��̬���� lmdb Դ��
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
# ���ָ��������Ƿ��Ѿ����밲װ
# ���ȱ�٣��򽫴�����Ϣ��ӵ� $error_msg 
function check_component([string]$folder,[PSObject]$info,[ref][string[]]$error_msg){
    args_not_null_empty_undefined folder info error_msg
    $null=(! (exist_file $folder)) -and ( $error_msg.Value+="(ȱ�� $($info.prefix) ),not found $folder,please build it by running ./build.ps1 $($info.prefix)")
}
# cmake��̬���� caffe ϵ��Դ��
function build_caffe([PSObject]$project){
    args_not_null_empty_undefined project
    if($project.prefix -ne 'caffe'){
        throw "not project caffe based $project"
    }
    $install_path=$project.install_path()
    # ���� check_component �������μ����� caffe ������������Ƿ���ȫ
    # ���������Ϣ������,����check_componentʱ����д����󱣴浽����
    [string[]]$error_message=@()
    check_component $GFLAGS_INFO.install_path() $GFLAGS_INFO ([ref]$error_message)
    check_component $GLOG_INFO.install_path() $GLOG_INFO ([ref]$error_message)
    # hdf5 cmake λ��  
    $hdf5_cmake_dir="$($HDF5_INFO.install_path())/cmake"
    check_component $hdf5_cmake_dir $HDF5_INFO ([ref]$error_message)
    check_component $BOOST_INFO.install_path() $BOOST_INFO ([ref]$error_message)
    check_component $OPENBLAS_INFO.install_path() $OPENBLAS_INFO ([ref]$error_message)
    check_component $PROTOBUF_INFO.install_path() $PROTOBUF_INFO ([ref]$error_message)
    # protobuf lib ·��
    $protobuf_lib="$($PROTOBUF_INFO.install_path())/lib"
    check_component $SNAPPY_INFO.install_path() $SNAPPY_INFO ([ref]$error_message)
    check_component $LMDB_INFO.install_path() $LMDB_INFO ([ref]$error_message)
    check_component $LEVELDB_INFO.install_path() $LEVELDB_INFO ([ref]$error_message)
    # opencv �����ļ�(OpenCVConfig.cmake)����·��
    $opencv_cmake_dir="$($OPENCV_INFO.install_path())"
    check_component $opencv_cmake_dir $OPENCV_INFO ([ref]$error_message)
    # ȱ��������ʱ�����˳�
    if($error_message.count){
        echo $error_message
        exit -1
    }
    $BUILD_INFO.begin_build()
    # ָ�� OpenBLAS ��װ·�� �μ� $caffe_source/cmake/Modules/FindOpenBLAS.cmake
    $env:OpenBLAS_HOME=$OPENBLAS_INFO.install_path()
    # ָ�� lmdb ��װ·�� �μ� $caffe_source/cmake/Modules/FindLMDB.cmake.cmake
    $env:LMDB_DIR=$LMDB_INFO.install_path()
    # ָ�� leveldb ��װ·�� �μ� $caffe_source/cmake/Modules/FindLevelDB.cmake.cmake
    $env:LEVELDB_ROOT=$LEVELDB_INFO.install_path()
    # GLOG_ROOT_DIR �μ� $caffe_source/cmake/Modules/FindGlog.cmake
    # GFLAGS_ROOT_DIR �μ� $caffe_source/cmake/Modules/FindGFlags.cmake
    # HDF5_ROOT �μ� https://cmake.org/cmake/help/v3.8/module/FindHDF5.html
    # BOOST_ROOT,Boost_NO_SYSTEM_PATHS Boost_USE_STATIC_LIBS Boost_USE_STATIC_RUNTIME �μ� https://cmake.org/cmake/help/v3.8/module/FindBoost.html
    # SNAPPY_ROOT_DIR �μ� $caffe_source/cmake/Modules/FindSnappy.cmake
    # COPY_PREREQUISITES=off �ر� windows ��Ԥ��������� �μ� $caffe_source/CMakeLists.txt
    # PROTOBUF_LIBRARY,PROTOBUF_PROTOC_LIBRARY... �μ� https://cmake.org/cmake/help/v3.8/module/FindProtobuf.html
    # OpenCV_DIR �μ�https://cmake.org/cmake/help/v3.8/command/find_package.html
    $lib_suffix=$(if($BUILD_INFO.is_msvc()){'.lib'}else{'.a'})
    if($BUILD_INFO.is_msvc()){
        # MSVC �رձ��뾯��
        $close_warning='/wd4996 /wd4267 /wd4244 /wd4018 /wd4800 /wd4661 /wd4812 /wd4309 /wd4305'
        #if($BUILD_INFO.build_type -eq 'debug'){
        #    $exe_link_opetion='/SAFESEH:NO'
        #}
        
    }
    $boost_use_static_runtime=$(if( $BUILD_INFO.msvc_shared_runtime){'off'}else{'on'})
    # �궨�� /DGOOGLE_GLOG_DLL_DECL= /DGLOG_NO_ABBREVIATED_SEVERITIES ���ڽ�� glog ���ӱ���
    $env:CXXFLAGS="/DGOOGLE_GLOG_DLL_DECL= /DGLOG_NO_ABBREVIATED_SEVERITIES $close_warning"
    $env:CFLAGS  ="/DGOOGLE_GLOG_DLL_DECL= /DGLOG_NO_ABBREVIATED_SEVERITIES $close_warning"
    $cmd=combine_multi_line "$($CMAKE_INFO.exe) .. $($BUILD_INFO.make_cmake_vars_define('','',$exe_link_opetion)) -DCMAKE_INSTALL_PREFIX=""$install_path"" 
        -DCOPY_PREREQUISITES=off
        -DINSTALL_PREREQUISITES=off
	    -DGLOG_ROOT_DIR=`"$($GLOG_INFO.install_path())`"
	    -DGFLAGS_ROOT_DIR=`"$($GFLAGS_INFO.install_path())`" 
	    -DHDF5_ROOT=`"$($HDF5_INFO.install_path())`"
        -DHDF5_USE_STATIC_LIBRARIES=on
	    -DBOOST_ROOT=`"$($BOOST_INFO.install_path())`" 
	    -DBoost_NO_SYSTEM_PATHS=on 
        -DBoost_USE_STATIC_LIBS=on
        -DBoost_USE_STATIC_RUNTIME=$boost_use_static_runtime
	    -DSNAPPY_ROOT_DIR=`"$($SNAPPY_INFO.install_path())`"
	    -DOpenCV_DIR=`"$opencv_cmake_dir`" 
        -DProtobuf_DIR=`"$(Join-Path $PROTOBUF_INFO.install_path() -ChildPath cmake)`"
#	    -DPROTOBUF_LIBRARY=`"$(Join-Path $protobuf_lib -ChildPath "libprotobuf$lib_suffix" )`"
#	    -DPROTOBUF_PROTOC_LIBRARY=`"$(Join-Path $protobuf_lib -ChildPath "libprotoc$lib_suffix")`"
#	    -DPROTOBUF_LITE_LIBRARY=`"$(Join-Path $protobuf_lib -ChildPath "libprotobuf-lite$lib_suffix")`"
#	    -DPROTOBUF_PROTOC_EXECUTABLE=`"$([io.path]::Combine($($PROTOBUF_INFO.install_path()),'bin','protoc.exe'))`"
# PROTOBUF_INCLUDE_DIR �ṩ��·���ָ���������/,��������� cmake ����
#	    -DPROTOBUF_INCLUDE_DIR=`"$($PROTOBUF_INFO.install_path().replace('\','/'))/include`"
	    -DCPU_ONLY=ON 
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
    # �޸����� link.txt ɾ��-lstdc++ ѡ���֤��̬����libstdc++��,������USE_OPENCV=on������£�libstdc++���ᾲ̬����
    if($BUILD_INFO.is_gcc()){
        ls . -Filter link.txt -Recurse|foreach {    
	        echo "modifing file: $_"
	        sed -i -r "s/-lstdc\+\+/ /g" $_
            (Get-Content $_) -replace '(^-lstdc\+\+','' | Out-File $_ -Encoding ascii -Force
        }
    }
    remove_if_exist "$install_path"
    cmd /c "$($BUILD_INFO.make_exe) $($BUILD_INFO.make_exe_option) $($BUILD_INFO.make_install_target) 2>&1"
    exit_on_error
    $BUILD_INFO.end_build()
}
# ���������Ϣ
function print_help(){
    if($(chcp ) -match '\.*936$'){
	    echo "�÷�: $current_script_name [-names] [��Ŀ�����б�,...] [��ѡ��...] 
���밲װָ������Ŀ,���û��ָ����Ŀ���ƣ������������Ŀ
    -n,-names       ��Ŀ�����б�(���ŷָ�,���Դ�Сд,�޿ո�)
                    ��ѡ����Ŀ����: $($all_project_names -join ',') 
ѡ��:
    -c,-compiler    ָ������������,��ѡֵ: vs2013,vs2015,gcc,Ĭ�� auto(�Զ����)
                    ָ��Ϊgccʱ,���û�м�⵽MinGW������,��ʹ�ñ�ϵͳ�Դ���MinGW������
    -a,-arch        ָ��Ŀ���������(x86,x86_64),Ĭ��auto(�Զ����)
    -g,-gcc         ָ��MingGW�������İ�װ·��(bin�ļ���),ָ����ֵ�󣬱���������(-compiler)�Զ�����Ϊgcc
    -r,-revert      ����Ŀǿ��ִ��fetch,����Ŀ����ָ�����ʼ״̬ 
    -msvc_project   ָ��cmake ���ɵ�MSVC�������ͼ����빤��,Ĭ��Ϊ JOM,����ʹ��MSVC����ʱ��Ч
                    nmake: NMake Makefiles ,nmake���̱߳���
                    jom  : NMake Makefiles JOM,jom���б���,CPU����������,��nmake����������ٶ�
                    sln  : Visual Studio����(.sln),msbuild���б���
    -md,-msvc_shared_runtime  
                    MSVC����ʱʹ�� /MD ����ѡ��,Ĭ�� /MT
    -debug          ����Debug�汾,Ĭ��Release
    -build_reserved ����������ɹ����ļ����м��ļ�
    -h,-help        ��ʾ������Ϣ
����: guyadong@gdface.net
"
    }else{
        echo "usage: $current_script_name [-names] [PROJECT_NAME,...] [options...] 
build & install projects specified by project name,
all projects builded if no name argument
    -n,-names       prject names(split by comma,ignore case,without blank)
                    optional project names: $($all_project_names -join ',')

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
                    sln  : Visual Studio����(.sln),parallel build by MSBuild
    -md,-msvc_shared_runtime  
                    use /MD link option,default /MT ,effective only when MSVC
    -debug          Debug building, default is Release
    -build_reserved reserve thd build folder while project building finished
	-h,-help        print the message
author: guyadong@gdface.net
"
    }
}
# ȷ�� $input �е��ַ������ظ���˳���� $available_names �е�һ��,
# �������� $available_names �е��ַ����������
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
# ������Ŀ�б��ַ�������
$all_project_names="gflags glog bzip2 boost leveldb lmdb snappy openblas hdf5 opencv protobuf caffe_windows".Trim() -split '\s+'
# ��ǰ�ű�����
$current_script_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
if($help){
    print_help  
    exit 0
}
# ���̱߳������ make -j 
$MAKE_JOBS=get_logic_core_count
init_build_info
Write-Host ����ϵͳ:$HOST_OS,$HOST_PROCESSOR -ForegroundColor Yellow
Write-Host ����������: -ForegroundColor Yellow
$BUILD_INFO

# û��ָ�� names ����ʱ����������Ŀ
if(! $names){
    $names= $all_project_names
}
# ��Ϊ������Ŀ֮����ǰ��������ϵ,������������������˳���������У�ȷ����ȷ��������ϵ
$names=$names | sorted_project $all_project_names
echo $names| foreach {    
    if( ! (Test-Path function:"build_$($_.ToLower())") -and !($_.StartsWith('caffe'))   ){
        echo "(��ʶ�����Ŀ����)unknow project name:$_"
        print_help
        exit -1
    }
}
$fetch_names=@()
if($revert){
    $fetch_names=$names
}else{
    echo $names| foreach {
        # ���Դ���ļ��в�����,����Ҫfetch����Ŀ   
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
# ˳����� $names ��ָ������Ŀ
echo $names| foreach {
    if($_.StartsWith('caffe')){
        build_caffe(Get-Variable "$($_.ToLower())_INFO" -ValueOnly)
    }else{
        &build_$($_.ToLower())      
    }     
}