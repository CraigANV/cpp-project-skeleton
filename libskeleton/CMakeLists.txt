cmake_minimum_required(VERSION 3.12 FATAL_ERROR)
project(libskeleton VERSION 1.2.3 LANGUAGES CXX)

set(VERBOSE ON)
set(CMAKE_FIND_DEBUG_MODE ON)

##############################################
# Building & Testing

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif (NOT CMAKE_BUILD_TYPE)

set(CMAKE_DEBUG_POSTFIX "-d")

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/)

if(USE_CONAN_PACKAGE)
    include(${CMAKE_BINARY_DIR}/conan_paths.cmake)
    set(BOOST_ROOT ${CONAN_BOOST_ROOT})
    set(POCO_ROOT ${CONAN_POCO_ROOT})
    set(OPENCV_ROOT ${CONAN_OPENCV_ROOT})
    set(GTEST_ROOT ${CONAN_GTEST_ROOT})
endif(USE_CONAN_PACKAGE)

find_package(GTest REQUIRED)

# This is an example of missing information propagation using cmake_paths generator
# This is needed for the Conan package in Windows.
set(Boost_USE_STATIC_LIBS ON CACHE BOOL "For Windows: ON = static library/ OFF = dynamic library")
find_package(Boost REQUIRED COMPONENTS system chrono)

set(POCO_STATIC ON CACHE BOOL "For Windows: ON = static library/ OFF = dynamic library")
find_package(Poco REQUIRED COMPONENTS Foundation)

set(OpenCV_STATIC ON CACHE BOOL "For Windows: ON = static library/ OFF = dynamic library")
find_package(OpenCV REQUIRED COMPONENTS core)

set(LIB_SKELETON "skeleton")
add_library(${LIB_SKELETON} src/skeleton.cpp)

# Add an alias so that library can be used inside the build tree, e.g. when testing
add_library(Skeleton::Skeleton ALIAS ${LIB_SKELETON})

target_compile_options(${LIB_SKELETON}
    PRIVATE
        $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:AppleClang>,$<CXX_COMPILER_ID:GNU>>:-Wall -Wextra -Wpedantic>
)

# Add sources to the library
# Header files are added only so that they appear in IDEs such as Visual Studio etc
# For INTERFACE libraries (header only) this is the only way to make the header
# files appear in the project in IDEs such as Visual Studio
target_sources(${LIB_SKELETON}
    PRIVATE
        ${src_files}
        ${header_files}
)

# Add directories to the target
# PRIVATE and PUBLIC items will populate the INCLUDE_DIRECTORIES property of target
# PUBLIC and INTERFACE items will populate the INTERFACE_INCLUDE_DIRECTORIES property of target
target_include_directories(${LIB_SKELETON}
    PUBLIC
        $<INSTALL_INTERFACE:include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)

target_link_libraries(${LIB_SKELETON}
	PUBLIC
        Boost::chrono
        opencv_core
    PRIVATE
        Poco::Foundation
)

#print_target_properties(${LIB_SKELETON})

enable_testing()
add_executable(skeleton_tester test/skeleton_tester.cpp)
target_link_libraries(skeleton_tester ${LIB_SKELETON} GTest::GTest ${OpenCV_LIBS})
target_include_directories(skeleton_tester PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include ${GTEST_INCLUDE_DIRS} ${OpenCV_INCLUDE_DIRS})
add_test(Skeleton.Test skeleton_tester)

##############################################
# Installation

include(GNUInstallDirs)
set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/Skeleton)

# This is required so that the exported target has the name Skeleton and not skeleton
set_target_properties(skeleton PROPERTIES EXPORT_NAME Skeleton)

install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(
    TARGETS skeleton
    EXPORT SkeletonTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Export the targets to a script
install(EXPORT SkeletonTargets
    FILE
        SkeletonTargets.cmake
    NAMESPACE
        Skeleton::
    DESTINATION
        ${INSTALL_CONFIGDIR}
)

# Create a ConfigVersion.cmake file
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/SkeletonConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(
    ${CMAKE_CURRENT_LIST_DIR}/cmake/SkeletonConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/SkeletonConfig.cmake
    INSTALL_DESTINATION ${INSTALL_CONFIGDIR}
    PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
)

export(
    EXPORT SkeletonTargets
    FILE ${CMAKE_CURRENT_BINARY_DIR}/SkeletonTargets.cmake
    NAMESPACE Skeleton::
)

# Install the config, configversion and dependency find modules
install(
    FILES
        ${CMAKE_CURRENT_BINARY_DIR}/SkeletonConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/SkeletonConfigVersion.cmake
    DESTINATION
        ${INSTALL_CONFIGDIR}
)

# Register package in user's package registry
export(PACKAGE Skeleton)

##############################################
# Packaging

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "CPP Skeleton Project Lib")
set(CPACK_PACKAGE_VENDOR "Craig Carey")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/../LICENSE")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(CPACK_PACKAGE_INSTALL_DIRECTORY "CMake ${CMake_VERSION_MAJOR}.${CMake_VERSION_MINOR}.${CMake_VERSION_PATCH}")
set(CPACK_SOURCE_STRIP_FILES "") # TODO: ensure stripping works

if (WIN32)
    set(CPACK_GENERATOR "ZIP;") # TODO: WIX
elseif(UNIX)
    set(CPACK_GENERATOR "STGZ;TGZ;ZIP;") # TODO: DEB
endif()

include(CPack)
