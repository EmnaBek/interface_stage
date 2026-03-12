cmake_minimum_required(VERSION 3.18)
project(openjpeg_bridge)

# --- Slim OpenJPEG build (optional) ---
set(BUILD_CODEC OFF CACHE BOOL "" FORCE)
set(BUILD_MJ2   OFF CACHE BOOL "" FORCE)
set(BUILD_JPIP  OFF CACHE BOOL "" FORCE)
set(BUILD_JPWL  OFF CACHE BOOL "" FORCE)
set(BUILD_DOC   OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
# We’ll link against static openjp2 if available
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# --- Bring in OpenJPEG ---
# Adjust this path if you placed the openjpeg repo elsewhere:
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../openjpeg
                 ${CMAKE_CURRENT_BINARY_DIR}/openjpeg_build)

# --- Our JNI bridge .so ---
add_library(openjpeg_bridge SHARED
    openjpeg_bridge.cpp
)

target_include_directories(openjpeg_bridge PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../openjpeg/src/lib/openjp2         # source headers
    ${CMAKE_CURRENT_BINARY_DIR}/openjpeg_build/src/lib/openjp2      # generated headers
)

# NDK log
find_library(log-lib log)

# Link our bridge to OpenJPEG
target_link_libraries(openjpeg_bridge
    openjp2
    ${log-lib}
)
