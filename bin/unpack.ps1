[CmdletBinding()]
param(
#[Parameter(Mandatory=$true,HelpMessage="����Ҫ��ѹ��ѹ��������(.zip,.gz...)")]
[string]$package,
[string]$targetFolder,
[switch]$quiet,
[switch]$help
)
# ��һ������ִ�г�������ֹ�ű�ִ��,��������ö�ջ��Ϣ
function exit_on_error(){
	if ( ! $? ){
		echo "exit for error:$1 " 
		exit -1
	}
}
# ���� haozip��ѹ�ļ�
function unpack_haozip([string]$exe,[string]$package,[string]$targetFolder){
    $item=Get-Item $exe    
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('HaoZipC'+$item.Extension)
    
    $cmd="""$unpack_exe"" x $package -o$targetFolder -y"
    if( $quiet ){
        # -sn����ֹ�������
        $cmd+=' -sn'
    }    
    cmd /c $cmd
    exit_on_error    
}
# ���� 7z��ѹ�ļ�
function unpack_7z([string]$exe,[string]$package,[string]$targetFolder){
    $item=Get-Item $exe
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('7z'+$item.Extension)
    $cmd="""$unpack_exe"" x $package -o$targetFolder -y"
    if(! $quiet){
        # -bb[0-3] : set output log level
        $cmd+=' -bb1'
    }   
    cmd /c $cmd
    exit_on_error
    if( $package.ToLower().EndsWith('.tar.gz')){        
        $tar=Join-Path -Path $targetFolder -ChildPath (Get-Item $package).BaseName
        $cmd="""$unpack_exe"" x $tar -o$targetFolder -y"
        if(!$quiet){
            $cmd+=' -bb1'
        }   
        cmd /c $cmd
        exit_on_error
        del -Force -Recurse  $tar
        exit_on_error
    }
}

# �鿴��׺Ϊ$suffix���ļ��ı����ļ���������
function find_associated_exe([string]$suffix){
	$Extension,$FileType=(cmd /c assoc $suffix) -split '='
    if(!$FileType){
        Write-Host "�����ֹ�ָ�� `$UNPACK_TOOL ����ָ����ѹ�����,define `$UNPACK_TOOL to fix it"
        exit -1
    }    
    $FileType,$Executable= (cmd /c ftype $FileType) -split '='
    if( ! $Executable ){
        exit -1
    }
    # exe ȫ·��    
   ($Executable -replace '^([^"\s]+|"[^"]+?")(\s.+)?$','$1') -replace '(^"|"$)',''
}
# Ϊ��׺Ϊ$suffixѹ����Ѱ�ҽ�ѹ������
# ��������� $UNPACK_TOOL ������ʹ������Ϊ��ѹ������
# ���� ���� assoc,ftype �����Ҷ�Ӧ�Ľ�ѹ�����ߣ�����Ҳ����ͱ����˳�
function find_unpack_function([string]$suffix){
    if($UNPACK_TOOL){        
        $exe=$UNPACK_TOOL
    }else{
        $exe=find_associated_exe $suffix
    }
    $fun="unpack_"+ ((Get-Item $exe).BaseName.toLower() -replace '^.*(7z|haozip).*$','$1')
    # ���ؽ�ѹ�������� unpack_xxxx
    $fun
    # ���ؽ�ѹ�����������exe�ļ�(ȫ·��)
    $exe
}
# ��ѹ�� $package ָ�����ļ��� $targetFolder
# ��� $targetFolderΪ����Ĭ�Ͻ�ѹ�� $package�����ļ���
function unpack([string]$package,[string]$targetFolder){
    if(! $targetFolder){
        $targetFolder=(Get-Item $package).Directory
    }
    $index=$package.LastIndexOf('.')
    if($index -lt 0){
        # û���ļ���׺���޷�ʶ��,�����˳�
        echo "unkonw file fomat $package"
        exit -1
    }
    if(!( Test-Path -Path $targetFolder -PathType Container)){
        mkdir $targetFolder
        exit_on_error
    }
    $suffix=$package.Substring($index) 
    #if ( $suffix -eq '.zip' ){
    #    unzip $package $targetFolder
    #}else{        
        $fun,$exe=find_unpack_function $suffix
        # ���� unpack_xxxx(haozip|7z)��ѹ
        &$fun $exe $package $targetFolder
    #}
}
# ָ�������ѹ����
# ����ָ����exe����֧�����������еİ汾,
# ����7z�� GUI�汾�Ŀ�ִ���ļ��� 7zfm.exe,�����а汾����7z.exe
# ��ѹ(HaoZip)��GUI�汾�Ŀ�ִ���ļ��� HaoZip.exe,�����а汾���� HaoZipC.exe
# ��������ô�ֵ���ű���ͨ�� assoc,ftype������ң����п��ܲ��Ҳ���
#$UNPACK_TOOL="C:\Program Files\7-Zip\7z.exe"
#$UNPACK_TOOL="C:\Program Files\2345Soft\HaoZip\HaoZipC.exe"
# ���й������Ƿ���ʾ��ʾ��ϸ�Ľ��в���
# ���������Ϣ
function print_help(){
    echo "�÷�: $my_name [��ѡ��...][ѹ�����ļ�]
PowerShell��ѹ�ļ�����

ѡ��:
    -p,-package      Ҫ��ѹ���ļ�(.zip,.tar,.gz...)
	-q,-quiet        ����ʾ��ϸ��Ϣ
	-h,-help        ��ʾ������Ϣ
����: guyadong@gdface.net
"
}
$my_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
if($help){
    print_help  
    exit 0
}
# ���������в�����$package��ѹ��
unpack $package $targetFolder