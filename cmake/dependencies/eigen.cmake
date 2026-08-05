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
include(FetchContent)

# Eigen is header-only. We download the source but skip add_subdirectory (to
# avoid Eigen's own install rules running as a subproject, which would produce
# a non-IMPORTED "eigen" build target that triggers CMake's install(EXPORT)
# export-set check even when used only as a PRIVATE dep).
FetchContent_Declare(
    eigen
    GIT_REPOSITORY https://gitlab.com/libeigen/eigen
    GIT_TAG        2e76277bd049f7bec36b0f908c69734a42c5234f
)
FetchContent_GetProperties(eigen)
if(NOT eigen_POPULATED)
    FetchContent_Populate(eigen)
endif()

# Expose a proper IMPORTED INTERFACE target. IMPORTED targets are never
# checked against export sets by install(EXPORT), which avoids the
# "target eigen not in any export set" error.
if(NOT TARGET Eigen3::Eigen)
    add_library(Eigen3::Eigen IMPORTED INTERFACE GLOBAL)
    set_target_properties(Eigen3::Eigen PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${eigen_SOURCE_DIR}"
    )
endif()

list(APPEND _gd_targets Eigen3::Eigen)
set(_gd_target_eigen "Eigen3::Eigen")
