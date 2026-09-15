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
#     [PRIVATE_INCLUDES path ...]
#     [EXCLUDE_REGEX regex])
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
#
# EXCLUDE_REGEX drops any matching file from the glob (list(FILTER ...
# EXCLUDE REGEX) semantics) before it's compiled. Use this when a subtree of
# <dir> unconditionally #includes headers from a dependency that a caller
# has conditionally disabled and therefore cannot compile against:
#
#   catch2_tests_from_dir(unit_test_foo tests/cxx/unit_tests foo
#       EXCLUDE_REGEX ".*/xc/gauxc/.*\\.cpp$")
function(catch2_tests_from_dir ctfd_target_name ctfd_dir)
    if(NOT BUILD_TESTING)
        return()
    endif()

    cmake_parse_arguments(ctfd "" "EXCLUDE_REGEX" "PRIVATE_INCLUDES" ${ARGN})
    # ctfd_UNPARSED_ARGUMENTS = link libraries
    # ctfd_PRIVATE_INCLUDES   = extra private include dirs
    # ctfd_EXCLUDE_REGEX      = optional regex of files to drop from the glob

    include(get_dependencies)
    get_dependencies(catch2)

    file(GLOB_RECURSE ctfd_test_files CONFIGURE_DEPENDS ${ctfd_dir}/*.cpp)
    if(ctfd_EXCLUDE_REGEX)
        list(FILTER ctfd_test_files EXCLUDE REGEX "${ctfd_EXCLUDE_REGEX}")
    endif()

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

    # A test executable can acquire pybind11 transitively, from an ecosystem
    # dependency's public link interface rather than from anything the caller
    # asked for: nwx::pluginplay exports pybind11::pybind11 and Python::Module,
    # so a test that links, say, nwx::simde ends up compiling the CPython API
    # into an executable.
    #
    # Python::Module is deliberately headers-without-libpython. That is correct
    # for a loadable extension module -- the interpreter that dlopen()s it
    # already holds those symbols -- and wrong for an executable, which has no
    # interpreter underneath it. The failure is platform-shaped, so it is easy
    # to mistake for two bugs: Linux reports several hundred "undefined
    # reference to `Py...'" at link, while macOS links clean (Python::Module
    # implies -undefined dynamic_lookup) and instead aborts at startup on the
    # first eagerly-bound data symbol, "dyld: symbol not found in flat
    # namespace '_PyBaseObject_Type'".
    #
    # Development.Embed is the component carrying the real libpython, so
    # Python::Python supplies precisely what the executable is missing.
    #
    # This belongs here rather than in the public link interface of the
    # dependency that drags pybind11 in: a PUBLIC Python::Python would reach
    # every consumer, the pybind11 extension modules included, and an
    # extension module must never link libpython (auditwheel strips it --
    # "Linking with libpython is forbidden for manylinux/musllinux wheels").
    # Confining it to test executables keeps libpython out of the wheels.
    #
    # Gated on BUILD_PYBIND11_BINDINGS so a build that has deliberately turned
    # Python off does not acquire a hard requirement on an embeddable
    # libpython, which is a separate artifact from Development.Module and is
    # not installed everywhere.
    if(BUILD_PYBIND11_BINDINGS)
        find_package(Python REQUIRED COMPONENTS Interpreter Development.Embed)
        target_link_libraries(${ctfd_target_name} PRIVATE Python::Python)
    endif()

    add_test(NAME ${ctfd_target_name}
         COMMAND ${ctfd_target_name}
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
endfunction()
