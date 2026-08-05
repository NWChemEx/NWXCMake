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
# Sets project-wide CMake defaults for all NWChemEx repositories.
#
# Include this module immediately after ``project()`` and
# ``disable_in_source_builds``.  All settings respect values already defined
# by the user or a parent project (e.g. ``-DCMAKE_CXX_STANDARD=17``).
#
# Variables set (if not already defined)
# ---------------------------------------
# - ``CMAKE_BUILD_TYPE``            — defaults to ``Release``, or ``Debug``
#   when ``DEVELOPER_SETUP`` is ``ON``
# - ``CMAKE_CXX_STANDARD``          — defaults to ``20``
# - ``CMAKE_CXX_STANDARD_REQUIRED`` — defaults to ``ON``
# - ``CMAKE_CXX_SCAN_FOR_MODULES``  — defaults to ``OFF``
#
# Options defined
# ---------------
# - ``BUILD_TESTING``           (default ``OFF``) — build unit tests
# - ``BUILD_PYBIND11_BINDINGS`` (default ``ON``)  — build Python bindings
# - ``INTEGRATION_TESTING``     (default ``OFF``) — build integration tests
# - ``DEVELOPER_SETUP``         (default ``OFF``) — wire up the shared
#   pre-commit hooks for local development (see nwx_setup_pre_commit)
#
# Example usage:
#
# .. code-block:: cmake
#
#    project(my_project LANGUAGES CXX)
#    include(disable_in_source_builds)
#    include(set_default_nwx_options)
#]]

option(BUILD_TESTING           "Whether to build the unit tests"        OFF)
option(BUILD_PYBIND11_BINDINGS "Build Python bindings via pybind11"     ON)
option(INTEGRATION_TESTING     "Should we build the integration tests?" OFF)
option(ENABLE_SIGMA            "Enable Sigma for uncertainty tracking"  OFF)
option(DEVELOPER_SETUP         "Wire up local dev tooling (pre-commit)" OFF)

# The pybind11 module is a shared object, so everything it statically links
# against (including FetchContent'd dependencies like spdlog) must be built
# with -fPIC, and the project's own libraries are built shared to match.
if(BUILD_PYBIND11_BINDINGS)
    if(NOT DEFINED CMAKE_POSITION_INDEPENDENT_CODE)
        set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    endif()
    if(NOT DEFINED BUILD_SHARED_LIBS)
        set(BUILD_SHARED_LIBS ON)
    endif()
endif()

# install_target.cmake hardcodes "lib" (not GNUInstallDirs) for this
# project's own libraries. FetchContent'd dependencies that *do* respect
# GNUInstallDirs (e.g. spdlog) would otherwise install to a
# platform-specific directory instead -- notably "lib64" on RHEL/CentOS
# (and so manylinux) x86_64 images -- landing one level away from where a
# pybind11 extension's INSTALL_RPATH looks (see nwx_python_module.cmake),
# breaking wheel-repair tools (auditwheel/delocate) that can't find the
# library outside that rpath. Forcing this keeps every installed shared
# library in the one place the whole ecosystem's rpaths expect.
if(NOT DEFINED CMAKE_INSTALL_LIBDIR)
    set(CMAKE_INSTALL_LIBDIR lib)
endif()

if(NOT DEFINED CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    if(DEVELOPER_SETUP)
        set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
    else()
        set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    endif()
endif()

if(NOT DEFINED CMAKE_CXX_STANDARD)
    set(CMAKE_CXX_STANDARD 20)
endif()

if(NOT DEFINED CMAKE_CXX_STANDARD_REQUIRED)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()

if(NOT DEFINED CMAKE_CXX_SCAN_FOR_MODULES)
    set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
endif()

if(DEVELOPER_SETUP)
    set(BUILD_TESTING
        ON
        CACHE BOOL
        "Whether to build the unit tests"
        FORCE
    )
    set(INTEGRATION_TESTING
        ON
        CACHE BOOL
        "Should we build the integration tests?"
        FORCE
    )
    include(nwx_setup_pre_commit)
    nwx_setup_pre_commit()
endif()
