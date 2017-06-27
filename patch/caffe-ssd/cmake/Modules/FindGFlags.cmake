# - Try to find GFLAGS
#
# The following variables are optionally searched for defaults
#  GFLAGS_ROOT_DIR:            Base directory where all GFLAGS components are found
#
# The following are set after configuration is done:
#  GFLAGS_FOUND
#  GFLAGS_INCLUDE_DIRS
#  GFLAGS_LIBRARIES
#  GFLAGS_LIBRARYRARY_DIRS

include(FindPackageHandleStandardArgs)

set(GFLAGS_ROOT_DIR "" CACHE PATH "Folder contains Gflags")
# We are testing only a couple of files in the include directories
# modified by guyadong
if(GFLAGS_ROOT_DIR)
	if(WIN32)
		set (cmake_root ${GFLAGS_ROOT_DIR}/CMake)
	else()
		set (cmake_root ${GFLAGS_ROOT_DIR}/lib/cmake/gflags)
	endif(WIN32)
	find_package(gflags REQUIRED CONFIG HINTS ${cmake_root})
	unset(cmake_root)	
	# solved "shlwapi.lib" missing
	# GFLAGS_LIBRARIES is imported target
	# gflags-config.cmake will set the variable :GFLAGS_LIBRARIES GFLAGS_INCLUDE_DIR
else()
	if(MSVC)
			find_path(GFLAGS_INCLUDE_DIR gflags/gflags.h
			    PATHS ${GFLAGS_ROOT_DIR}/include)			
			find_library(GFLAGS_LIBRARY_RELEASE
	        NAMES gflags gflags_static
	        PATHS ${GFLAGS_ROOT_DIR}
	        PATH_SUFFIXES lib)	
	    find_library(GFLAGS_LIBRARY_DEBUG
	        NAMES gflags gflags_static
	        PATHS ${GFLAGS_ROOT_DIR}
	        PATH_SUFFIXES lib)
    			set(GFLAGS_LIBRARIES optimized ${GFLAGS_LIBRARY_RELEASE} debug ${GFLAGS_LIBRARY_DEBUG})
	else()
			find_path(GFLAGS_INCLUDE_DIR gflags/gflags.h
			    PATHS ${GFLAGS_ROOT_DIR}/include
					NO_DEFAULT_PATH)
			find_path(GFLAGS_INCLUDE_DIR gflags/gflags.h
			    PATHS ${GFLAGS_ROOT_DIR}/include)	
	    find_library(GFLAGS_LIBRARIES gflags PATHS ${GFLAGS_ROOT_DIR}/lib)	
	endif(MSVC)
endif(GFLAGS_ROOT_DIR)
find_package_handle_standard_args(GFlags DEFAULT_MSG GFLAGS_INCLUDE_DIR GFLAGS_LIBRARIES)

if(GFLAGS_FOUND)
    set(GFLAGS_INCLUDE_DIRS ${GFLAGS_INCLUDE_DIR})
    message(STATUS "Found gflags  (include: ${GFLAGS_INCLUDE_DIRS}, library: ${GFLAGS_LIBRARIES})")
    mark_as_advanced(GFLAGS_LIBRARY_DEBUG GFLAGS_LIBRARY_RELEASE
                     GFLAGS_LIBRARY GFLAGS_INCLUDE_DIR GFLAGS_ROOT_DIR)
endif()
