author: guyadong@gdface.net 2017/6

#0.who am i?

在caffe应用到工程实现时，为了方便系统安装，需要尽可能减少软件的依赖库。

本项目以bash shell/PowerShell脚本实现将caffe依赖的所有第三方库与caffe静态编译一起，以满足全静态编译的要求。

通过本项目提供的脚本生成的caffe编译环境不需要在系统安装任何第三方库和软件，就可以自动完成caffe项目静态编译.

目前在centos6.5/ubuntu16/win7/win10上测试通过,windows上VS2013,VS2015,MinGW 5.2.0编译通过


本项目编译出的caffe有如下限制：


	--没有提供python接口

	--CPU_ONLY模式


#1.目录结构说明

目录结构如下：
	
	├── bin windows/linux 执行脚本
	│   ├── build_boost.sh
	│   ├── build_bzip2_1_0_6.sh
	│   ├── build_bzip2.sh
	│   ├── build_funs
	│   ├── build_funs.ps1
	│   ├── build_gflags.sh
	│   ├── build_glog.sh
	│   ├── build_hdf5.sh
	│   ├── build_leveldb.sh
	│   ├── build_lmdb_cmake.sh
	│   ├── build_lmdb.sh
	│   ├── build_OpenBLAS.sh
	│   ├── build_opencv.sh
	│   ├── build_protobuf.sh
	│   ├── build.ps1
	│   ├── build.sh
	│   ├── build_snappy.sh
	│   ├── build_ssd.sh
	│   ├── build_vars
	│   ├── build_vars.ps1
	│   ├── compiler_flag_overrides.cmake
	│   ├── fetch.ps1
	│   ├── fetch.sh
	│   ├── patchwin.ps1
	│   ├── test1.ps1
	│   └── unpack.ps1
	├── package 所有项目压缩包位置
	├── patch 存放对应项目的补丁文件
	├── README.md
	├── release 所有项目编译后的安装位置
	├── source 解压后的源码位置
	└── tools 编译过程中用的工具(cmake,7z,jom,mingw32,ming64,msys2)

## bash shell(for linux): ##

	build.sh 自动下载编译所有项目最后编译caffe
	fetch.sh 用于下载对应的项目包并解压以及更新补丁(fetch.sh --help 查看使用说明)
	build_xxx.sh 编译xxx对应的项目
	build_var,build_funs公用函数和变量

## PowerShell(for windows): ##

	build.ps1 项目编译脚本 (PowerShell中执行 ./build.ps1 -help 查看使用说明)
	fetch.ps1 用于下载对应的项目包并解压以及更新补丁(PowerShell中执行 ./fetch.ps1 --help 查看使用说明)
	patchwin.ps1 源码分析并自动修复代码的函数库
	build_var.ps1,build_funs.ps1 公用函数和变量




#2.运行环境要求

## linux ##

必须安装gcc编译器(g++ &＆ gcc)

关于编译器版本要求参见 build_vars 中的变量 compiler_version_limit 定义，

可以通过 BUILD_COMPILER_PATH 指定编译器位置(参见bin/build_vars中 BUILD_COMPILER_PATH 的定义 )

## windows ##

Windows下需要 PowerShell 执行脚本，需要 PowerShell 4.0或5.0 支持(目前在PowerShell 6.0版本上还有兼容性问题，暂不支持)。

Win7 内置 PowerShell 2.0，需要升级到4.0。关于 PowerShell 4.0 下载安装，参见
[《How to Install Windows PowerShell 4.0》](https://social.technet.microsoft.com/wiki/contents/articles/21016.how-to-install-windows-PowerShell-4-0.aspx)

Win10内置 PowerShell 5.0，不需要升级

**如何查看 PowerShell 版本号?**

在PowerShell (1.0以上版本)中输入 如下命令

>$PSVersionTable
    
即会输出如下一张表，其中 PSVersion 即为 PowerShell 版本号

	Name                           Value                                                                                                                                                                                                          
	----                           -----                                                                                                                                                                                                          
	PSVersion                      4.0                                                                                                                                                                                                            
	WSManStackVersion              3.0                                                                                                                                                                                                            
	SerializationVersion           1.1.0.1                                                                                                                                                                                                        
	CLRVersion                     4.0.30319.42000                                                                                                                                                                                                
	BuildVersion                   6.3.9600.16406                                                                                                                                                                                                 
	PSCompatibleVersions           {1.0, 2.0, 3.0, 4.0}                                                                                                                                                                                           
	PSRemotingProtocolVersion      2.2              

##编译器

支持Visual Studio 2013,Visual Studio 2015，MinGW.

执行 build.ps1时如果没有用 -compiler 指定编译器，则脚本会以vs2013 vs2015 gcc的优先顺序自动侦测系统中的编译器，选择第一个找到的编译器，参见 build.ps1 中init_build_info函数

如果你的Windows系统没有安装任何编译器，脚本会用自带的MinGW编译进行编译
    
#3.开始

## linux ##
执行 bin/build.sh 即可完成下载、编译所有代码。

第一次执行因为要下载caffe及所有依赖库的源码，所以会耗时较长，请耐心等待。

如果要编译自己的caffe项目代码，请参照 build_ssd.sh 脚本修改

## windows ##

在 PowerShell 中执行fetch.ps1 下载解压所有软件包和工具包,第一次执行时要下载几百MB数据，可能耗时较长 

	D:\caffe-static\bin> ./fetch.ps1

执行 build.ps1 完成所有依赖库及caffe项目编译

	D:\caffe-static\bin> ./build.ps1

##编译自己的caffe windows代码

本项目windows脚本已经内置了下面两套 caffe 源码的静态编译(运行./build -help 查看帮助信息)：

caffe_windows :官方caffe项目windows分支 https://github.com/BVLC/caffe.git branch:windows

conner99_ssd  :conner99的ssd windows版本  https://github.com/conner99/caffe.git branch:ssd-microsoft

如果要对其他的caffe项目进行编译，可以在执行 ./build.ps1时使用 -custom_caffe_folder 选项指定要编译的caffe项目文件夹

在这个过程中会对指定的caffe项目文件夹中的cmake脚本进行自动修改。

代码自动修改是用正则表达式根据已经掌握的代码特征对源码进行分析并修改，作者不可能对所有的caffe项目代码都了解其特征，做出正确修改，在使用此参数不能完成项目编译时，请自行对比脚本对caffe_windows，conner99_ssd两个项目的修改，多看看patchwin.ps1的源码，掌握要领进行手工修改。

**注意：**

本项目只是一个整合编译工具，并不负责将只能能linux下编译的代码修改为可以windows下编译的代码。使用-custom_caffe_folder选项指定要编译的caffe项目文件夹时，用户自己要确保这套代码在windows是可编译的。



 








