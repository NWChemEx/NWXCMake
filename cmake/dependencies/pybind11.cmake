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

# KEEP THIS TAG IN SYNC WITH THE "pybind11==" PIN IN EVERY ECOSYSTEM REPO'S
# pyproject.toml. pybind11 keys its type registry on PYBIND11_INTERNALS_VERSION,
# which is baked into each extension as
# __pybind11_internals_v<N>_<stdlib>_<abi>__. Two modules built against
# different N get SEPARATE registries and cannot exchange types, even though
# importing one from the other succeeds.
#
# That is not hypothetical: with this tag at v3.0.2 (internals v11) while
# pyproject.toml asked for an unpinned "pybind11" (pip resolved 3.1.0,
# internals v12), the published wheels were v11 and any local CMake build
# against them was v12. SCF'"'"'s test_cmake_build -- which pip installs the
# ecosystem and then builds SCF from source -- died with
#
#   TypeError: Unregistered type : parallelzone::runtime::RuntimeView
#
# from scf.initialize(), because scf'"'"'s locally built module could not see the
# RuntimeView the installed parallelzone wheel had registered. Wheel-only and
# source-only builds both worked, which is why it hid for so long.
#
# Version -> internals: 3.0.2 -> 11, 3.1.0 -> 12.
FetchContent_Declare(
    pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11
    GIT_TAG        "v3.1.0"
)
