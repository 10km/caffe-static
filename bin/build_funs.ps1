# debug开关
#$DebugPreference = 'continue'
$DebugPreference = 'SilentlyContinue'
#set-executionpolicy remotesigned 
# 输出函数调用堆栈
# $index 从堆栈数组的第几个元素开始输出，默认为1,即不输出当前函数(call_stack)
function call_stack([int]$index=1){
    [array]$stack=$(Get-PSCallStack)
    $s2=$stack[$index..($stack.Count-1)]
    echo "调用堆栈:"
    echo $s2 
}
# 如果指定的函数名未定义则报错退出脚本
function check_defined_function(){
    echo $args| foreach {
        $name=$($_)
        # 判断名为$name的变量是否定义
        if( ! (Test-Path function:$name) ){
            Write-Host "undefined function: '$name'"
            call_stack 3
            exit -1
        }
    }
}
# 变量名检查
# 如果指定的变量名未定义或为空或null则报错退出脚本
function args_not_null_empty_undefined(){
    echo $args| foreach {
        $name=$($_)
        # 判断名为$name的变量是否定义
        if( ! (Test-Path variable:$name) ){
            echo "undefined variable: '$name'"
            call_stack 3
            exit -1
        }
        # 获取名为 $name 的变量的值
        $value=(Get-Variable $name).Value
        Write-Debug "name:$name, value:$value"
        if([string]::IsNullOrEmpty( $value)){
            echo "the argument name '$name' must not be null or empty"
            call_stack 3
            exit -1
        }           
    }
}
# 上一条命令执行出错则中止脚本执行,并输出调用堆栈信息
function exit_on_error(){
	if ( ! $? ){
		echo "exit for error:$1 " 
        call_stack -index 2
		exit -1
	}
}
# 如果文件/文件夹存在则删除,删除失败则中止脚本
function remove_if_exist([string]$file){
	if(Test-Path $file){
		del -Force -Recurse  $file
		if( ! $? ){
            call_stack 
			exit -1
		}
	}
}
# 如果文件/文件夹存在返回 true,否则返回 false
function exist_file([string]$file,[Microsoft.PowerShell.Commands.TestPathType]$type="Any"){
    args_not_null_empty_undefined file
	return Test-Path "$file" -PathType $type
}
# 如果文件/文件夹不存在则报错退出
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
# 清除指定文件夹的内容，如果文件夹不存在则创建空文件夹
function clean_folder([string]$folder){
    args_not_null_empty_undefined folder
    if(Test-Path $folder){
    	del -Recurse -Force $folder\*
    }else{
        mkdir $folder
    }
	exit_on_error 
}
# 如果文件夹不存在则创建空文件夹
function mkdir_if_not_exist([string]$folder){
    args_not_null_empty_undefined folder
	if (!(exist_file -file $folder -type Container)){	
		mkdir $folder
		exit_on_error
	}
}

# 计算文件md5校验值
function md5sum([string]$file){
    exit_if_not_exist -file $file -type Leaf
    return $(Get-FileHash $file -Algorithm MD5).Hash.ToLower()
}
# 调用powershell内置功能解压缩 $package 指定的 zip 文件到 $targetFolder
# 如果 $targetFolder为空则默认解压到 $package所在文件夹
function unzip([string]$zipFile,[string]$targetFolder){
    args_not_null_empty_undefined zipFile
    exit_if_not_exist $zipFile -type Leaf
    # 检查是否为zip后缀
    if(!$zipFile.ToLower().EndsWith(".zip")){
        echo "$zipFile not zip file"
        call_stack
        exit -1
    }
    # targetFolder为空时解压到zipFile同级文件夹的同名文件夹
    if(! $targetFolder){
        $targetFolder=(Get-Item $zipFile).Directory
    }    
    $shellApp = New-Object -ComObject Shell.Application
    $files = $shellApp.NameSpace($zipFile).Items()
	echo "unzip to $targetFolder..."
    $shellApp.NameSpace($targetFolder).CopyHere($files)
}
# 调用 haozip解压文件
function unpack_haozip([string]$exe,[string]$package,[string]$targetFolder){
    args_not_null_empty_undefined exe package targetFolder
    exit_if_not_exist $exe -type Leaf 
    $item=Get-Item $exe    
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('HaoZipC'+$item.Extension)
    exit_if_not_exist $unpack_exe
    $cmd="""$unpack_exe"" x $package -o$targetFolder"
    cmd /c $cmd
    exit_on_error    
}
# 调用 7z解压文件
function unpack_7z([string]$exe,[string]$package,[string]$targetFolder){
    args_not_null_empty_undefined exe package targetFolder
    exit_if_not_exist $exe -type Leaf 
    $item=Get-Item $exe
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('7z'+$item.Extension)
    $cmd="""$unpack_exe"" x $package -o$targetFolder"
    cmd /c $cmd
    exit_on_error
    if( $package.ToLower().EndsWith('.tar.gz')){        
        $tar=Join-Path -Path $targetFolder -ChildPath (Get-Item $package).BaseName
        $cmd="""$unpack_exe"" x $tar -o$targetFolder"
        cmd /c $cmd
        exit_on_error
        remove_if_exist $tar
        exit_on_error
    }
}

# 查看后缀为$suffix的文件的本机文件关联程序
function find_associated_exe([string]$suffix){
	args_not_null_empty_undefined suffix
	$Extension,$FileType=(cmd /c assoc $suffix) -split '='
    if(!$FileType){
        Write-Host "请用手工指定 `$UNPACK_TOOL 变量指定解压缩软件,define `$UNPACK_TOOL to fix it"
        call_stack
        exit -1
    }    
    $FileType,$Executable= (cmd /c ftype $FileType) -split '='
    if( ! $Executable ){
        call_stack
        exit -1
    }
    # exe 全路径    
   ($Executable -replace '^([^"\s]+|"[^"]+?")(\s.+)?$','$1') -replace '(^"|"$)',''
}
# 为后缀为$suffix压缩包寻找解压缩工具
function find_unpack_function([string]$suffix){
    if($UNPACK_TOOL){
        exit_if_not_exist $UNPACK_TOOL -type Leaf -msg "没有找到 `$UNPACK_TOOL 指定的命令行解压缩工具 $UNPACK_TOOL"
        $exe=$UNPACK_TOOL
    }else{
        $exe=find_associated_exe $suffix
    }
    $fun="unpack_"+ ((Get-Item $exe).BaseName.toLower() -replace '^.*(7z|haozip).*$','$1')
    check_defined_function $fun
    # 返回解压缩函数名 unpack_xxxx
    $fun
    # 返回解压缩工具软件的exe文件(全路径)
    $exe
}
# 解压缩 $package 指定的文件到 $targetFolder
# 如果 $targetFolder为空则默认解压到 $package所在文件夹
function unpack([string]$package,[string]$targetFolder){
    args_not_null_empty_undefined package targetFolder
    if(! $targetFolder){
        $targetFolder=(Get-Item $zipFile).Directory
    }
    $index=$package.LastIndexOf('.')
    if($index -lt 0){
        # 没有文件后缀，无法识别,报错退出
        echo "unkonw file fomat $package"
        call_stack
        exit -1
    }
    $suffix=$package.Substring($index) 
    if ( $suffix -eq '.zip' ){
        unzip $package $targetFolder
    }else{        
        $fun,$exe=find_unpack_function $suffix
        &$fun $exe $package $targetFolder
    }
}