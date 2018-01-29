[CmdletBinding()]
param(
#[Parameter(Mandatory=$true,HelpMessage="输入要解压的压缩包名称(.zip,.gz...)")]
[string]$package,
[string]$targetFolder,
[switch]$quiet,
[switch]$help
)
# 上一条命令执行出错则中止脚本执行,并输出调用堆栈信息
function exit_on_error(){
	if ( ! $? ){
		echo "exit for error:$1 " 
		exit -1
	}
}
# 调用 haozip解压文件
function unpack_haozip([string]$exe,[string]$package,[string]$targetFolder){
    $item=Get-Item $exe    
    $unpack_exe=Join-Path -Path $item.Directory -ChildPath ('HaoZipC'+$item.Extension)
    
    $cmd="""$unpack_exe"" x $package -o$targetFolder -y"
    if( $quiet ){
        # -sn：禁止文字输出
        $cmd+=' -sn'
    }    
    cmd /c $cmd
    exit_on_error    
}
# 调用 7z解压文件
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

# 查看后缀为$suffix的文件的本机文件关联程序
function find_associated_exe([string]$suffix){
	$Extension,$FileType=(cmd /c assoc $suffix) -split '='
    if(!$FileType){
        Write-Host "请用手工指定 `$UNPACK_TOOL 变量指定解压缩软件,define `$UNPACK_TOOL to fix it"
        exit -1
    }    
    $FileType,$Executable= (cmd /c ftype $FileType) -split '='
    if( ! $Executable ){
        exit -1
    }
    # exe 全路径    
   ($Executable -replace '^([^"\s]+|"[^"]+?")(\s.+)?$','$1') -replace '(^"|"$)',''
}
# 为后缀为$suffix压缩包寻找解压缩工具
# 如果定义了 $UNPACK_TOOL 则优先使用它做为解压缩工具
# 否则 调用 assoc,ftype 来查找对应的解压缩工具，如果找不到就报错退出
function find_unpack_function([string]$suffix){
    if($UNPACK_TOOL){        
        $exe=$UNPACK_TOOL
    }else{
        $exe=find_associated_exe $suffix
    }
    $fun="unpack_"+ ((Get-Item $exe).BaseName.toLower() -replace '^.*(7z|haozip).*$','$1')
    # 返回解压缩函数名 unpack_xxxx
    $fun
    # 返回解压缩工具软件的exe文件(全路径)
    $exe
}
# 解压缩 $package 指定的文件到 $targetFolder
# 如果 $targetFolder为空则默认解压到 $package所在文件夹
function unpack([string]$package,[string]$targetFolder){
    if(! $targetFolder){
        $targetFolder=(Get-Item $package).Directory
    }
    $index=$package.LastIndexOf('.')
    if($index -lt 0){
        # 没有文件后缀，无法识别,报错退出
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
        # 调用 unpack_xxxx(haozip|7z)解压
        &$fun $exe $package $targetFolder
    #}
}
# 指定命令解压工具
# 这里指定的exe，是支持命令行运行的版本,
# 比如7z的 GUI版本的可执行文件是 7zfm.exe,命令行版本则是7z.exe
# 好压(HaoZip)的GUI版本的可执行文件是 HaoZip.exe,命令行版本则是 HaoZipC.exe
# 如果不设置此值，脚本会通过 assoc,ftype命令查找，但有可能查找不到
#$UNPACK_TOOL="C:\Program Files\7-Zip\7z.exe"
#$UNPACK_TOOL="C:\Program Files\2345Soft\HaoZip\HaoZipC.exe"
# 运行过程中是否显示显示详细的进行步骤
# 输出帮助信息
function print_help(){
    echo "用法: $my_name [可选项...][压缩包文件]
PowerShell解压文件工具

选项:
    -p,-package      要解压的文件(.zip,.tar,.gz...)
	-q,-quiet        不显示详细信息
	-h,-help        显示帮助信息
作者: guyadong@gdface.net
"
}
$my_name=$($(Get-Item $MyInvocation.MyCommand.Definition).Name)
if($help){
    print_help  
    exit 0
}
# 根据命令行参数对$package解压缩
unpack $package $targetFolder