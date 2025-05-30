include(GNUInstallDirs)
include(LLVMDistributionSupport)

macro(set_flang_windows_version_resource_properties name)
  if (DEFINED windows_resource_file)
    set_windows_version_resource_properties(${name} ${windows_resource_file}
      VERSION_MAJOR ${FLANG_VERSION_MAJOR}
      VERSION_MINOR ${FLANG_VERSION_MINOR}
      VERSION_PATCHLEVEL ${FLANG_VERSION_PATCHLEVEL}
      VERSION_STRING "${FLANG_VERSION}"
      PRODUCT_NAME "flang")
  endif()
endmacro()

macro(add_flang_subdirectory name)
  add_llvm_subdirectory(FLANG TOOL ${name})
endmacro()

function(add_flang_library name)
  set(options SHARED STATIC INSTALL_WITH_TOOLCHAIN)
  set(multiValueArgs ADDITIONAL_HEADERS CLANG_LIBS MLIR_LIBS MLIR_DEPS)
  cmake_parse_arguments(ARG
    "${options}"
    ""
    "${multiValueArgs}"
    ${ARGN})

  set(srcs)
  if (MSVC_IDE OR XCODE)
    # Add public headers
    file(RELATIVE_PATH lib_path
      ${FLANG_SOURCE_DIR}/lib/
      ${CMAKE_CURRENT_SOURCE_DIR})
    if(NOT lib_path MATCHES "^[.][.]")
      file( GLOB_RECURSE headers
        ${FLANG_SOURCE_DIR}/include/flang/${lib_path}/*.h
        ${FLANG_SOURCE_DIR}/include/flang/${lib_path}/*.def)
      set_source_files_properties(${headers} PROPERTIES HEADER_FILE_ONLY ON)

      if (headers)
        set(srcs ${headers})
      endif()
    endif()
  endif(MSVC_IDE OR XCODE)

  if (srcs OR ARG_ADDITIONAL_HEADERS)
    set(srcs
      ADDITIONAL_HEADERS
      ${srcs}
      ${ARG_ADDITIONAL_HEADERS}) # It may contain unparsed unknown args.
      
  endif()

  if(ARG_SHARED AND ARG_STATIC)
    set(LIBTYPE SHARED STATIC)
  elseif(ARG_SHARED)
    set(LIBTYPE SHARED)
  elseif(ARG_STATIC)
    # If BUILD_SHARED_LIBS and ARG_STATIC are both set, llvm_add_library prioritizes STATIC.
    # This is required behavior for libflang_rt.quadmath.
    set(LIBTYPE STATIC)
  else()
    # Let llvm_add_library decide, taking BUILD_SHARED_LIBS into account.
    set(LIBTYPE)
  endif()
  llvm_add_library(${name} ${LIBTYPE} ${ARG_UNPARSED_ARGUMENTS} ${srcs})

  clang_target_link_libraries(${name} PRIVATE ${ARG_CLANG_LIBS})
  if (ARG_MLIR_LIBS)
    mlir_target_link_libraries(${name} PRIVATE ${ARG_MLIR_LIBS})
  endif()
  if (ARG_MLIR_DEPS AND NOT FLANG_STANDALONE_BUILD)
    add_dependencies(${name} ${ARG_MLIR_DEPS})
  endif()

  if (TARGET ${name})

    if (NOT LLVM_INSTALL_TOOLCHAIN_ONLY OR ${name} STREQUAL "libflang"
        OR ARG_INSTALL_WITH_TOOLCHAIN)
      get_target_export_arg(${name} Flang export_to_flangtargets UMBRELLA flang-libraries)
      install(TARGETS ${name}
        COMPONENT ${name}
        ${export_to_flangtargets}
        LIBRARY DESTINATION lib${LLVM_LIBDIR_SUFFIX}
        ARCHIVE DESTINATION lib${LLVM_LIBDIR_SUFFIX}
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")

      if (NOT LLVM_ENABLE_IDE)
        add_llvm_install_targets(install-${name}
                                 DEPENDS ${name}
                                 COMPONENT ${name})
      endif()

      set_property(GLOBAL APPEND PROPERTY FLANG_LIBS ${name})
    endif()
    set_property(GLOBAL APPEND PROPERTY FLANG_EXPORTS ${name})
    if (FLANG_PARALLEL_COMPILE_JOBS)
      set_property(TARGET ${name} PROPERTY JOB_POOL_COMPILE flang_compile_job_pool)
    endif()
  else()
    # Add empty "phony" target
    add_custom_target(${name})
  endif()

  set_target_properties(${name} PROPERTIES FOLDER "Flang/Libraries")
  set_flang_windows_version_resource_properties(${name})
endfunction(add_flang_library)

macro(add_flang_executable name)
  add_llvm_executable(${name} ${ARGN})
  set_flang_windows_version_resource_properties(${name})
endmacro(add_flang_executable)

macro(add_flang_tool name)
  if (NOT FLANG_BUILD_TOOLS)
    set(EXCLUDE_FROM_ALL ON)
  endif()

  add_flang_executable(${name} ${ARGN})

  if (FLANG_BUILD_TOOLS)
    get_target_export_arg(${name} Flang export_to_flangtargets)
    install(TARGETS ${name}
      ${export_to_flangtargets}
      RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
      COMPONENT ${name})

    if(NOT LLVM_ENABLE_IDE)
      add_llvm_install_targets(install-${name}
                               DEPENDS ${name}
                               COMPONENT ${name})
    endif()
    set_property(GLOBAL APPEND PROPERTY FLANG_EXPORTS ${name})
  endif()
endmacro()

macro(add_flang_symlink name dest)
  llvm_add_tool_symlink(FLANG ${name} ${dest} ALWAYS_GENERATE)
  # Always generate install targets
  llvm_install_symlink(FLANG ${name} ${dest} ALWAYS_GENERATE)
endmacro()
