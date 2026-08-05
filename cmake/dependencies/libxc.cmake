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

# Reuse a previously-installed copy from the active venv's site-packages
# (NWX_VENV_SITE_PACKAGES, set by get_skbuild_python_path()) if one exists,
# instead of re-cloning and rebuilding libxc from source every time. Scoped
# to exactly that directory (NO_DEFAULT_PATH) so this can never accidentally
# match an unrelated system-wide install (e.g. Homebrew).
if(NWX_VENV_SITE_PACKAGES)
    # A dependency fetched earlier in this same configure (e.g. GauXC, which
    # transitively fetches its own libxc) can leave a stale/negative
    # Libxc_DIR cache entry behind from its own unrelated, unscoped
    # find_package() attempt; clear it first so our scoped lookup below
    # always gets a fresh, authoritative search.
    unset(Libxc_DIR CACHE)
    find_package(Libxc CONFIG QUIET
        PATHS "${NWX_VENV_SITE_PACKAGES}" NO_DEFAULT_PATH
    )
endif()
if(TARGET Libxc::xc)
    set(_gd_target_libxc "Libxc::xc")
    set(_gd_uses_fc FALSE)
    return()
endif()

FetchContent_Declare(
    libxc
    GIT_REPOSITORY https://gitlab.com/libxc/libxc
    GIT_TAG        devel
)

# Drive MakeAvailable here (instead of letting get_dependencies batch it) so we
# can build libxc with tests off without leaving the parent project's
# BUILD_TESTING clobbered. Opt out of the batched call via _gd_uses_fc below.
set(_gd_bt_backup "${BUILD_TESTING}")
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(libxc)
set(BUILD_TESTING "${_gd_bt_backup}" CACHE BOOL "" FORCE)
unset(_gd_bt_backup)

# libxc's CMakeLists only defines the plain "xc" target; "Libxc::xc" is an
# imported-target alias created by its install(EXPORT) rule, which doesn't
# exist for an in-tree FetchContent build (same situation as gau2grid's "gg").
set(_gd_target_libxc "xc")
set(_gd_uses_fc FALSE)
