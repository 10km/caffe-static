# æ≤Ã¨±‡“Î gflags ‘¥¬ÎΩ≈±æ
# author guyadong@gdface.net

. "./build_vars.ps1"

$install_path=$GFLAGS_INSTALL_PATH
echo install_path:$install_path
pushd (Join-Path -Path $SOURCE_ROOT -ChildPath $GFLAGS_FOLDER)
remove_if_exist CMakeCache.txt
&$CMAKE_EXE . $CMAKE_VARS_DEFINE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$install_path \
	-DBUILD_SHARED_LIBS=off \
	-DBUILD_STATIC_LIBS=on \
	-DBUILD_gflags_LIB=on \
	-DINSTALL_STATIC_LIBS=on \
	-DINSTALL_SHARED_LIBS=off \
	-DREGISTER_INSTALL_PREFIX=off
exit_on_error
remove_if_exist $install_path
make clean
make -j $MAKE_JOBS install
exit_on_error
popd