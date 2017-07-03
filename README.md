author: guyadong@gdface.net 2017/6
#0.who am i?

在caffe应用到工程实现时，为了方便系统安装，需要尽可能减少软件的依赖库。

本项目以bash shell/powershell脚本实现将caffe依赖的所有第三方库与caffe静态编译一起，以满足全静态编译的要求。

通过本项目提供的脚本生成的caffe编译环境不需要在系统安装任何第三方库和软件，就可以自动完成caffe项目静态编译(目前在centos6.5/ubuntu16/win7/win10上测试通过)。


本项目编译出的caffe有如下限制：


	--没有提供python接口

	--CPU_ONLY模式

本项目只是实现caffe-ssd源码的全静态编译，如果要实现其他caffe版本全静态编译只需要参照bin/build_ssd.sh即可以实现。
#1.目录结构说明

bin下为所有执行脚本(bash shell/powsershell)

	bash shell(for linux):

		build.sh 自动下载编译所有项目最后编译caffe

		fetch.sh 用于下载对应的项目包并解压以及更新补丁(fetch.sh --help 查看使用说明)

		build_xxx.sh 编译xxx对应的项目

		build_var,build_funs公用函数和变量

	powershell(for windows):

		build.ps1 项目编译脚本 (powershell中执行 ./build.ps1 -help 查看使用说明)

		fetch.ps1 用于下载对应的项目包并解压以及更新补丁(powershell中执行 ./fetch.ps1 --help 查看使用说明)

		build_var.ps1,build_funs.ps1 公用函数和变量

tools下为编译过程中用的工具(cmake,7z,jom,mingw32,ming64,msys2)

source 解压后的源码位置

package 项目压缩包位置

release 编译安装位置

pactch 存放对应项目的补丁文件	

	
    ├── bin
    │   ├── build_boost.sh
    │   ├── build_bzip2.sh
    │   ├── build_funs
    │   ├── build_gflags.sh
    │   ├── build_glog.sh
    │   ├── build_hdf5.sh
    │   ├── build_leveldb.sh
    │   ├── build_lmdb.sh
    │   ├── build_OpenBLAS.sh
    │   ├── build_opencv.sh
    │   ├── build_protobuf.sh
    │   ├── build.sh
    │   ├── build_snappy.sh
    │   ├── build_ssd.sh
    │   ├── build_vars
    │   └── fetch.sh
    ├── package
    ├── patch
    ├── readme.md
    ├── source
    └── tools

#2.开始

执行bin/build.sh即可完成下载、编译所有代码。

第一次执行因为要下载caffe及所有依赖库的源码，所以会耗时较长，请耐心等待。



#3.运行环境要求

必须有安装gcc编译器(g++ &＆ gcc)

关于编译器版本要求参见 build_vars 中的变量 compiler_version_limit 定义，
可以通过 BUILD_COMPILER_PATH 指定编译器位置(参见bin/build_vars中 BUILD_COMPILER_PATH 的定义 )

powershell 4.0 下载安装
https://social.technet.microsoft.com/wiki/contents/articles/21016.how-to-install-windows-powershell-4-0.aspx

