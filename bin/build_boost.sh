#!/bin/bash
# 静态编译 boost 源码脚本
# author guyadong@gdface.net

shell_folder=$(cd "$(dirname "$0")";pwd)
. $shell_folder/build_funs
. $shell_folder/build_vars

rm $SOURCE_ROOT/$BOOST_FOLDER/b2 >/dev/null 2>&1
rm $SOURCE_ROOT/$BOOST_FOLDER/bjam >/dev/null 2>&1
rm $SOURCE_ROOT/$BOOST_FOLDER/project-config.jam* >/dev/null 2>&1
rm -fr $SOURCE_ROOT/$BOOST_FOLDER/bin.v2 >/dev/null 2>&1

install_path=$BOOST_INSTALL_PATH
echo install_path:$install_path
pushd $SOURCE_ROOT/$BOOST_FOLDER
#exit_if_not_exist $BZIP2_INSTALL_PATH "not found $BZIP2_INSTALL_PATH,please build $BZIP2_PREFIX"
# 指定依赖库bzip2的位置,编译iostreams库时需要
#export LIBRARY_PATH=$BZIP2_INSTALL_PATH/lib:$LIBRARY_PATH
#export CPLUS_INCLUDE_PATH=$BZIP2_INSTALL_PATH/include:$CPLUS_INCLUDE_PATH
# 生成 user-config.jam 指定编译器
export BOOST_BUILD_PATH=$(pwd)
echo "using gcc : : $MAKE_CXX_COMPILER ;" >$BOOST_BUILD_PATH/user-config.jam
cat $BOOST_BUILD_PATH/user-config.jam

# 所有库列表
# atomic chrono container context coroutine date_time exception filesystem 
# graph graph_parallel iostreams locale log math mpi program_options python 
# random regex serialization signals system test thread timer wave
# --without-libraries指定不编译的库
#./bootstrap.sh --without-libraries=python,mpi,graph,graph_parallel,wave
# --with-libraries指定编译的库

# 默认编译的库
with_librarys=--with-libraries=system,thread,filesystem,regex
# 默认排除的库
without_librarys=

[ -n "$BOOST_WITHOUT_LIBRARYS" ] && without_librarys=--without-libraries=$BOOST_WITHOUT_LIBRARYS && with_librarys=

[ -n "$BOOST_WITH_LIBRARYS" ] && with_librarys=--with-libraries=$BOOST_WITH_LIBRARYS && without_librarys=

[ "$boost_build_all" = "ON" ] && with_librarys=　&& without_librarys=

./bootstrap.sh $with_librarys $without_librarys
exit_on_error
./b2 --clean
remove_if_exist $install_path
# --prefix指定安装位置
# --debug-configuration 编译时显示加载的配置信息
# -q参数指示出错就停止编译
# link=static 只编译静态库

./b2 cxxflags=-fPIC cflags=-fPIC --prefix=$install_path -q --debug-configuration link=static install
exit_on_error
popd
