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
    gcc_project=$gcc_project
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
    # make ���߱���ʱ��Ĭ��ѡ��
    make_exe_option=""
    # install ��������,ʹ��msbuild����msvc����ʱ����Ϊ'INSTALL.vcxproj'
    make_install_target='install'
    # ��������
    build_type=$(if($debug){'debug'}else{'release'})
    # ��Ŀ����ɹ����Ƿ���� build�ļ���
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
    param([string[]]$sub_folders,[switch]$no_build,[string]$project_root)
    args_not_null_empty_undefined project
    Write-Host "(��ʼ����)building $($project.prefix) $($project.version)" -ForegroundColor Yellow
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
            $gxx_exe='g++.exe'
            #$gcc_exe='i686-w64-mingw32-gcc.exe'
            #$gxx_exe='i686-w64-mingw32-g++.exe'
            if($BUILD_INFO.gcc_location){
                $gcc_exe=Join-Path $BUILD_INFO.gcc_location -ChildPath $gcc_exe
            }else{
                $gcc_exe=where_first $gcc_exe
                if(!$gcc_exe){
                    # ���ϵͳ��û�м�⵽ gcc ��������ʹ���Դ��� mingw ������
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
                default{ call_stack; throw "(��Ч��������)invalid project type:$($BUILD_INFO.gcc_project)"}
                }
                exit_if_not_exist $BUILD_INFO.gcc_cxx_compiler -type Leaf -msg "(û�ҵ�g++������)not found g++ in $BUILD_INFO.gcc_location"
                $BUILD_INFO.cmake_vars_define="-G `"$generator`" -DCMAKE_C_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_c_compiler)"" -DCMAKE_CXX_COMPILER:FILEPATH=""$($BUILD_INFO.gcc_cxx_compiler)"" -DCMAKE_BUILD_TYPE:STRING=$($BUILD_INFO.build_type)"
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
    if($BUILD_INFO.gcc_location -and $BUILD_INFO.compiler -ne 'gcc'){        
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
    }elseif($BUILD_INFO.is_msvc()){
        ignore_arguments_by_compiler gcc_project gcc_location,gcc
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