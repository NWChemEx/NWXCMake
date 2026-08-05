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

# Boost is found via the system. Deliberately left in CMP0167 OLD (CMake's
# own bundled, deprecated-but-functional FindBoost module) rather than NEW
# (Boost's own exported BoostConfig.cmake, only shipped since 1.70) --
# nothing here uses more than the header-only Boost::boost umbrella target,
# which the legacy module provides identically, and OLD additionally works
# with the much older Boost still shipped by manylinux images' package
# managers (e.g. manylinux2014's boost-devel is 1.53.0). If a future
# consumer needs a Boost >= 1.70-only feature, switch this back to NEW.
# No include_guard: find_package is idempotent, and the _gd_uses_fc flag
# must be set every time this file is included so get_dependencies skips
# calling FetchContent_MakeAvailable for boost.
if(POLICY CMP0167)
    cmake_policy(SET CMP0167 OLD)
endif()
if(NOT Boost_FOUND)
    find_package(Boost REQUIRED)
endif()

# Boost::boost is the header-only umbrella target; individual component
# targets (e.g. Boost::filesystem) can be added by the caller as needed.
list(APPEND _gd_targets Boost::boost)
set(_gd_target_boost "Boost::boost")

# Boost is found via find_package, not FetchContent; opt out of the
# FetchContent_MakeAvailable call in get_dependencies.
set(_gd_uses_fc FALSE)
