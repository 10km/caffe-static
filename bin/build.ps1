param(
[ValidateSet('auto','vs2015','vs2013','gcc')]
[string]$compiler='auto',
[ValidateSet('auto','x86','x86_64')]
[string]$arch='auto',
[string]$gcc=$DEFAULT_GCC,
[switch]$help
)
. "./build_vars.ps1"
function check_cmd_args(
    [ValidateSet('auto','vs2015','vs2013','gcc')][string]$compiler,
    [ValidateSet('auto','x86','x86_64')][string]$arch,
    [string]$gcc){
    if($gcc ){
        exit_if_not_exist $gcc -type Leaf -msg "指定的gcc编译器不存在"
        $compiler='gcc'
    }
    if($gcc -and $compiler -ne 'gcc' ){
        echo '只有-compiler 为'gcc'时,才能指定-gcc参数'
        exit -1
    }
}

function check_vs2013(){
}
function check_g2015(){
}
function check_gcc(){

}
