# 如果文件/文件夹存在则删除,删除失败则中止脚本
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
		# 参数错误，退出
		echo invalid argument:
		echo $*
		exit -1
	}
}
# 如果文件/文件夹存在返回 true,否则返回 false
Function exit_file(){
	param([string]$File)
	if ( $args.Count -eq 1 ){
		return Test-Path $File
	}else{
		# 参数错误，退出
		echo invalid argument:
		echo $*
		exit -1
	}
}
# 如果文件/文件夹不存在则报错退出
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
    #确保目标文件夹必须存在,目标文件夹存在 则清空文件夹
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