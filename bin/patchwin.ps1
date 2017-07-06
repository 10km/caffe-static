<#
对cmake脚本分析自动完成已知补丁代码更新
author: guyadong@gdface.net
#>
if(!$BUILD_VARS_INCLUDED){
. "$PSScriptRoot/build_funs.ps1"
}

# 在文本文件中用正则表达式搜索替换字符串并将修改后的内容回写到文件中,
# 并显示修改前后内容比较
function regex_replace_file($text_file,$regex,$replace,$msg,[switch]$join){
    args_not_null_empty_undefined text_file regex 
    exit_if_not_exist $text_file -type Leaf 
    if( ! $msg ){
        $msg="modify $text_file"
    }
    $content=Get-Content $text_file
    if( $join ){
        $content=$content -join "`n"
    }
    $res=$content -match $regex
    if( $res){
        if($content -is [array]){
            [string[]]$lines=$res
        }else{
            [string[]]$lines=@($Matches[0])
        }
        Write-Host $msg -ForegroundColor Yellow
        $content -replace $regex,$replace| Out-File $text_file -Encoding ascii -Force 
        exit_on_error
        # 显示所有修改内容的前后比较
        $lines | foreach{
            $_
            '====> '
            $_ -replace $regex,$replace
        }
    }
}
function disable_download_prebuilt_dependencies($cmakelists_root){
    args_not_null_empty_undefined cmakelists_root
    exit_if_not_exist $cmakelists_root -type Leaf 
    regex_replace_file -text_file $cmakelists_root `
                       -regex '(^\s*include\s*\(\s*cmake/WindowsDownloadPrebuiltDependencies\.cmake\s*\))' `
                       -replace "$sign#`$1" `
                       -msg "(禁止 Windows 预编译库下载) disable download prebuilt dependencies ($cmakelists_root)" 
}

$regex_gtest_definitions="\n\s*if\s*\(\s*NOT\s+MSVC\s*\)(?:(\s|\s*#.*\n))*target_compile_definitions\s*\(\s*gtest\s+PUBLIC\s+-DGTEST_USE_OWN_TR1_TUPLE\s*\)(?:(\s|\s*#.*\n))*endif\s*\(\s*(NOT\s+MSVC)?\s*\)"

function remove_gtest_use_own_tr1_tuple($cmakelists){
    args_not_null_empty_undefined cmakelists
    exit_if_not_exist $cmakelists -type Leaf 
    $content=Get-Content $cmakelists
    if(($content -join "`n") -match $regex_gtest_definitions){
        Write-Host "(找到正确的GTEST_USE_OWN_TR1_TUPLE定义)find GTEST_USE_OWN_TR1_TUPLE definition for gtest" -ForegroundColor Yellow
        return
    }
    $sign="#deleted by guyadong,remove GTEST_USE_OWN_TR1_TUPLE definition,do not edit it`n"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*add_definitions\s*\()\s*-DGTEST_USE_OWN_TR1_TUPLE\s*(\))' `
                        -replace "$sign#`$0`n" `
                        -msg "(删除GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*add_definitions\s*\()(.*)-DGTEST_USE_OWN_TR1_TUPLE(.*)(\))' `
                        -replace "$sign`$1`$2`$3`$4" `
                        -msg "(删除GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*target_compile_definitions\s*\(\s*\w+\s+)(?:(?:(?:INTERFACE|PUBLIC|PRIVATE)\s+)?-DGTEST_USE_OWN_TR1_TUPLE)\s*(\))' `
                        -replace "$sign#`$0" `
                        -msg "(删除GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*target_compile_definitions\s*\(\s*\w+\s+)(.*?)(?:(?:(?:INTERFACE|PUBLIC|PRIVATE)\s+)?-DGTEST_USE_OWN_TR1_TUPLE)(.*)(\))' `
                        -replace "$sign#`$1`$2`$3`$4" `
                        -msg "(删除GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
}

function add_gtest_use_own_tr1_tuple($cmakelists){
    args_not_null_empty_undefined cmakelists
    exit_if_not_exist $cmakelists -type Leaf 
    if((Get-Item $cmakelists).Directory.Name -ne 'gtest'){
        Write-Host "only CMakeLists.txt on 'gtest' folder" -ForegroundColor Yellow
        call_stack
        exit -1
    }
    $content=(Get-Content $cmakelists ) -join "`n"
    $sign="`n#added by guyadong,add GTEST_USE_OWN_TR1_TUPLE definition for gtest,do not edit it`n"    
    if( ! ($content -match $regex_gtest_definitions)){
        Write-Host "(添加GTEST_USE_OWN_TR1_TUPLE定义) add GTEST_USE_OWN_TR1_TUPLE for gtest ($cmakelists)" -ForegroundColor Yellow
        $content + "${sign}if(NOT MSVC)
  target_compile_definitions(gtest PUBLIC -DGTEST_USE_OWN_TR1_TUPLE)
endif(NOT MSVC)"| Out-File $cmakelists -Encoding ascii -Force
        exit_on_error
    }
}
# 删除其他文件中的 GTEST_USE_OWN_TR1_TUPLE 定义，在 gtest/CMakeLists.txt中为 gtest 添加 GTEST_USE_OWN_TR1_TUPLE 定义
function modify_gtest_use_own_tr1_tuple($caffe_root){
    args_not_null_empty_undefined caffe_root
    ls $caffe_root -Filter 'CMakeLists.txt' | foreach {
        remove_gtest_use_own_tr1_tuple $_.FullName        
    }
    add_gtest_use_own_tr1_tuple ([io.path]::Combine( $caffe_root,'src','gtest','CMakeLists.txt'))
}

