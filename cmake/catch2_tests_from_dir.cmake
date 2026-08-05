# Copyright 2025 NWChemEx-Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_guard()

# enable_testing() (called internally by include(CTest)) has no effect when
# called from inside a function -- it must run at directory scope. Calling it
# here, once, at file-include time keeps the function itself free to be a
# no-op guard via BUILD_TESTING without silently failing to register any
# tests when BUILD_TESTING is ON.
include(CTest)

# catch2_tests_from_dir(target dir [link_lib ...]
#     [PRIVATE_INCLUDES path ...])
#
# Builds a Catch2 test executable from all *.cpp files under <dir>, links it
# against Catch2::Catch2WithMain and any additional <link_lib>s, registers it
# with CTest, and adds <dir> itself as a PRIVATE include (so test-local headers
# like test_common.hpp are findable without a path prefix).
#
# No-op when BUILD_TESTING is OFF, so callers do not need an
# if(BUILD_TESTING)/endif() guard around individual calls.
#
# PRIVATE_INCLUDES accepts additional directories (relative paths are resolved
# against CMAKE_CURRENT_SOURCE_DIR) to add as PRIVATE includes. Use this to
# expose the library's private implementation headers to the test target:
#
#   catch2_tests_from_dir(unit_test_foo tests/cxx/unit_tests foo
#       PRIVATE_INCLUDES cxx/src)
function(catch2_tests_from_dir ctfd_target_name ctfd_dir)
    if(NOT BUILD_TESTING)
        return()
    endif()

    cmake_parse_arguments(ctfd "" "" "PRIVATE_INCLUDES" ${ARGN})
    # ctfd_UNPARSED_ARGUMENTS = link libraries
    # ctfd_PRIVATE_INCLUDES   = extra private include dirs

    include(get_dependencies)
    get_dependencies(catch2)

    file(GLOB_RECURSE ctfd_test_files CONFIGURE_DEPENDS ${ctfd_dir}/*.cpp)

    add_executable(${ctfd_target_name} ${ctfd_test_files})

    # The test dir itself is always on the include path so test-local headers
    # (e.g. test_common.hpp) resolve without a prefix.
    target_include_directories(${ctfd_target_name} PRIVATE "${ctfd_dir}")

    foreach(_inc ${ctfd_PRIVATE_INCLUDES})
        if(IS_ABSOLUTE "${_inc}")
            target_include_directories(${ctfd_target_name} PRIVATE "${_inc}")
        else()
            target_include_directories(${ctfd_target_name} PRIVATE
                "${CMAKE_CURRENT_SOURCE_DIR}/${_inc}")
        endif()
    endforeach()

    target_link_libraries(
        ${ctfd_target_name} PRIVATE Catch2::Catch2WithMain ${ctfd_UNPARSED_ARGUMENTS})

    add_test(NAME ${ctfd_target_name}
         COMMAND ${ctfd_target_name}
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
endfunction()
