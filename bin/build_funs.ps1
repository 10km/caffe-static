# ����ļ�/�ļ��д�����ɾ��,ɾ��ʧ������ֹ�ű�
Function remove_if_exist(){
	param([string]$File)
	if($args.Count -eq 1){
		if(Test-Path $File){
			del -Force -Recurse $File
			if( $? -ne 0){
				exit -1
			}
		}
		return 0
	}else {
		# ���������˳�
		echo invalid argument:
		echo $*
		exit -1
	}
}
# ����ļ�/�ļ��д��ڷ��� true,���򷵻� false
Function exit_file(){
	param([string]$File)
	if ( $args.Count -eq 1 ){
		return Test-Path $File
	}else{
		# ���������˳�
		echo invalid argument:
		echo $*
		exit -1
	}
}
# ����ļ�/�ļ��в������򱨴��˳�
Function exit_if_not_exist(){
	param([string]$File,[string]$msg)
	if([String]::IsNullOrEmpty()){
		error_msg="not found: $File"
	}else{
		error_msg=$msg
	}
	exit_file $File 
	exit_on_error "$error_msg"
}
Function unzip_file()
{
    param([string]$ZipFile,[string]$TargetFolder)
    #ȷ��Ŀ���ļ��б������,Ŀ���ļ��д��� ������ļ���
    if(!(Test-Path $TargetFolder))
    {
        mkdir $TargetFolder
    }else{
    	del -Recurse -Force $TargetFolder\*
    }
    $shellApp = New-Object -ComObject Shell.Application
    $files = $shellApp.NameSpace($ZipFile).Items()
    $shellApp.NameSpace($TargetFolder).CopyHere($files)
}
unzip_file -ZipFile d:\caffe-static\package\wgetwin-1_5_3_1-binary.zip -TargetFolder d:\caffe-static\tools\wget