# 修改 set_caffe_link 加入 MSVC 支持
function modify_caffe_set_caffe_link($caffe_root){
    args_not_null_empty_undefined caffe_root
    $target_cmake=[io.path]::Combine($caffe_root,'cmake','Targets.cmake')
    exit_if_not_exist $target_cmake -type Leaf 
    $sign="`n#modified by guyadong,for build with msvc,do not edit it`n"    
    $set_caffe_link_body='  if(MSVC AND CMAKE_GENERATOR MATCHES Ninja)        
    foreach(_suffix "" ${CMAKE_CONFIGURATION_TYPES})
      if(NOT _suffix STREQUAL "")
        string(TOUPPER _${_suffix} _suffix)
      endif()
      set(CMAKE_CXX_FLAGS${_suffix} "${CMAKE_CXX_FLAGS${_suffix}} /FS")
      set(CMAKE_C_FLAGS${_suffix} "${CMAKE_C_FLAGS${_suffix}} /FS")              
    endforeach()
  endif()
  if(BUILD_SHARED_LIBS)
    set(Caffe_LINK caffe)
  else()
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
      set(Caffe_LINK -Wl,-force_load caffe)
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
      set(Caffe_LINK -Wl,--whole-archive caffe -Wl,--no-whole-archive)
    elseif(MSVC)
      set(Caffe_LINK caffe)
    endif()
  endif()'
    $regx_no_msvc='((?:(?!MSVC)[\s\S])*)'
    $regex_msvc='[\s\S]*'
    $regex_begin='(\n\s*macro\s*\(\s*caffe_set_caffe_link\s*\))'
    $regex_end='(endmacro\(\s*(?:caffe_set_caffe_link)?\s*\))'
    regex_replace_file  -text_file $target_cmake `
                        -regex ($regex_begin + $regx_no_msvc + $regex_end) `
                        -replace "`$1$sign$set_caffe_link_body`n`$3" `
                        -msg "(修改set_caffe_link)modify set_caffe_link for MSVC in $target_cmake " `
                        -join
    # 显示修改后的结果
    $null=((Get-Content $target_cmake) -join "`n") -match $regex_begin+$regex_msvc+$regex_end
    $Matches[0]
}
# 修改 cmake/ProtoBuf.cmake
function modify_protobuf_cmake($caffe_root){
    args_not_null_empty_undefined caffe_root
    $protobuf_cmake=[io.path]::Combine($caffe_root,'cmake','ProtoBuf.cmake')
    exit_if_not_exist $protobuf_cmake -type Leaf 
    $content=(Get-Content $protobuf_cmake) -join "`n"
    # 匹配表达式:如果找到 guyadong 标记无需修改代码 
    $pattern='^((?:(?:\n\s*|\s*#(?:.{0})*\n))*)([^#\s].*\n[\s\S]+?)((?:(?:\s|\s*#.*\n))*if\s*\(\s*EXISTS\s+\$\s*\{\s*PROTOBUF_PROTOC_EXECUTABLE\s*\}\s*\))'
    if(! ($content -match $pattern.Replace('{0}','(?!guyadong)'))) {                    
        if($content -match $pattern.Replace('{0}','')){
            Write-Host "(无需修改find protobuf package代码)not need modify find protobuf package code in $protobuf_cmake"
            $Matches[2]
            return
        }else{
            Write-Host "(正则表达没有匹配到find protobuf package代码)not found find package for protobuf code by regular expression in $protobuf_cmake"
            call_stack
            exit -1
        }
    }
    $find_package_block=$Matches
    $protobuf_include_dir=($find_package_block[2] -split "`n") -match '(list|include_directories)\s*\(.*PROTOBUF_INCLUDE_DIR.*\)'
    $protobuf_libraries=($find_package_block[2] -split "`n") -match 'list\s*\(.*PROTOBUF_LIBRARIES.*\)'
    if(!$protobuf_include_dir -or !$protobuf_libraries){
        Write-Host "(正则表达没有匹配到 PROTOBUF_INCLUDE_DIR PROTOBUF_LIBRARIES 赋值代码)not found PROTOBUF_INCLUDE_DIR PROTOBUF_LIBRARIES assing statement by regular expression in $protobuf_cmake"
        call_stack
        exit -1
    }
    $sign="# modified by guyadong`n# search using protobuf-config.cmake"
    $find_package_block[2]="$sign`nfind_package( Protobuf REQUIRED NO_MODULE)`nset(PROTOBUF_INCLUDE_DIR `${PROTOBUF_INCLUDE_DIRS})`n$($protobuf_include_dir.trim())`n$($protobuf_libraries.trim())"
    Write-Host "(修改 protobuf 检测代码) modify profobuf find package $protobuf_cmake"
    $content.Replace($find_package_block[0],($find_package_block[1..3] -join "`n")) -split "`n" | Out-File $protobuf_cmake -Encoding ascii -Force
    $find_package_block[2]
}
# 修复 VS2013编译时， boost 
function support_boost_vs2013($caffe_root){    
    args_not_null_empty_undefined caffe_root
    if($skip_fix_boost_vs2013){
        return 
    }
    $dependencies_cmake= [io.path]::combine( $caffe_root,'cmake','Dependencies.cmake')
    exit_if_not_exist $dependencies_cmake -type Leaf 
    $regex_code='\s*if\s*\(\s*(?:(?:DEFINED\s+)?)MSVC\s+AND\s+CMAKE_CXX_COMPILER_VERSION VERSION_LESS\s+18.0.40629.0\s*\)((?:(?:\n\s*|\s*#.*\n))*)\s*add_definitions\s*\(\s*-DBOOST_NO_CXX11_TEMPLATE_ALIASES\s*\)\s*endif\(.*\)'
    $content=(Get-Content $dependencies_cmake) -join "`n"
    if( $content -match $regex_code){
        Write-Host "(无需修改) BOOST_NO_CXX11_TEMPLATE_ALIASES definition is present, $dependencies_cmake"
        $Matches[0]
        return
    }
    $regex_boost_block='(#\s*---\[\s*Boost.*\n)([\s\S]+)(#\s*---\[\s*Threads)'
    $patch_code='if( MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 18.0.40629.0)
  # Required for VS 2013 Update 4 or earlier.
  add_definitions(-DBOOST_NO_CXX11_TEMPLATE_ALIASES)
endif()
'
    if( !($content -match $regex_boost_block)){
        Write-Host "警告:(没有匹配到find boost package相关代码) warning:not match code for finding  boost package regular expression in $dependencies_cmake" -ForegroundColor Yellow
        Write-Host "程序以'# ---[ Boost' 和 '# ---[ Threads' 为标记查找findg boost package相关的代码块来实现代码自动更新。
如果没有找到这两个标记，无法完成自动更新.
如果不是用Visual Studio 2013编译，可以使用 -skip_fix_boost_vs2013 跳过此步骤.
如果用Visual Studio 2013编译，请将如下代码添加到 $dependencies_cmake 开始的位置,否则编译时会报错：
$patch_code
"
        call_stack
        exit -1
    }
    regex_replace_file -text_file $dependencies_cmake `
                        -regex $regex_boost_block `
                        -replace "`$1`$2#modified by guyadong`n$patch_code`$3" `
                        -msg "(增加对VS2103下boost编译支持代码)add BOOST_NO_CXX11_TEMPLATE_ALIASES definition in $dependencies_cmake" `
                        -join
    # 显示修改后的结果
    $null=((Get-Content $dependencies_cmake) -join "`n") -match $regex_code
    $Matches[0]
}
# 修改 cmake/Dependencies.cmake 中搜索hdf5代码
function modify_find_hdf5($caffe_root){
    args_not_null_empty_undefined caffe_root
    $dependencies_cmake= [io.path]::combine( $caffe_root,'cmake','Dependencies.cmake')
    exit_if_not_exist $dependencies_cmake -type Leaf 
    $content=(Get-Content $dependencies_cmake) -join "`n"
    # 匹配表达式:如果找到 guyadong 标记无需修改代码 
    $pattern='(\s*#\s*---\s*\[\s*HDF5.*\n)((?:(?:\n\s*|\s*#(?:.{0})*\n))*[^#\s].*\n[\s\S]+?)(#\s*---\s*\[\s*LMDB)'
    if( !($content -match $pattern.Replace('{0}','(?!guyadong)'))) {
        if($content -match $pattern.Replace('{0}','')){
            Write-Host "(无需修改find_package代码)not need modify find_package code in $dependencies_cmake"
            $Matches[2]
            return
        }else{
            Write-Host "(正则表达没有匹配到find hdf5 package代码)not found find_package code for hdf5 by regular expression in $dependencies_cmake"
            Write-Host "程序以'# ---[ HDF5' 和 '# ---[ LMDB' 为标记查找findg hdf5 package相关的代码块来实现代码自动更新。如果没有找到这两个标记，无法完成自动更新"
            call_stack
            exit -1
        }
    }
    $find_package_block=$Matches
    $hdf5_include_dir=($find_package_block[2] -split "`n") -match '(list|include_directories)\s*\(.*HDF5_INCLUDE_DIRS.*\)'
    $hdf5_libraries=($find_package_block[2] -split "`n") -match 'list\s*\(.*HDF5_LIBRARIES.*\)'
    if(!($hdf5_libraries -match 'HDF5_HL_LIBRARIES')){
        $hdf5_libraries=$hdf5_libraries -replace '\$\s*\{\s*HDF5_LIBRARIES\s*\}','$0 ${HDF5_HL_LIBRARIES}'
    }
    if(!$hdf5_include_dir -or !$hdf5_libraries){
        Write-Host "(正则表达没有匹配到 HDF5_INCLUDE_DIRS HDF5_LIBRARIES 赋值代码)not found HDF5_INCLUDE_DIRS HDF5_LIBRARIES assing statement by regular expression in $dependencies_cmake"
        call_stack
        exit -1
    }
    $sign="# modified by guyadong`n# Find HDF5 always using static libraries"
    $find_package_block[2]="$sign`nfind_package(HDF5 COMPONENTS C HL REQUIRED)`nset(HDF5_LIBRARIES hdf5-static)`nset(HDF5_HL_LIBRARIES hdf5_hl-static)`n$($hdf5_include_dir.trim())`n$($hdf5_libraries.trim())"
    Write-Host "(修改 hdf5 检测代码) modify find package for hdf5,$dependencies_cmake"
    $content.Replace($find_package_block[0],($find_package_block[1..3] -join "`n")) -split "`n" | Out-File $dependencies_cmake -Encoding ascii -Force
    $find_package_block[2]
}
# 修复 /src/caffe/CMakeLists.txt /tools/CMakeLists.txt中可能存在的问题
function modify_src_cmake_list($caffe_root){
    args_not_null_empty_undefined caffe_root
    $src_caffe_cmake= [io.path]::combine( $caffe_root,'src','caffe','CMakeLists.txt')
    regex_replace_file  -text_file $src_caffe_cmake `
                        -regex '(^\s*target_link_libraries\(caffe\s+)(?!PUBLIC\s+)(.*\$\{Caffe_LINKER_LIBS\}\))' `
                        -replace '$1PUBLIC $2' `
                        -msg "(修正tools下target 没有连接库的问题),add PUBLIC keyword $src_caffe_cmake"
}
# 修改源码以适应 MinGW 编译 src/caffe/util/db_lmdb.cpp
function modify_for_mingw_db_lmdb_cpp($caffe_root){
    args_not_null_empty_undefined caffe_root
    $db_lmdb_cpp=[io.path]::Combine($caffe_root,'src','caffe','util','db_lmdb.cpp')
    if( !(Test-Path $db_lmdb_cpp -PathType Leaf)){
        Write-Host "(警告:没有找到文件),not found $db_lmdb_cpp" -ForegroundColor Yellow
        return
    }
    $content=(Get-Content $db_lmdb_cpp) -join "`n"
    # 找到 包含 guyadong 标记的更新代码
    if($content -match '\s*//\s*.*guyadong.*\n\s*#if.*\n[\s\S]+?\s*#endif'){        
        Write-Host "(代码不必再更新),code is update of date $db_lmdb_cpp"
        $Matches[0]
        return
    }
    $sign='// modify by guyadong,for WIN32 building with MinGW'
    $if_expression='#if defined WIN32 && (defined _MSC_VER || defined __MINGW__ || defined __MINGW64__ || defined __MINGW32__)'
    $code0="$if_expression`n#include <direct.h>`n#define mkdir(X, Y) _mkdir(X)`n#endif`n"
    $code="`n$sign`n$code0"
    $regex_def='(\s*#if.*_MSC_VER.*\n)(?:\s*(?://.*)?\n)*\s*#include <direct.h>\s*(?://.*)?\n(?:\s*(?://.*)?\n)*\s*#define\s+mkdir\s*\(\s*\w+\s*,\s*\w+\s*\)\s+_mkdir\s*\(\s*\w+\s*\)\s*\n(?:\s*(?://.*)?\n)*\s*#endif'
    if( $content -match $regex_def ){
        $m=($Matches[1].trim() -replace '\s+',' ') -replace '\s*([^A-Za-z0-9_\s]+)\s*','$1'
        $f=($if_expression.trim() -replace '\s+',' ') -replace '\s*([^A-Za-z0-9_\s]+)\s*','$1'
        if($m -eq $f){
            Write-Host "(代码不必再更新),code is update of date $db_lmdb_cpp"
            $Matches[0]
            return
        }
        regex_replace_file  -text_file $db_lmdb_cpp `
                    -regex  $regex_def `
                    -replace $code `
                    -msg "(改进宏定义条件判断)modify preprocessor expression for MinGW $db_lmdb_cpp" `
                    -join
        return
    }elseif( $content -match '\s*#define\s+mkdir\s*\(\s*\w+\s*,\s*\w+\s*\)\s+_mkdir\s*\(\s*\w+\s*\)' ){
        Write-Host "找到了 $($Matches[0].trim()) 代码,但是逻辑结构比较复杂,没办法自动修正代码。请手工检查修复。
如果你不需要用 MinGW 编译,可以在命令行加 -skip_fix_formingw 跳过此步骤" -ForegroundColor Yellow
        Write-Host "说明:这个代码文件中用到了mkdir函数用于创建文件夹,linux gcc中的mkdir有两个参数(文件夹名,权限),
MSVC和MinGW也有名为_mkdir的函数用于创建文件夹，但只有一个参数(文件夹名),
所以这里需要一个名为mkdir的宏,将对mkdir的调用转换为_mkdir,代码如下：
$code0 
请参照上面的代码原理修复此代码,手工修复代码后,fetch时请加 -skip_fix_formingw 跳过此步骤"
        call_stack
        exit -1

    }
    regex_replace_file -text_file $db_lmdb_cpp `
                        -regex '\s*#include\s+"caffe/util/db_lmdb\.hpp"\s*\n' `
                        -replace "`$0$code" `
                        -msg "(改进宏定义条件判断)modify preprocessor expression for MinGW $db_lmdb_cpp" `
                        -join
}
# 修改源码以适应 MinGW 编译 src/caffe/util/signal_handler.cpp
function modify_for_mingw_signal_handler_cpp($caffe_root){
    args_not_null_empty_undefined caffe_root
    $signal_handler_cpp=[io.path]::Combine($caffe_root,'src','caffe','util','signal_handler.cpp')
    if(!((Get-Content $signal_handler_cpp) -match '^\s*#if(?:def)?\s+.*(WIN32|_MSC_VER).*$')){
        Write-Host "这个代码好像没有针对 windows 编译做过修改，请检查代码 $signal_handler_cpp
如果你不需要用 MinGW 编译,可以在命令行加 -skip_fix_formingw 跳过此步骤"
        call_stack
        exit -1
    }
    $sign='// modify by guyadong,for WIN32 building with MinGW'
    regex_replace_file -text_file $signal_handler_cpp `
                    -regex '\s*(#\s*ifdef\s+_MSC_VER|#\s*if\s+defined(\s+|\s*\(\s*)_MSC_VER(\s*\))?)' `
                    -replace "$sign`n#if defined WIN32 && (defined _MSC_VER || defined __MINGW__ || defined __MINGW64__ || defined __MINGW32__)" `
                    -msg "(改进宏定义条件判断)modify preprocessor expression for MinGW $signal_handler_cpp" `
}
function modify_for_mingw($caffe_root){
    if( ! $skip_fix_formingw){
        modify_for_mingw_db_lmdb_cpp $caffe_root
        modify_for_mingw_signal_handler_cpp $caffe_root
    }
}
# 根据bvlccaffe windows版本的CMakeLists.txt,修改 根目录下 CMakeLists.txt 可能存在的问题
function modify_cmakelists_root_for_windows($caffe_root){
    args_not_null_empty_undefined caffe_root
    $cmakelists_root=Join-Path $caffe_root -ChildPath CMakeLists.txt
    regex_replace_file  -text_file $cmakelists_root `
                        -regex '^\s*include\s*\(\s*cmake[/\\]WindowsDownloadPrebuiltDependencies\.cmake\s*\)' `
                        -replace "#deleted by guyadong,disable download prebuilt dependencies`n#`$0" `
                        -msg "(禁止 Windows 预编译库下载) disable download prebuilt dependencies ($cmakelists_root)"  

    regex_replace_file  -text_file $cmakelists_root `
                        -regex '(^\s*caffe_option\s*\(\s*protobuf_MODULE_COMPATIBLE\s+.*\s+)(?:ON|OFF)[^)]*\)\s*(?:#.*)?$' `
                        -replace "`$1ON)#modify by guyadong,always set ON" `
                        -msg "set protobuf_MODULE_COMPATIBLE always ON ($cmakelists_root)"  `

    regex_replace_file  -text_file $cmakelists_root `
                        -regex '(^\s*caffe_option\s*\(\s*COPY_PREREQUISITES\s+.*\s+)(?:ON|OFF)[^)]*\)\s*(?:#.*)?$' `
                        -replace "`$1OFF)#modify by guyadong,always set OFF" `
                        -msg "set COPY_PREREQUISITES always OFF ($cmakelists_root)"  `

}
# 基于 caffe 项目代码通用补丁函数, 
# 所有 caffe 系列项目fetch后 应先调用此函数做修补
# $caffe_root caffe 源码根目录
function modify_caffe_folder([string]$caffe_root,$patch_root=$PATCH_ROOT){
    args_not_null_empty_undefined caffe_root
    exit_if_not_exist $caffe_root -type Container
    # 通过是不是有src/caffe 文件夹判断是不是 caffe 项目
    exit_if_not_exist ([io.path]::Combine($caffe_root,'src','caffe')) -type Container -msg "$caffe_root 好像不是个 caffe 源码文件夹"
    modify_cmakelists_root_for_windows $caffe_root
    modify_src_cmake_list $caffe_root
    modify_find_hdf5 $caffe_root
    support_boost_vs2013 $caffe_root
    modify_protobuf_cmake $caffe_root
    modify_caffe_set_caffe_link $caffe_root
    modify_gtest_use_own_tr1_tuple $caffe_root
    modify_for_mingw $caffe_root
    echo "function:$($MyInvocation.MyCommand) -> (复制修改的补丁文件)copy patch file to $caffe_root"	
    cp -Path ([io.path]::Combine($patch_root,'caffe_base','*')) -Destination $caffe_root -Recurse -Force -Verbose    
    #cp -Path ([io.path]::Combine($patch_root,'caffe_base','cmake','Modules','*')) -Destination ([io.path]::Combine($caffe_root,'cmake','Modules')) -Recurse -Force -Verbose    
	exit_on_error 
}
