. "./build_funs.ps1"
#set-executionpolicy remotesigned
#echo (exist_file D:\j\axis2-1.6.2.zip )
#exist_file 
#exit_if_not_exist D:\j\a
#unzip_file -zipFile D:\caffe-static\package\wgetwin-1_5_3_1-binary.zip 
#install_suffix opencv
#md5sum ..\package\boost-1.58.0.tar.gz

# 获取CPU逻辑核心总数
function get_logic_core_count(){
    $cpu=get-wmiobject win32_processor
    return @($cpu).count*$cpu.NumberOfLogicalProcessors
}
$MAKE_JOBS=get_logic_core_count
echo MAKE_JOBS:$MAKE_JOBS
$BIN_ROOT=$(Get-Item $MyInvocation.MyCommand.Definition).Directory
echo BIN_ROOT=$BIN_ROOT
$DEPENDS_ROOT=$BIN_ROOT.Parent.FullName
echo DEPENDS_ROOT=$DEPENDS_ROOT