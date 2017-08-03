# debug����
#$DebugPreference = 'continue'
$DebugPreference = 'SilentlyContinue'
#set-executionpolicy remotesigned 
$BUILD_FUNS_INCLUDED=$true
# ����������ö�ջ
# $index �Ӷ�ջ����ĵڼ���Ԫ�ؿ�ʼ�����Ĭ��Ϊ1,���������ǰ����(call_stack)
function call_stack([int]$index=1){
    [array]$stack=$(Get-PSCallStack)
    $s2=$stack[$index..($stack.Count-1)]
    echo "���ö�ջ:"
    echo $s2 
}
# ���ָ���ĺ�����δ�����򱨴��˳��ű�
function check_defined_function(){
    echo $args| foreach {
        $name=$($_)
        # �ж���Ϊ$name�ı����Ƿ���
        if( ! (Test-Path function:$name) ){
            Write-Host "undefined function: '$name'"
            call_stack 3
            exit -1
        }
    }
}
# ���������
# ���ָ���ı�����δ�����Ϊ�ջ�null�򱨴��˳��ű�
function args_not_null_empty_undefined(){
    echo $args| foreach {
        $name=$($_)
        # �ж���Ϊ$name�ı����Ƿ���
        if( ! (Test-Path variable:$name) ){
            echo "undefined variable: '$name'"
            call_stack 3
            exit -1
        }
        # ��ȡ��Ϊ $name �ı�����ֵ
        $value=(Get-Variable $name).Value
        Write-Debug "name:$name, value:$value"
        if([string]::IsNullOrEmpty( $value)){
            echo "the argument name '$name' must not be null or empty"
            call_stack 3
            exit -1
        }           
    }
}
# ��һ������ִ�г�������ֹ�ű�ִ��,��������ö�ջ��Ϣ
function exit_on_error(){
	if ( ! $? ){
		Write-Host "exit for error:$args "  -ForegroundColor Yellow
        call_stack -index 2
		exit -1
	}
}
# ����ļ�/�ļ��д�����ɾ��,ɾ��ʧ������ֹ�ű�
function remove_if_exist([string]$file){
	if(Test-Path $file){
        Write-Host "(ɾ��)deleting $file" -ForegroundColor Yellow
		del -Force -Recurse  $file
		if( ! $? ){
            Write-Host "(ɾ��ʧ��,�볢���ֹ�ɾ��)failt to delete $file,try delete it manually" -ForegroundColor Red
            call_stack 
			exit -1
		}
	}
}
# ����ļ�/�ļ��д��ڷ��� true,���򷵻� false
function exist_file([string]$file,[Microsoft.PowerShell.Commands.TestPathType]$type="Any"){
    args_not_null_empty_undefined file
	return Test-Path "$file" -PathType $type
}
# ����ļ�/�ļ��в������򱨴��˳�
function exit_if_not_exist([string]$file,[string]$msg,[Microsoft.PowerShell.Commands.TestPathType]$type="Any"){    
	if($msg.Length -eq 0){
        switch($type){
            Leaf {$typeStr="file"}
            Container {$typeStr="directory"}
            Any {$typeStr=""}
        }
		$error_msg="not found $typeStr : $file"
	}else{
		$error_msg=$msg
	}
	if(!$(exist_file $file -type $type)  ){
        Write-Host $error_msg -ForegroundColor Yellow 
        call_stack
        exit -1
    }
}
# ���ָ���ļ��е����ݣ�����ļ��в������򴴽����ļ���
function clean_folder([string]$folder){
    args_not_null_empty_undefined folder
    if(Test-Path $folder){
        Write-Host "(���)clearing $folder" -ForegroundColor Yellow
    	del -Recurse -Force $folder\*
    }else{
        $null=mkdir $folder
    }
	exit_on_error 
}
# ����ļ��в������򴴽����ļ���
function mkdir_if_not_exist([string]$folder){
    args_not_null_empty_undefined folder
	if (!(exist_file -file $folder -type Container)){	
		$null=mkdir $folder
		exit_on_error
	}
}

