cmake_minimum_required(VERSION 3.18)
project(openjpeg_bridge)

# Paths
set(OPENJPEG_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../openjpeg)
set(OPENJPEG_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/include)
set(OPENJPEG_PREBUILT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})


set(BRIDGE_SRC openjpeg_bridge_stub.cpp)
set(OPENJPEG_ENABLED OFF)

# Option 1: Build OpenJPEG from source tree if present
if(EXISTS ${OPENJPEG_SRC_DIR}/CMakeLists.txt)
    message(STATUS "Using OpenJPEG sources from ${OPENJPEG_SRC_DIR}")

    set(BUILD_CODEC OFF CACHE BOOL "" FORCE)
    set(BUILD_MJ2 OFF CACHE BOOL "" FORCE)
    set(BUILD_JPIP OFF CACHE BOOL "" FORCE)
    set(BUILD_JPWL OFF CACHE BOOL "" FORCE)
    set(BUILD_DOC OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

    add_subdirectory(${OPENJPEG_SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR}/openjpeg_build)

    set(BRIDGE_SRC openjpeg_bridge.cpp)
    set(OPENJPEG_ENABLED ON)


    )

    set(BRIDGE_SRC openjpeg_bridge.cpp)
    set(OPENJPEG_ENABLED ON)
else()
    message(WARNING "OpenJPEG sources/libs not found. Building stub decoder (native JP2 decode disabled).")
endif()

add_library(openjpeg_bridge SHARED ${BRIDGE_SRC})

find_library(log-lib log)

set(BRIDGE_LINK_LIBS "")
if(log-lib)
    list(APPEND BRIDGE_LINK_LIBS ${log-lib})
endif()

if(OPENJPEG_ENABLED)
    if(TARGET openjp2)
        target_link_libraries(openjpeg_bridge openjp2 ${BRIDGE_LINK_LIBS})
    else()
        target_link_libraries(openjpeg_bridge ${BRIDGE_LINK_LIBS})
    endif()

    if(EXISTS ${OPENJPEG_SRC_DIR}/CMakeLists.txt)
        target_include_directories(openjpeg_bridge PRIVATE
            ${OPENJPEG_SRC_DIR}/src/lib/openjp2
            ${CMAKE_CURRENT_BINARY_DIR}/openjpeg_build/src/lib/openjp2
        )
    else()
        target_include_directories(openjpeg_bridge PRIVATE
            ${OPENJPEG_INCLUDE_DIR}
        )
    endif()

    target_compile_definitions(openjpeg_bridge PRIVATE USE_OPENJPEG=1)
else()
    target_link_libraries(openjpeg_bridge ${BRIDGE_LINK_LIBS})
    target_compile_definitions(openjpeg_bridge PRIVATE NO_OPENJPEG=1)
endif()
