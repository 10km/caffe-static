# Copyright (C) 2007-2009 LuaDist.
# author guyadong@gdface.net

PROJECT(lmdb C)
CMAKE_MINIMUM_REQUIRED(VERSION 2.6)
if(MSVC)
include_directories(${PROJECT_SOURCE_DIR})
endif(MSVC)
# Library
SET(BZIP2_SRCS blocksort.c huffman.c crctable.c randtable.c
               compress.c decompress.c bzlib.c )

ADD_LIBRARY(lmdb  mdb.c midl.c)
TARGET_LINK_LIBRARIES(lmdb -pthread)


function(LMDB_ADD_EXE TESTNAME TESTFILE)
    if(NOT TESTNAME)
        message(SEND_ERROR "Error: LMDB_ADD_TEST called without test name")
        return()
    endif(NOT TESTNAME)

    if(NOT TESTFILE)
        message(SEND_ERROR "Error: LMDB_ADD_TEST called without test file")
        return()
    endif(NOT TESTFILE)
		message(STATUS TESTFILE:${TESTFILE})
		if(${TESTFILE})
	    add_executable(${TESTNAME}
	        ${${TESTFILE}})
		else()
	    add_executable(${TESTNAME}
	        ${TESTFILE})
		endif()

    target_link_libraries(${TESTNAME} lmdb)

    #add_test(NAME ${TESTNAME} COMMAND ${TESTNAME})

    #add_dependencies(RUN_LMDB_UNIT_TESTS ${TESTNAME})
    install(TARGETS ${TESTNAME}  RUNTIME DESTINATION bin)
endfunction(LMDB_ADD_EXE)
if(MSVC)
	SET(MDB_STAT_SRCS mdb_stat.c getopt.c)
	SET(MDB_COPY_SRCS mdb_copy.c getopt.c)
	SET(MDB_DUMP_SRCS mdb_dump.c getopt.c)
	SET(MDB_LOAD_SRCS mdb_load.c getopt.c)
	message(STATUS MDB_STAT_SRCS:${MDB_STAT_SRCS})
	message(STATUS MDB_COPY_SRCS:${MDB_COPY_SRCS})
	message(STATUS MDB_DUMP_SRCS:${MDB_DUMP_SRCS})
	message(STATUS MDB_LOAD_SRCS:${MDB_LOAD_SRCS})
else()
	SET(MDB_STAT_SRCS mdb_stat.c)
	SET(MDB_COPY_SRCS mdb_copy.c)
	SET(MDB_DUMP_SRCS mdb_dump.c)
	SET(MDB_LOAD_SRCS mdb_load.c)
endif(MSVC)               
LMDB_ADD_EXE(mdb_stat MDB_STAT_SRCS)
LMDB_ADD_EXE(mdb_copy MDB_COPY_SRCS)
LMDB_ADD_EXE(mdb_dump MDB_DUMP_SRCS)
LMDB_ADD_EXE(mdb_load MDB_LOAD_SRCS)
LMDB_ADD_EXE(mtest mtest.c)
LMDB_ADD_EXE(mtest2 mtest2.c)
LMDB_ADD_EXE(mtest3 mtest3.c)
LMDB_ADD_EXE(mtest4 mtest4.c)
LMDB_ADD_EXE(mtest5 mtest5.c)
# ftp://sourceware.org/pub/pthreads-win32/pthreads-w32-2-9-1-release.zip
if(MSVC)
	set(PTHREADS_W32_ROOT ${PROJECT_SOURCE_DIR}/../../../pthreads-w32-2-9-1-release/Pre-built.2)
	message(STATUS PTHREADS_W32_ROOT:${PTHREADS_W32_ROOT})
	if(NOT IS_DIRECTORY  ${PTHREADS_W32_ROOT})
		message(FATAL_ERROR "not found pthreads-w32")
	endif()
	include_directories (${PTHREADS_W32_ROOT}/include)
	set(CMAKE_FIND_ROOT_PATH ${PTHREADS_W32_ROOT})
	set(CMAKE_PREFIX_PATH ${PTHREADS_W32_ROOT} )
	message(STATUS CMAKE_LIBRARY_ARCHITECTURE:${CMAKE_LIBRARY_ARCHITECTURE})
	find_library( PTHREADS_W32_LIBRARY pthreadVC2 PATH_SUFFIXES  X64 )
	if( NOT PTHREADS_W32_LIBRARY)
		message(FATAL_ERROR "not found PTHREADS_W32_LIBRARY: pthreadVC2")
	endif()
	target_link_libraries(mdb_stat ${PTHREADS_W32_LIBRARY})
	target_link_libraries(mdb_copy ${PTHREADS_W32_LIBRARY})
	target_link_libraries(mdb_dump ${PTHREADS_W32_LIBRARY})
	target_link_libraries(mdb_load ${PTHREADS_W32_LIBRARY})
endif(MSVC)

INSTALL(TARGETS lmdb mdb_stat mdb_copy mdb_dump mdb_load 
	RUNTIME DESTINATION bin 
	LIBRARY DESTINATION lib 
	ARCHIVE DESTINATION lib)
INSTALL(FILES lmdb.h DESTINATION include)
INSTALL(FILES  mdb_stat.1 mdb_copy.1 mdb_dump.1 mdb_load.1 	DESTINATION share/man/man1)

