# debug����
#$DebugPreference = 'continue'
$DebugPreference = 'SilentlyContinue'
#set-executionpolicy remotesigned 
# ����������ö�ջ
# $index �Ӷ�ջ����ĵڼ���Ԫ�ؿ�ʼ�����Ĭ��Ϊ1,���������ǰ����(call_stack)
function call_stack([int]$index=1){
    [array]$stack=$(Get-PSCallStack)
    $s2=$stack[$index..($stack.Count-1)]
    echo "���ö�ջ:"
    echo  $s2 
}
# ���ָ���ĺ�����δ�����򱨴��˳��ű�
function check_defined_function(){
    echo $args| foreach {
        $name=$($_)
        # �ж���Ϊ$name�ı����Ƿ���
        if( ! (Test-Path function:$name) ){
            echo "undefined function: '$name'"
            call_stack 2
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
		echo "exit for error:$1 " 
        call_stack -index 2
		exit -1
	}
}
# ����ļ�/�ļ��д�����ɾ��,ɾ��ʧ������ֹ�ű�
function remove_if_exist([string]$file){
	if(Test-Path $file){
		del -Force -Recurse  $file
		if( ! $? ){
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
        echo $error_msg
        call_stack
        exit -1
    }
}
# ���ָ���ļ��е����ݣ�����ļ��в������򴴽����ļ���
function clean_folder([string]$folder){
    args_not_null_empty_undefined folder
    if(Test-Path $folder){
    	del -Recurse -Force $folder\*
    }else{
        mkdir $folder
    }
	exit_on_error 
}
# ����ļ��в������򴴽����ļ���
function mkdir_if_not_exist([string]$folder){
    args_not_null_empty_undefined folder
	if (!(exist_file -file $folder -type Container)){	
		mkdir $folder
		exit_on_error
	}
}

# �����ļ�md5У��ֵ
function md5sum([string]$file){
    exit_if_not_exist -file $file -type Leaf
    return $(Get-FileHash $file -Algorithm MD5).Hash.ToLower()
}
function unzip([string]$zipFile,[string]$targetFolder)
{
    exit_if_not_exist $zipFile -type Leaf
    # ����Ƿ�Ϊzip��׺
    if(!$zipFile.EndsWith(".zip")){
        echo "$zipFile not zip file"
        call_stack
        exit -1
    }
    # targetFolderΪ��ʱ��ѹ��zipFileͬ���ļ��е�ͬ���ļ���
    if(! $targetFolder){
        $targetFolder=(Get-Item $zipFile).Directory
    }    
    #ȷ��Ŀ���ļ��б������,Ŀ���ļ��д��� ������ļ���
    #clean_folder -folder $targetFolder
    $shellApp = New-Object -ComObject Shell.Application
    $files = $shellApp.NameSpace($zipFile).Items()
	echo "unzip to $targetFolder..."
    $shellApp.NameSpace($targetFolder).CopyHere($files)
}
