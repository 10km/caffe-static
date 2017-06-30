if(MSVC)     
  # Use the static C library for all build types
  MESSAGE(STATUS "link to static  C and C++ runtime lirbary(/MT /MTd)")
  foreach(var 
		CMAKE_C_FLAGS_DEBUG_INIT 
		CMAKE_C_FLAGS_RELEASE_INIT
		CMAKE_C_FLAGS_MINSIZEREL_INIT 
		CMAKE_C_FLAGS_RELWITHDEBINFO_INIT
		CMAKE_CXX_FLAGS_DEBUG_INIT 
		CMAKE_CXX_FLAGS_RELEASE_INIT
		CMAKE_CXX_FLAGS_MINSIZEREL_INIT 
		CMAKE_CXX_FLAGS_RELWITHDEBINFO_INIT
    )
    set( has_replaced off)
    if(${var} MATCHES "/MD")
      string(REGEX REPLACE "/MD" "/MT" ${var} "${${var}}")
      set( has_replaced on)
    endif()   
    if(${var} MATCHES "/Z[iI]")
    	# use /Z7 option to produces an .obj file containing full symbolic debugging information for use with the debugger
    	# for detail,see https://msdn.microsoft.com/zh-cn/library/958x11bc.aspx
      string(REGEX REPLACE "/Z[iI]" "/Z7" ${var} "${${var}}")
      set( has_replaced on)
    endif() 
    if( has_replaced ) 
    	MESSAGE(STATUS  "${var}:${${var}}")
		endif( has_replaced )
		unset( has_replaced )
  endforeach()	  
endif(MSVC)