# �����ļ�md5У��ֵ
function md5sum([string]$file){
    exit_if_not_exist -file $file -type Leaf
    return $(Get-FileHash $file -Algorithm MD5).Hash.ToLower()
}
# ����powershell���ù��ܽ�ѹ�� $package ָ���� zip �ļ��� $targetFolder
# ��� $targetFolderΪ����Ĭ�Ͻ�ѹ�� $package�����ļ���
function unzip([string]$zipFile,[string]$targetFolder){
    args_not_null_empty_undefined zipFile
    exit_if_not_exist $zipFile -type Leaf
    # ����Ƿ�Ϊzip��׺
    if(!$zipFile.ToLower().EndsWith(".zip")){
        echo "$zipFile not zip file"
        call_stack
        exit -1
    }
    # targetFolderΪ��ʱ��ѹ��zipFileͬ���ļ��е�ͬ���ļ���
    if(! $targetFolder){
        $targetFolder=(Get-Item $zipFile).Directory
    }    
    $shellApp = New-Object -ComObject Shell.Application
    $files = $shellApp.NameSpace($zipFile).Items()
	echo "unzip to $targetFolder..."    
    $shellApp.NameSpace($targetFolder).CopyHere($files)
}
# ���� haozip��ѹ�ļ�
function unpack_haozip([string]$exe,[string]$package,[string]$targetFolder){
    args_not_null_empty_undefined exe package targetFolder
    exit_if_not_exist $exe -type Leaf 
    $item=Get-Item $exe    
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('HaoZipC'+$item.Extension)
    exit_if_not_exist $unpack_exe
    $cmd="""$unpack_exe"" x $package -o$targetFolder -y"
    if( ! $VERBOSE_EXTRACT ){
        # -sn����ֹ�������
        $cmd+=' -sn'
    }    
    cmd /c $cmd
    exit_on_error    
}
# ���� 7z��ѹ�ļ�
function unpack_7z([string]$exe,[string]$package,[string]$targetFolder){
    args_not_null_empty_undefined exe package targetFolder
    exit_if_not_exist $exe -type Leaf 
    $item=Get-Item $exe
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('7z'+$item.Extension)
    $cmd="""$unpack_exe"" x $package -o$targetFolder -y"
    if($VERBOSE_EXTRACT){
        # -bb[0-3] : set output log level
        $cmd+=' -bb1'
    }   
    cmd /c $cmd
    exit_on_error
    if( $package -match '.tar.[gx]z$'){        
        $tar=Join-Path -Path $targetFolder -ChildPath (Get-Item $package).BaseName
        $cmd="""$unpack_exe"" x $tar -o$targetFolder -y"
        if($VERBOSE_EXTRACT){
            $cmd+=' -bb1'
        }   
        cmd /c $cmd
        exit_on_error
        remove_if_exist $tar
        exit_on_error
    }
}

# �鿴��׺Ϊ$suffix���ļ��ı����ļ���������
function find_associated_exe([string]$suffix){
	args_not_null_empty_undefined suffix
	$Extension,$FileType=(cmd /c assoc $suffix) -split '='
    if(!$FileType){
        Write-Host "�����ֹ�ָ��build_vars.ps1�е� `$UNPACK_TOOL ����ָ����ѹ�����,define `$UNPACK_TOOL to fix it"
        call_stack
        exit -1
    }    
    $FileType,$Executable= (cmd /c ftype $FileType) -split '='
    if( ! $Executable ){
        call_stack
        exit -1
    }
    # exe ȫ·��    
   ($Executable -replace '^([^"\s]+|"[^"]+?")(\s.+)?$','$1') -replace '(^"|"$)',''
}
# Ϊ��׺Ϊ$suffixѹ����Ѱ�ҽ�ѹ������
# ��������� $UNPACK_TOOL ������ʹ������Ϊ��ѹ������
# ���� ���� get_unpack_cmdexe �����Ҷ�Ӧ�Ľ�ѹ�����ߣ�����Ҳ����ͱ����˳�
function find_unpack_function([string]$suffix){
    if($UNPACK_TOOL){
        exit_if_not_exist $UNPACK_TOOL -type Leaf -msg "(û���ҵ� `$UNPACK_TOOL ָ���������н�ѹ������)not found unpack tool $UNPACK_TOOL"
        $exe=$UNPACK_TOOL
    }else{
        $exe=get_unpack_cmdexe
        if( !$exe ){
            Write-Host "(û���ҵ������н�ѹ������)not found unpack tool,install 7z by running ./fetch.ps1 7z " -ForegroundColor Yellow
            call_stack
            exit -1
        }
    }
    $fun="unpack_"+ ((Get-Item $exe).BaseName.toLower() -replace '^.*(7z|haozip).*$','$1')
    check_defined_function $fun
    exit_if_not_exist $exe -type Leaf -msg "û���ҵ���ѹ������ $exe"
    # ���ؽ�ѹ�������� unpack_xxxx
    $fun
    # ���ؽ�ѹ�����������exe�ļ�(ȫ·��)
    $exe
}
# ��ѹ�� $package ָ�����ļ��� $targetFolder
# ��� $targetFolderΪ����Ĭ�Ͻ�ѹ�� $package�����ļ���
function unpack([string]$package,[string]$targetFolder){
    args_not_null_empty_undefined package targetFolder
    exit_if_not_exist $package -type Leaf
    if(! $targetFolder){
        $targetFolder=(Get-Item $package).Directory
    }
    $index=$package.LastIndexOf('.')
    if($index -lt 0){
        # û���ļ���׺���޷�ʶ��,�����˳�
        echo "unkonw file fomat $package"
        call_stack
        exit -1
    }
    if(!( Test-Path -Path $targetFolder -PathType Container)){
        $null=mkdir $targetFolder 
        exit_on_error
    }
    $suffix=$package.Substring($index) 
    #if ( $suffix -eq '.zip' ){
    #    unzip $package $targetFolder
    #}else{        
        $fun,$exe=find_unpack_function $suffix
        # ���� unpack_(haozip|7z)������ѹ
        &$fun $exe $package $targetFolder
    #}
}
function get_installed_softwares
{
    #
    # Read registry key as product entity.
    #
    function ConvertTo-ProductEntity
    {
        param([Microsoft.Win32.RegistryKey]$RegKey)
        $product = '' | select Name,Publisher,Version,Location,UninstallString
        $product.Name =  $_.GetValue("DisplayName")
        $product.Publisher = $_.GetValue("Publisher")
        $product.Version =  $_.GetValue("DisplayVersion")
        $product.Location= $_.GetValue("InstallLocation")
        $product.UninstallString=$_.GetValue("UninstallString")
        if( -not [string]::IsNullOrEmpty($product.Name)){
            $product
        }
    }

    $UninstallPaths = @(,
    # For local machine.
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    # For current user.
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall')

    # For 32bit softwares that were installed on 64bit operating system.
    if([Environment]::Is64BitOperatingSystem) {
        $UninstallPaths += 'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    }
    $UninstallPaths | foreach {
        Get-ChildItem $_ | foreach {
            ConvertTo-ProductEntity -RegKey $_
        }
    }
}
# $system_firstΪ$trueʱ����������ϵͳ��װ��msys2,����ֱ��ʹ���Դ��� msys2
# ��ȡע����ز��� msys2
# ����ҵ����ͷ�ϵͳ��msys2�İ�װ·��
# ���û�ҵ�����ʹ���Դ��� msys2
function get_msys2_location(){
    if($system_first){
        foreach($r in (get_installed_softwares | Where-Object {$_.name -match 'msys2'})){
            if(Test-Path (Join-Path $r.Location,'bin' -ChildPath 'msys2_shell.cmd') -PathType Leaf){
                return $r.Location
            }
        }
    }
    if( $MSYS2_INFO -and (Test-Path $MSYS2_INFO.root -PathType Container)){
        return $MSYS2_INFO.root
    }
}
# $system_firstΪ$trueʱ����������ϵͳ��װ�Ľ�ѹ�����,����ֱ��ʹ���Դ���7z
# ��ȡע����ز��� haozip��7z
# ����ҵ����ͷ��ض�Ӧ�������ѹ�������ȫ·��
# ���û�ҵ�����ʹ���Դ��� 7z
function get_unpack_cmdexe(){
    if($system_first){
        foreach($r in (get_installed_softwares | Where-Object {$_.name -match '(HaoZip|��ѹ|7-zip)'})){
            switch -regex ($r){
                '(��ѹ|haozip)'{ $cmdexe=Join-Path (ls $r.UninstallString).Directory -ChildPath 'HaoZipC.exe';}
                '(7-zip|7z)' { $cmdexe=Join-Path $r.Location -ChildPath '7z.exe';}
                Default { throw "(�ڲ��쳣����ʶ���������� )unknow software name:$($r.Name)"}
            }
            if(Test-Path $cmdexe -PathType Leaf){
                return $cmdexe
            }
        }
    }
    # �����Դ��� 7z ����ѹ����
    $cmdexe=[io.path]::Combine($7Z_INFO.root,'7z.exe')
    if( Test-Path $cmdexe -PathType Leaf){
        return $cmdexe
    }
}
function find_installed_software($name){
    args_not_null_empty_undefined name
    (get_installed_softwares | Where-Object {$_.name -match $name})
}
# �� windows ·��תΪ unix��ʽ
function unix_path($path){
    ($path -replace '^([a-z]):','/$1').Replace('\','/')
}
# ��ȡCPU�߼���������
function get_logic_core_count(){
    $cpu=Get-CimInstance win32_processor
    return @($cpu).count*$cpu.NumberOfLogicalProcessors
}
#find_installed_software '(��ѹ|7-zip)'
#find_installed_software '7-zip'
#get_installed_softwares
#get_unpack_cmdexe