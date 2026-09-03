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

# This fetches ryanmrichard/IntegratorXX -- a fork of upstream
# (wavefunction91) IntegratorXX with a reorganized header layout (e.g.
# quadratures/s2/lebedev_laikov.hpp instead of quadratures/lebedev_laikov.hpp)
# -- as the sole, authoritative "integratorxx" dependency, using the same
# find_package-then-FetchContent pattern as sibling dependency files (see
# gau2grid.cmake). This is only safe because SCF currently builds with
# GauXC disabled (BUILD_GAUXC=OFF): GauXC's own CMake (gauxc.cmake)
# transitively FetchContent_Declares upstream IntegratorXX under this same
# content name ("integratorxx") and target name ("IntegratorXX::IntegratorXX")
# pinned to the old, incompatible header layout. If GauXC is ever re-enabled
# without addressing that conflict, re-introduce the private-content-name /
# BEFORE-include-order workaround this file used to carry (see git history)
# instead of the plain pattern below.

# Resolution order: (1) a pre-installed copy reachable via the caller's own
# CMAKE_PREFIX_PATH (e.g. a hand-built or system-package IntegratorXX), (2) a
# previous build's copy already installed into the active venv's
# site-packages (NWX_VENV_SITE_PACKAGES, set by get_skbuild_python_path()),
# (3) fetch and build from source. CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY is
# already forced ON globally (get_dependencies.cmake), so step (1) can't
# resolve against a stale ~/.cmake/packages entry -- only CMAKE_PREFIX_PATH
# and the normal default search locations.
find_package(IntegratorXX CONFIG QUIET)
if(TARGET IntegratorXX::IntegratorXX)
    set(_gd_target_integratorxx "IntegratorXX::IntegratorXX")
    set(_gd_uses_fc FALSE)
    return()
endif()

# Step (2): reuse a previous build's copy instead of re-cloning and
# rebuilding IntegratorXX from source every time. Scoped to exactly that
# directory (NO_DEFAULT_PATH) so this can never accidentally match an
# unrelated system-wide install (e.g. Homebrew).
if(NWX_VENV_SITE_PACKAGES)
    unset(IntegratorXX_DIR CACHE)
    find_package(IntegratorXX CONFIG QUIET
        PATHS "${NWX_VENV_SITE_PACKAGES}" NO_DEFAULT_PATH
    )
endif()
if(TARGET IntegratorXX::IntegratorXX)
    set(_gd_target_integratorxx "IntegratorXX::IntegratorXX")
    set(_gd_uses_fc FALSE)
    return()
endif()

FetchContent_Declare(
    integratorxx
    GIT_REPOSITORY https://github.com/ryanmrichard/IntegratorXX.git
    GIT_TAG        master
    GIT_SUBMODULES ""
)

# Drive MakeAvailable here (instead of letting get_dependencies batch it) so we
# can build with tests off without leaving the parent project's BUILD_TESTING
# clobbered. Opt out of the batched call via _gd_uses_fc below.
set(_gd_bt_backup "${BUILD_TESTING}")
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(integratorxx)
set(BUILD_TESTING "${_gd_bt_backup}" CACHE BOOL "" FORCE)
unset(_gd_bt_backup)

# IntegratorXX's own CMakeLists.txt exports the alias
# "IntegratorXX::IntegratorXX" for its real target "integratorxx" even in an
# in-tree FetchContent build (the alias is created unconditionally, not just
# as part of install(EXPORT)).
set(_gd_target_integratorxx "IntegratorXX::IntegratorXX")
set(_gd_uses_fc FALSE)
