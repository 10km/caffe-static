. "./build_funs.ps1"
#set-executionpolicy remotesigned
#echo (exist_file D:\j\axis2-1.6.2.zip )
#exist_file 
#exit_if_not_exist D:\j\a
#unzip_file -zipFile D:\caffe-static\package\wgetwin-1_5_3_1-binary.zip 
#install_suffix opencv
#md5sum ..\package\boost-1.58.0.tar.gz
#$Modules= Join-Path (Join-Path 'C:\Program Files' WindowsPowerShell) -ChildPath Modules 
#$Modules=Join-Path 'C:\Program Files' WindowsPowerShell | Join-Path -ChildPath Modules 
#$Modules=[io.path]::combine('C:\Program Files',"WindowsPowerShell","Modules","txt")
#$Modules
function unpack_haozip($exe,$package,$targetFolder){
    $item=Get-Item $exe    
    $haozipc=Join-Path -Path $item.Directory -ChildPath ($item.BaseName+'C'+$item.Extension)
    $cmd="""$haozipc"" x $package -o$targetFolder"
    cmd /c $cmd
    exit_on_error    
}
# 查看后缀为$suffix的文件的本机文件关联程序
function find_associated_exe([string]$suffix){
	args_not_null_empty_undefined suffix
	$Extension,$FileType=(cmd /c assoc $suffix) -split '='
    if(!$Extension -or !$FileType){
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

function find_unpack_function([string]$suffix){
    $exe=find_associated_exe $suffix
    $fun="unpack_"+ (Get-Item $exe).BaseName.toLower()
    check_defined_function $fun
    $fun
    $exe
}
$fun,$exe=find_unpack_function .gz

&$fun $exe d:\caffe-static\package\hdf5-1.8.16.tar.gz d:\caffe-static\package\t