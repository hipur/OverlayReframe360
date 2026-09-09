cmake_minimum_required(VERSION 3.21)

# NOTE (macOS): the universal-binary arch list lives in the `macos` configure preset
# (CMAKE_OSX_ARCHITECTURES=arm64;x86_64) because it must be set before project() and
# APPLE is not defined until project() runs. Configuring on macOS without that preset
# yields a host-arch-only bundle.
project(OverlayReframe360 LANGUAGES C CXX)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "64-bit toolchain required (run vcvars64.bat)")
endif()

if(APPLE)
  enable_language(OBJC OBJCXX)
endif()

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# src/MetalKernel.mm compiles at the same locked standard (ignored off Apple).
set(CMAKE_OBJCXX_STANDARD 14)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_EXTENSIONS OFF)

# ---------------------------------------------------------------- paths / options

if(WIN32)
  set(_ofx_sdk_default "C:/ProgramData/Blackmagic Design/DaVinci Resolve/Support/Developer/OpenFX")
  set(_ofx_plugin_default "C:/Program Files/Common Files/OFX/Plugins")
  set(OFX_ARCH_DIR "Win64")
elseif(APPLE)
  set(_ofx_sdk_default "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX")
  set(_ofx_plugin_default "/Library/OFX/Plugins")
  set(OFX_ARCH_DIR "MacOS")
endif()

set(OFX_SDK_DIR "${_ofx_sdk_default}" CACHE PATH "DaVinci Resolve's OpenFX SDK root")
set(OFX_PLUGIN_DIR "${_ofx_plugin_default}" CACHE PATH "Where the .ofx.bundle is installed")

if(NOT EXISTS "${OFX_SDK_DIR}/Support/include/ofxsImageEffect.h")
  message(FATAL_ERROR
    "OpenFX SDK not found: '${OFX_SDK_DIR}/Support/include/ofxsImageEffect.h' does not exist. "
    "Pass -DOFX_SDK_DIR=<Resolve OpenFX SDK root>.")
endif()

option(REFRAME_DEBUG_LOG "spdlog sinks + ~/reframe.*.log" OFF)

# ---------------------------------------------------------------- OpenCL

if(WIN32)
  # Resolve's SDK ships no OpenCL import library and the Windows SDK has none. Build one
  # at configure time from cmake/OpenCL.def against the system ICD loader (System32\OpenCL.dll).
  # CMAKE_AR is lib.exe (absolute path), so this works without vcvars on PATH.
  if(NOT CMAKE_AR)
    message(FATAL_ERROR "CMAKE_AR is empty: cannot build OpenCL.lib. Expected MSVC's lib.exe.")
  endif()

  set(_opencl_def "${CMAKE_SOURCE_DIR}/cmake/OpenCL.def")
  set(_opencl_lib "${CMAKE_BINARY_DIR}/lib/OpenCL.lib")

  # Only rebuild when stale: rewriting the .lib on every re-configure bumps its mtime and
  # forces a needless relink of the module.
  if(NOT EXISTS "${_opencl_lib}" OR "${_opencl_def}" IS_NEWER_THAN "${_opencl_lib}")
    message(STATUS "Building OpenCL.lib from cmake/OpenCL.def")
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
    execute_process(
      COMMAND "${CMAKE_AR}" /nologo "/def:${_opencl_def}" /machine:x64 "/out:${_opencl_lib}"
      RESULT_VARIABLE _rc
      OUTPUT_VARIABLE _lib_out
      ERROR_VARIABLE _lib_out)
    if(NOT _rc EQUAL 0)
      message(FATAL_ERROR "Failed to build OpenCL.lib from cmake/OpenCL.def (exit ${_rc}):\n${_lib_out}")
    endif()
  else()
    message(STATUS "Building OpenCL.lib from cmake/OpenCL.def - skipped (up to date)")
  endif()

  add_library(OpenCL::OpenCL STATIC IMPORTED)
  set_target_properties(OpenCL::OpenCL PROPERTIES
    IMPORTED_LOCATION "${_opencl_lib}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/OpenCL-Headers")
elseif(APPLE)
  add_library(OpenCL::OpenCL INTERFACE IMPORTED)
  set_target_properties(OpenCL::OpenCL PROPERTIES
    INTERFACE_LINK_LIBRARIES "-framework OpenCL")
endif()

# ---------------------------------------------------------------- sources

set(SOURCES
  src/ImageScaler.cpp
  src/OpenCLKernel.cpp
  src/Parameters.cpp
  src/Reframe360.cpp
  src/Reframe360Factory.cpp
  src/Reframe360TransformInteract.cpp
  src/lodepng.cpp

  # Blackmagic's C++ support library, compiled straight from the SDK (no copy into ./Library).
  # ofxsHWNDInteract.cpp is deliberately excluded: it only serves the HWND custom-param UI.
  "${OFX_SDK_DIR}/Support/Library/ofxsCore.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsImageEffect.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsInteract.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsLog.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsMultiThread.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsParams.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsProperty.cpp"
  "${OFX_SDK_DIR}/Support/Library/ofxsPropertyValidation.cpp"

  openfx-supportext/ofxsOGLTextRenderer.cpp
  openfx-supportext/ofxsOGLFontData.cpp)

