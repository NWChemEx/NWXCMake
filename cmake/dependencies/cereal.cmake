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

# cereal is header-only. Under FetchContent (add_subdirectory) cereal is not the
# master project, so its install target is off by default -- force CEREAL_INSTALL
# ON so the `cereal` interface target lands in an export set (required because
# consumers link it PUBLIC-ly and we install/export our target). JUST_INSTALL_CEREAL
# makes cereal return right after installing, skipping its docs/sandbox/tests.
# Honored by cereal's option() calls (policy CMP0077).
set(CEREAL_INSTALL ON CACHE BOOL "" FORCE)
set(JUST_INSTALL_CEREAL ON CACHE BOOL "" FORCE)

FetchContent_Declare(
    cereal
    GIT_REPOSITORY https://github.com/USCiLab/cereal
    GIT_TAG        "v1.3.2"
    SYSTEM
)

set(_gd_target_cereal "cereal::cereal")
