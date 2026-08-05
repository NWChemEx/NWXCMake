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
include(get_version_from_git)

#[[[
# Determines a numeric project version suitable for ``project(VERSION ...)``.
#
# The version is resolved with the following priority:
#
# 1. ``SKBUILD_PROJECT_VERSION`` -- set by scikit-build-core when building a
#    wheel/sdist (derived from, e.g., setuptools-scm).
# 2. The most recent git tag, via :cmake:command:`get_version_from_git`.
# 3. ``0.1.0`` as a final fallback.
#
# Any PEP 440 style suffix (e.g. ``1.2.3.dev4+g1a2b3c``) is stripped down to the
# numeric ``MAJOR.MINOR.PATCH`` triple that ``project(VERSION ...)`` accepts.
# This function is safe to call *before* ``project()``.
#
# :param _nsv_out: Name of the variable to assign the resolved version to.
# :type _nsv_out: desc*
# :param _nsv_git_root: Directory containing the ``.git/`` directory, forwarded
#                       to :cmake:command:`get_version_from_git`.
# :type _nsv_git_root: path
#
# .. code-block:: cmake
#
#    include(nwx_set_version)
#    nwx_set_version(MY_PROJECT_VERSION "${CMAKE_CURRENT_LIST_DIR}")
#    project(my_project VERSION "${MY_PROJECT_VERSION}" LANGUAGES CXX)
#]]
function(nwx_set_version _nsv_out _nsv_git_root)
    if(DEFINED SKBUILD_PROJECT_VERSION AND NOT SKBUILD_PROJECT_VERSION STREQUAL "")
        set(_nsv_raw "${SKBUILD_PROJECT_VERSION}")
    else()
        get_version_from_git(_nsv_raw "${_nsv_git_root}")
    endif()

    if(_nsv_raw MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)")
        set(${_nsv_out} "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}"
            PARENT_SCOPE
        )
    else()
        message(WARNING
            "nwx_set_version: could not parse a numeric version from "
            "\"${_nsv_raw}\"; defaulting to 0.1.0"
        )
        set(${_nsv_out} "0.1.0" PARENT_SCOPE)
    endif()
endfunction()
