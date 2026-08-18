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

# Resolution order: (1) a pre-installed copy reachable via the caller's own
# CMAKE_PREFIX_PATH (e.g. a hand-built or system-package gau2grid), (2) a
# previous build's copy already installed into the active venv's
# site-packages (NWX_VENV_SITE_PACKAGES, set by get_skbuild_python_path()),
# (3) fetch and build from source. CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY is
# already forced ON globally (get_dependencies.cmake), so step (1) can't
# resolve against a stale ~/.cmake/packages entry -- only CMAKE_PREFIX_PATH
# and the normal default search locations.
find_package(gau2grid CONFIG QUIET)
if(TARGET gau2grid::gg)
    set(_gd_target_gau2grid "gau2grid::gg")
    set(_gd_uses_fc FALSE)
    return()
endif()

# Step (2): reuse a previous build's copy instead of re-cloning and
# rebuilding gau2grid from source every time. Scoped to exactly that
# directory (NO_DEFAULT_PATH) so this can never accidentally match an
# unrelated system-wide install (e.g. Homebrew).
if(NWX_VENV_SITE_PACKAGES)
    # GauXC's own (unrelated, unscoped) internal find_package(gau2grid) call
    # for its own grid-generation code can leave a stale/negative
    # gau2grid_DIR cache entry behind from earlier in this same configure;
    # clear it first so our scoped lookup below always gets a fresh,
    # authoritative search instead of silently reusing that unrelated result.
    unset(gau2grid_DIR CACHE)
    find_package(gau2grid CONFIG QUIET
        PATHS "${NWX_VENV_SITE_PACKAGES}" NO_DEFAULT_PATH
    )
endif()
if(TARGET gau2grid::gg)
    set(_gd_target_gau2grid "gau2grid::gg")
    set(_gd_uses_fc FALSE)
    return()
endif()

# gau2grid's own CMakeLists only requests `COMPONENTS Interpreter` (no
# NumPy component) and never checks numpy is importable before wiring its
# code generator up as a build-time add_custom_command. That means a plain
# find_package(Python) can silently resolve to an interpreter without numpy
# (e.g. the first one on PATH), and the failure only surfaces later, deep in
# a custom command, as a raw Python traceback. Resolve and validate the
# interpreter here instead, mirroring skbuild_python.cmake's FATAL_ERROR
# pattern, so a missing numpy is a clear configure-time error.
find_package(Python 3.6 REQUIRED COMPONENTS Interpreter)
execute_process(
    COMMAND "${Python_EXECUTABLE}" -c "import numpy"
    RESULT_VARIABLE _gd_numpy_rc
    OUTPUT_QUIET
    ERROR_QUIET
)
if(NOT _gd_numpy_rc EQUAL 0)
    message(FATAL_ERROR
        "gau2grid's code generator requires numpy, but it is not "
        "importable in the detected Python interpreter "
        "(${Python_EXECUTABLE}). Install it there, e.g.:\n"
        "    ${Python_EXECUTABLE} -m pip install numpy\n"
        "or point CMake at a different interpreter with "
        "-DPython_EXECUTABLE=/path/to/python."
    )
endif()
unset(_gd_numpy_rc)

# Pin gau2grid's own find_package(Python) to the exact interpreter just
# validated above, so it can't silently re-resolve to a different one.
set(Python_EXECUTABLE "${Python_EXECUTABLE}" CACHE FILEPATH "" FORCE)

FetchContent_Declare(
    gau2grid
    GIT_REPOSITORY https://github.com/psi4/gau2grid
    GIT_TAG        master
)

# Drive MakeAvailable here (instead of letting get_dependencies batch it) so we
# can build with tests off without leaving the parent project's BUILD_TESTING
# clobbered. Opt out of the batched call via _gd_uses_fc below.
set(_gd_bt_backup "${BUILD_TESTING}")
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(gau2grid)
set(BUILD_TESTING "${_gd_bt_backup}" CACHE BOOL "" FORCE)
unset(_gd_bt_backup)

# gau2grid exports the plain target "gg".
set(_gd_target_gau2grid "gg")
set(_gd_uses_fc FALSE)
