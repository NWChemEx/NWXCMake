# Copyright 2026 NWChemEx-Project
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

#[[[
# Adds an executable that links against ecosystem libraries.
#
# Use this instead of a bare ``add_executable()`` for any executable built
# alongside an NWChemEx library (examples, drivers, test programs);
# catch2_tests_from_dir() builds its test executables with it too. On top of
# ``add_executable()`` it:
#
# - links each ``DEPENDS`` entry PRIVATE,
# - adds the site-packages build rpath (see nwx_site_packages_rpath.cmake), so
#   the executable still loads when run from the build tree after pip's
#   temporary build env is gone, and
# - links libpython when ``BUILD_PYBIND11_BINDINGS`` is on (see below).
#
# An executable can acquire pybind11 transitively, from an ecosystem
# dependency's public link interface rather than from anything the caller
# asked for: nwx::pluginplay exports pybind11::pybind11 and Python::Module, so
# an executable that links, say, nwx::simde ends up compiling the CPython API
# in.
#
# Python::Module is deliberately headers-without-libpython. That is correct
# for a loadable extension module -- the interpreter that dlopen()s it already
# holds those symbols -- and wrong for an executable, which has no interpreter
# underneath it. The failure is platform-shaped, so it is easy to mistake for
# two bugs: Linux reports "undefined reference to `Py...'" at link, while
# macOS links clean (Python::Module implies -undefined dynamic_lookup) and
# instead aborts at startup on the first eagerly-bound data symbol, "dyld:
# symbol not found in flat namespace '_PyBaseObject_Type'".
#
# Development.Embed is the component carrying the real libpython, so
# Python::Python supplies precisely what the executable is missing.
#
# This belongs here rather than in the public link interface of the
# dependency that drags pybind11 in: a PUBLIC Python::Python would reach every
# consumer, the pybind11 extension modules included, and an extension module
# must never link libpython (auditwheel strips it -- "Linking with libpython
# is forbidden for manylinux/musllinux wheels"). An exported Python::Python is
# also a dangling target in any consumer whose config only finds
# Development.Module. Confining it to executables keeps libpython out of the
# wheels.
#
# Gated on BUILD_PYBIND11_BINDINGS so a build that has deliberately turned
# Python off does not acquire a hard requirement on an embeddable libpython,
# which is a separate artifact from Development.Module and is not installed
# everywhere.
#
# Example::
#
#   include(nwx_executable)
#   nwx_executable(my_example examples/my_example/main.cpp
#       DEPENDS ${PROJECT_NAME})
#
# :param ne_target: Name of the executable target to create.
# :type ne_target: str
# :param ARGN: Source files, followed by an optional ``DEPENDS`` list of
#              targets to link PRIVATE.
#]]
function(nwx_executable ne_target)
    cmake_parse_arguments(ne "" "" "DEPENDS" ${ARGN})
    # ne_UNPARSED_ARGUMENTS = source files
    # ne_DEPENDS            = libraries to link PRIVATE

    add_executable(${ne_target} ${ne_UNPARSED_ARGUMENTS})
    target_link_libraries(${ne_target} PRIVATE ${ne_DEPENDS})

    include(nwx_site_packages_rpath)
    nwx_add_site_packages_build_rpath(${ne_target})

    if(BUILD_PYBIND11_BINDINGS)
        find_package(Python REQUIRED COMPONENTS Interpreter Development.Embed)
        target_link_libraries(${ne_target} PRIVATE Python::Python)
    endif()
endfunction()
