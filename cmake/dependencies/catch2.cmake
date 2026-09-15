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

# Same class of bug as dependencies/pybind11.cmake, latent rather than live.
# Catch2 names its targets Catch2 / Catch2::Catch2; CMake target names are
# case-sensitive, so get_dependencies()'s default check for a target named
# "catch2" never matches and the already-resolved short-circuit never fires.
# Nothing find_package()es Catch2 ahead of get_dependencies() today -- it is
# test-only and so never appears in an installed target's
# INTERFACE_LINK_LIBRARIES, hence no config declares it -- which leaves
# FetchContent_MakeAvailable()'s own dedup as the only thing standing between
# this and pybind11's duplicate-target failure. Key on the real target name so
# it does not depend on that.
set(_gd_target_catch2 "Catch2::Catch2")

FetchContent_Declare(
    catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2
    GIT_TAG "v3.11.0"
)
