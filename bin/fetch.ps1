. "./build_vars.ps1"
<#
下载caffe-ssd及其所有依赖库的源码以及cmake工具，
下载的源码压缩包存放在 $PACKAGE_ROOT 文件夹下
并解压缩到 $SOURCE_ROOT 文件夹下，
如果压缩已经存在则跳过下载直接解压缩
#>

# $file 待检查的文件路径
# $md5 md5校验码
# 如果$file不存在 返回$true
# 如果$file是文件夹则报错退出
# 如果$file存在且checksum与$2指定的md5相等则返回 $false,否则返回$true
# 如果$file存在且md5为空时，由全局变量$FORCE_DOWNLOAD_IF_EXIST决定是否需要下载
function need_download([string]$file,[string]$md5){
    args_not_null_empty_undefined file 
	if (Test-Path $file -PathType Leaf){
		if($md5){
			echo "File already exists. Checking md5..."
			if($HOST_OS -eq "windows"){
				$checksum=(md5sum $file)
			}else{
				$os=$(uname -s)
				if ( $os -eq "Linux" ){
					$checksum=$(md5sum $file | awk '{ print $1 }')
				}elseif ( $os -eq "Darwin" ){
					$checksum=$(cat $file | md5)
				}
				exit_on_error
			}
			if ( $checksum -eq  $md5){
				echo "Checksum is correct. No need to download $file."
				return $false
			}else{
				echo "Checksum is incorrect. Need to download again $file"
				return $true
			}
		}else{
			return $FORCE_DOWNLOAD_IF_EXIST
		}
	}elseif (Test-Path $file -PathType Container){
		# $file是文件夹则报错退出
		echo "invalid argument: package=$file is a folder!!!"
		call_stack
		exit -1
	}else{
		return $true
	}
}

# 从github上下载源码
# 如果本地不存在指定的zip包，或$md5为空或$md5校验码不匹配则从github下载
# 如果本地存在指定的zip包，且$md5为空,则根据$FORCE_DOWNLOAD_IF_EXIST决定是否跳过下载直接解压
# $1 项目名称
function fetch_from_github([string]$project){
	args_not_null_empty_undefined project
	$name=$project.ToUpper()+"_INFO"	
	$info=(Get-Variable -Name $name).Value
	# $project类型必须是
	if(!($info -is [PSObject])){
		echo 'invalid argument: $project must be [PSObject]'
		call_stack
		exit -1
	}
	$package=$info.folder+".zip"
	$package_path=Join-Path $PACKAGE_ROOT $package
	$source_path=Join-Path $SOURCE_ROOT $info.folder
	if( (need_download $package_path $info.md5)[-1] ){	
		Write-Host "(下载源码)downloading" $info.prefix $info.version source
		remove_if_exist $package_path
        $url='https://github.com',$info.owner,$info.prefix,'archive',($info.package_prefix+$info.version+'.zip') -join '/'        
        Invoke-WebRequest -Uri $url -OutFile $package_path 
   		#&$WGET $url -O $package_path
		exit_on_error
	}
	remove_if_exist $source_path
	echo "(解压缩文件)extracting file from $package_path"
	unzip $package_path -targetFolder $SOURCE_ROOT	
	exit_on_error
	$remot_name=$info.prefix+'-'+$info.package_prefix+$info.version
	$unpack_folder=Join-Path $SOURCE_ROOT $remot_name
	if( $info.package_prefix -and (Test-Path $unpack_folder -PathType Container)){
		Write-Host rename $remot_name to $info.folder
        pushd $SOURCE_ROOT
        Rename-Item -Path $remot_name -NewName $info.folder
        exit_on_error
        popd		
	}
}
$FORCE_DOWNLOAD_IF_EXIST=$false
fetch_from_github glog
fetch_from_github lmdb
fetch_from_github snappy