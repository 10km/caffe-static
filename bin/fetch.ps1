. "./build_vars.ps1"
<#
����caffe-ssd���������������Դ���Լ�cmake���ߣ�
���ص�Դ��ѹ��������� $PACKAGE_ROOT �ļ�����
����ѹ���� $SOURCE_ROOT �ļ����£�
���ѹ���Ѿ���������������ֱ�ӽ�ѹ��
#>

# $file �������ļ�·��
# $md5 md5У����
# ���$file������ ����$true
# ���$file���ļ����򱨴��˳�
# ���$file������checksum��$2ָ����md5����򷵻� $false,���򷵻�$true
# ���$file������md5Ϊ��ʱ����ȫ�ֱ���$FORCE_DOWNLOAD_IF_EXIST�����Ƿ���Ҫ����
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
		# $file���ļ����򱨴��˳�
		echo "invalid argument: package=$file is a folder!!!"
		call_stack
		exit -1
	}else{
		return $true
	}
}

# ��github������Դ��
# ������ز�����ָ����zip������$md5Ϊ�ջ�$md5У���벻ƥ�����github����
# ������ش���ָ����zip������$md5Ϊ��,�����$FORCE_DOWNLOAD_IF_EXIST�����Ƿ���������ֱ�ӽ�ѹ
# $project ��Ŀ����(�����ִ�Сд)
function fetch_from_github([string]$project){
	args_not_null_empty_undefined project
	$name=$project.ToUpper()+"_INFO"	
	$info=(Get-Variable -Name $name).Value
	# $project���ͱ�����
	if(!($info -is [PSObject])){
		echo 'invalid argument: $project must be [PSObject]'
		call_stack
		exit -1
	}
	$package=$info.folder+".zip"
	$package_path=Join-Path $PACKAGE_ROOT $package
	$source_path=Join-Path $SOURCE_ROOT $info.folder
	if( (need_download $package_path $info.md5)[-1] ){	
		Write-Host "(����Դ��)downloading" $info.prefix $info.version source
		remove_if_exist $package_path
        $url='https://github.com',$info.owner,$info.prefix,'archive',($info.package_prefix+$info.version+'.zip') -join '/'        
        Invoke-WebRequest -Uri $url -OutFile $package_path 
   		#&$WGET $url -O $package_path
		exit_on_error
	}
	remove_if_exist $source_path
	echo "(��ѹ���ļ�)extracting file from $package_path"
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

function download_and_extract([string]$project,[string]$url,[string]$remote_prefix){
	$package=$BOOST_INFO.folder + $BOOST_INFO.package_suffix
	$package_path=Join-Path $PACKAGE_ROOT $package
	$source_path=Join-Path $SOURCE_ROOT $info.folder
	if( (need_download $package_path $info.md5)[-1] ){	
		remove_if_exist $package_path
		echo "${FUNCNAME[0]}:(����Դ��)downloading $version $version source"
		Invoke-WebRequest -Uri $url -OutFile $package_path 
		exit_on_error
	}
	remove_if_exist $source_path
	echo "(��ѹ���ļ�)extracting file from $package_path"
	if ($project.package_suffix -ceq '.zip'){
		unzip $package_path -targetFolder $SOURCE_ROOT	
	}elseif($project.package_suffix -ceq '.tar.gz'){
	}	
	exit_on_error
}
###################################################
function fetch_boost(){

	$package=$BOOST_INFO.folder + ".tar.gz"
	$remote_prefix=$BOOST_INFO.prefix+'_'+$BOOST_INFO.version.Replace('.','_')
	$package_path=Join-Path $PACKAGE_ROOT $package
	$source_path=Join-Path $SOURCE_ROOT $info.folder
	if( (need_download $package_path $info.md5)[-1] ){	
		remove_if_exist $package_path
		Write-Host "(����)downloading" $info.prefix $info.version
		wget --no-check-certificate https://nchc.dl.sourceforge.net/project/boost/boost/$version/$remote_prefix.tar.gz -O $PACKAGE_ROOT/$package
		exit_on_error
	}
	remove_if_exist $SOURCE_ROOT/$folder
	echo "(��ѹ���ļ�)extracting file from $PACKAGE_ROOT/$package"
	tar zxf$VERBOSE_EXTRACT $PACKAGE_ROOT/$package -C $SOURCE_ROOT
	mv $SOURCE_ROOT/$remote_prefix $SOURCE_ROOT/$folder
	exit_on_error
}
function modify_snappy(){}
function modify_ssd(){}

$FORCE_DOWNLOAD_IF_EXIST=$false
function fetch_protobuf(){ fetch_from_github "protobuf" ; }
function fetch_gflags(){ fetch_from_github "gflags" ; }
function fetch_glog(){ fetch_from_github "glog" ; }
function fetch_leveldb(){ fetch_from_github "leveldb" ; }
function fetch_lmdb(){ fetch_from_github "lmdb" ; }
function etch_snappy(){ fetch_from_github "snappy" ; modify_snappy ; }
function fetch_openblas(){ fetch_from_github "OpenBLAS" ; }
function fetch_ssd(){ fetch_ssd_zip ; modify_ssd; }
function fetch_opencv(){ fetch_from_github "opencv" ; }
function fetch_bzip2(){ fetch_bzip2_1_0_5 ; }

#fetch_from_github glog
#fetch_from_github lmdb
#fetch_from_github snappy