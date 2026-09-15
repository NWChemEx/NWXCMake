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
include(FetchContent)

# pybind11 never defines a target named "pybind11", so without this override
# get_dependencies()'s already-resolved check (TARGET ${NWX_DEP_TARGET_pybind11},
# defaulting to the bare dep name) can never fire. That was survivable while
# FetchContent_MakeAvailable() was the only way pybind11 entered a build -- it
# dedups internally, so the repeated "Fetching dependency: pybind11" lines cost
# nothing but noise.
#
# It stopped being survivable once the generated <name>Config.cmake files
# started declaring their real dependencies: pluginplayConfig.cmake now calls
# nwx_config_find_dependency(pybind11), which find_package()es the wheel's
# config and creates pybind11::pybind11 et al. as IMPORTED targets. A later
# get_dependencies(pybind11) would miss them, fall through to
# FetchContent_MakeAvailable(), and add_subdirectory() pybind11's own
# CMakeLists -- which then dies trying to re-create those same targets
# ("add_library cannot create ALIAS target \"pybind11::pybind11_headers\"
# because another target with the same name already exists").
#
# pybind11::pybind11 is the right name to key on: tools/pybind11Common.cmake
# creates it, and both provisioning paths include that file -- the installed
# wheel's config directly, and the fetched source via its CMakeLists.
set(_gd_target_pybind11 "pybind11::pybind11")

FetchContent_Declare(
    pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11
    GIT_TAG        "v3.0.2"
)