if(APPLE)
  list(APPEND SOURCES src/utils.cpp src/AccessibilityEvent.m src/MetalKernel.mm)
elseif(WIN32 AND EXISTS "${CMAKE_SOURCE_DIR}/src/utils_win.cpp")
  list(APPEND SOURCES src/utils_win.cpp)
endif()

# ---------------------------------------------------------------- spdlog

set(SPDLOG_BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
set(SPDLOG_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(SPDLOG_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory(spdlog EXCLUDE_FROM_ALL)

# ---------------------------------------------------------------- the plugin

add_library(OverlayReframe360 MODULE ${SOURCES})

set_target_properties(OverlayReframe360 PROPERTIES
  PREFIX ""
  SUFFIX ".ofx"
  CXX_VISIBILITY_PRESET hidden
  OBJCXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/OverlayReframe360.ofx.bundle/Contents/${OFX_ARCH_DIR}"
  # ARCHIVE and PDB both leave the bundle: MSVC drops an import .lib/.exp next to the
  # module, and a RelWithDebInfo .pdb would otherwise be shipped by install().
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
  PDB_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

configure_file(cmake/Info.plist
  "${CMAKE_BINARY_DIR}/OverlayReframe360.ofx.bundle/Contents/Info.plist" COPYONLY)

target_include_directories(OverlayReframe360 PRIVATE
  src
  images
  "${OFX_SDK_DIR}/OpenFX-1.4/include"
  "${OFX_SDK_DIR}/Support/include"
  openfx-supportext
  glm
  json/single_include)

if(EXISTS "${OFX_SDK_DIR}/Support/Plugins/include")
  target_include_directories(OverlayReframe360 PRIVATE "${OFX_SDK_DIR}/Support/Plugins/include")
endif()

target_compile_definitions(OverlayReframe360 PRIVATE CL_TARGET_OPENCL_VERSION=120)
if(REFRAME_DEBUG_LOG)
  target_compile_definitions(OverlayReframe360 PRIVATE DEBUG)
endif()

target_link_libraries(OverlayReframe360 PRIVATE spdlog::spdlog OpenCL::OpenCL)

if(WIN32)
  target_compile_definitions(OverlayReframe360 PRIVATE
    WIN32 _WINDOWS _USRDLL NOMINMAX WIN32_LEAN_AND_MEAN)
  target_compile_options(OverlayReframe360 PRIVATE /EHsc /W3)
  target_link_libraries(OverlayReframe360 PRIVATE opengl32 glu32)
elseif(APPLE)
  target_compile_options(OverlayReframe360 PRIVATE -Wno-deprecated-declarations)
  target_link_libraries(OverlayReframe360 PRIVATE
    "-framework OpenGL" "-framework Metal" "-framework AppKit")
endif()

# ---------------------------------------------------------------- regen-headers (not in ALL)

# The generated headers (src/MetalKernel.h, src/OpenCLKernel.h, images/*.png.h) are committed
# and stay out of the build graph. Run `cmake --build <dir> --target regen-headers` after
# editing a .metal/.cl/.png source; the diff must otherwise be empty.
if(WIN32 AND EXISTS "${CMAKE_SOURCE_DIR}/.venv/Scripts/python.exe")
  set(REGEN_PYTHON "${CMAKE_SOURCE_DIR}/.venv/Scripts/python.exe")
else()
  find_program(REGEN_PYTHON NAMES python3 python)
endif()

find_program(XXD_EXECUTABLE xxd)

set(_xxd_commands)
if(XXD_EXECUTABLE)
  file(GLOB _pngs RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/images/*.png")
  foreach(_png IN LISTS _pngs)
    list(APPEND _xxd_commands
      COMMAND "${CMAKE_COMMAND}" "-DXXD=${XXD_EXECUTABLE}" "-DIN=${_png}" "-DOUT=${_png}.h"
              -P "${CMAKE_SOURCE_DIR}/cmake/xxd_include.cmake")
  endforeach()
else()
  list(APPEND _xxd_commands
    COMMAND "${CMAKE_COMMAND}" -E echo
            "xxd not found: images/*.png.h left untouched (install xxd and re-configure)")
endif()

set(_kernel_commands)
if(REGEN_PYTHON)
  list(APPEND _kernel_commands
    COMMAND "${REGEN_PYTHON}" metal2string.py src/MetalKernel.metal src/MetalKernel.h
    COMMAND "${REGEN_PYTHON}" HardcodeKernel.py src/OpenCLKernel src/OpenCLKernel.cl)
else()
  list(APPEND _kernel_commands
    COMMAND "${CMAKE_COMMAND}" -E echo
            "python not found: src/MetalKernel.h and src/OpenCLKernel.h left untouched")
endif()

add_custom_target(regen-headers
  ${_kernel_commands}
  ${_xxd_commands}
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Regenerating committed kernel/image headers")

# ---------------------------------------------------------------- install

# On Windows OFX_PLUGIN_DIR is admin-only: `cmake --install` needs an elevated shell.
install(DIRECTORY "${CMAKE_BINARY_DIR}/OverlayReframe360.ofx.bundle"
  DESTINATION "${OFX_PLUGIN_DIR}"
  USE_SOURCE_PERMISSIONS)
