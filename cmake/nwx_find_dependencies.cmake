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

#[[[
# Find-only dependency resolution for *installed* packages.
#
# This is the consume-time counterpart to ``get_dependencies()``, and the two
# are deliberately not the same thing. ``get_dependencies()`` may fall back to
# FetchContent: ``dependencies/pybind11.cmake``, for instance, does nothing
# *but* declare a FetchContent source. That is correct while building a
# project and completely wrong inside a downstream consumer's
# ``find_package()``, where it would clone a dependency and graft build
# targets into a project that only asked to link an imported library.
#
# So this module never fetches. It only knows the thing a plain
# ``find_dependency()`` cannot know: *where a pip-installed ecosystem puts
# its CMake packages*, and which components a target actually needs.
# ``pybind11``'s wheel, for example, installs its config under
# ``<platlib>/pybind11/share/cmake/pybind11`` rather than the
# ``<prefix>/lib/cmake/<name>`` that ``find_package`` searches, and
# ``Python::Module`` only exists if the ``Development.Module`` component was
# requested -- a bare ``find_package(Python)`` defaults to ``Interpreter``
# and silently leaves that target undefined.
#]]
include_guard()
include(CMakeFindDependencyMacro)

#[[[
# Puts the active interpreter's site-packages on CMAKE_PREFIX_PATH.
#
# Ecosystem wheels install their headers, libraries and CMake configs into the
# platlib directory, so that is where a consumer has to look. Cached in a
# global property: a consumer typically pulls in several ecosystem packages
# and each one's config calls this, but the Python query only needs doing
# once.
#]]
macro(nwx_config_python_prefix)
    get_property(_ncpp_done GLOBAL PROPERTY NWX_CONFIG_PYTHON_PREFIX_DONE)
    if(NOT _ncpp_done)
        find_package(Python QUIET COMPONENTS Interpreter)
        if(Python_Interpreter_FOUND)
            execute_process(
                COMMAND "${Python_EXECUTABLE}" -c
                    "import sysconfig; print(sysconfig.get_path('platlib'))"
                OUTPUT_VARIABLE _ncpp_platlib
                OUTPUT_STRIP_TRAILING_WHITESPACE
                RESULT_VARIABLE _ncpp_rc
            )
            if(_ncpp_rc EQUAL 0 AND IS_DIRECTORY "${_ncpp_platlib}")
                set_property(GLOBAL PROPERTY NWX_CONFIG_PLATLIB "${_ncpp_platlib}")
            endif()
        endif()
        set_property(GLOBAL PROPERTY NWX_CONFIG_PYTHON_PREFIX_DONE TRUE)
    endif()
    get_property(NWX_CONFIG_PLATLIB GLOBAL PROPERTY NWX_CONFIG_PLATLIB)
endmacro()

#[[[
# find_dependency() for one package named in an installed link interface.
#
# :param ncfd_pkg: Package name, as derived from the exported target's
#                  namespace (``nwx::chemist`` -> chemist, ``Eigen3::Eigen``
#                  -> Eigen3).
#]]
macro(nwx_config_find_dependency ncfd_pkg)
    nwx_config_python_prefix()

    if("${ncfd_pkg}" STREQUAL "Python")
        # Python::Module, the target pybind11 modules link against, is only
        # defined when Development.Module is requested.
        find_dependency(Python COMPONENTS Development.Module)
    elseif("${ncfd_pkg}" STREQUAL "pybind11")
        # The wheel's config is under <platlib>/pybind11/share/cmake, which is
        # not a prefix find_package searches. Hint it explicitly, then fall
        # back to an ordinary search for a system/conda install.
        if(NWX_CONFIG_PLATLIB AND NOT pybind11_FOUND)
            find_package(pybind11 QUIET CONFIG
                PATHS "${NWX_CONFIG_PLATLIB}/pybind11/share/cmake/pybind11"
                NO_DEFAULT_PATH
            )
        endif()
        if(NOT pybind11_FOUND)
            find_dependency(pybind11)
        endif()
    elseif("${ncfd_pkg}" STREQUAL "MPI")
        find_dependency(MPI COMPONENTS CXX)
    else()
        # Ecosystem packages (installed as siblings under this prefix) and
        # anything else with a well-behaved config or find module.
        find_dependency(${ncfd_pkg})
    endif()
endmacro()
