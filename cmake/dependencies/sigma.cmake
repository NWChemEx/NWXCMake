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

# sigma (and the CMaize/CMakePP-Lang machinery it pulls in) is still on an
# older cmake_minimum_required(), so its dev warnings for policies introduced
# since then would otherwise leak into every project that fetches sigma
# through NWXCMake. Rather than patch sigma/CMaize's own CMakeLists.txt (not
# ours to maintain), set the CMAKE_POLICY_DEFAULT_CMP<NNNN> variables here:
# CMake reads these as the default for any policy a subdirectory leaves
# unset, and -- because this is a plain set() in an include()'d file rather
# than a function(), not a CACHE variable -- the value lives in
# get_dependencies()'s call scope and is inherited by every add_subdirectory()
# nested underneath it (sigma's own, CMaize's, cmakepp_lang's, ...).
#
# CMP0167 (FindBoost module removed): NEW is the forward-looking choice --
# Boost >= 1.70 ships its own BoostConfig.cmake, which is what actually
# resolves find_package(Boost) here regardless of this policy's setting.
set(CMAKE_POLICY_DEFAULT_CMP0167 NEW)
# CMP0152 (file(REAL_PATH) resolves symlinks before collapsing ../): OLD
# matches CMake's pre-existing behavior, which is what this vendored tree has
# always been exercised against -- switching to NEW changes the resolved
# install paths CMaize computes, unverified territory we don't need to enter
# just to silence a warning.
set(CMAKE_POLICY_DEFAULT_CMP0152 OLD)

# sigma is still on its own CMaize-based build (not yet migrated to the
# NWXCMake pipify pattern the rest of the ecosystem uses), so this pulls it
# in as a subdirectory the same way wtf.cmake does for its already-migrated
# counterpart -- sigma's own CMakeLists.txt drives its own dependency
# resolution (Eigen, Boost) internally.
#
# sigma/cmake/get_cmaize.cmake fetches CMaize from within a function()
# (get_cmaize()), so the CMAKE_MODULE_PATH entry CMaize's own CMakeLists.txt
# exports via `set(... PARENT_SCOPE)` lands in that function's scope and is
# discarded when it returns -- sigma's subsequent `include(cmaize/cmaize)`
# then fails with "include could not find requested file" when sigma is
# fetched as a subdirectory of another project's get_dependencies() (this
# doesn't surface in a standalone sigma build, where nothing wraps it in an
# extra function scope). Pre-fetching CMaize here, directly in
# get_dependencies()'s function scope (not nested inside another function),
# lets its PARENT_SCOPE export land exactly where sigma's own add_subdirectory
# will inherit it from. sigma's own get_cmaize() still runs afterward, but
# FetchContent_MakeAvailable(cmaize) is idempotent, so it's a no-op there.
FetchContent_Declare(
    cmaize
    GIT_REPOSITORY https://github.com/CMakePP/CMaize
    GIT_TAG        master
)
set(_sigma_bt_backup "${BUILD_TESTING}")
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(cmaize)
set(BUILD_TESTING "${_sigma_bt_backup}" CACHE BOOL "" FORCE)
unset(_sigma_bt_backup)

FetchContent_Declare(
    sigma
    GIT_REPOSITORY https://github.com/QCUncertainty/sigma
    GIT_TAG        taylor2
)

set(ENABLE_EIGEN_SUPPORT ON CACHE BOOL "Include Eigen compatibility headers?")

# FIXED (2026-08), see the BUILD_TESTING save/restore above the CMaize fetch.
# History, for the next person who touches this file:
#
# With -DBUILD_TESTING=ON, sigma's own
# cmaize_find_or_build_optional_dependency(eigen ...) call (CMakeLists.txt:46)
# used to fail with "Maximum recursion depth of 2000 exceeded" inside
# CMakePP-Lang's cpp_sanitize_string, called from CMaize's
# _cmaize_find_dependency -- reproducible, not flaky, and only when sigma was
# fetched nested inside another project's get_dependencies() (a standalone
# `cmake -S sigma -B build -DBUILD_TESTING=ON` never recursed).
#
# Root cause: CMaize's core bootstrap (cmake/cmaize/globals.cmake)
# unconditionally resets the CMAIZE_TOP_PROJECT global -- and other
# CMakePP-Lang global state feeding its virtual-dispatch machinery -- every
# time it's include()'d, guarded only by a directory-scoped include_guard().
# CMaize's whole nested-project composition model assumes that bootstrap runs
# exactly once per configure. That assumption held when TensorWrapper was
# itself CMaize-based and composed sigma through CMaize's own
# cmaize_find_or_build_optional_dependency() (see TensorWrapper git history,
# e.g. commit b15d062d, pre build-overhaul) -- CMaize controlled both ends of
# that composition. It does NOT hold here: sigma is glued in via a plain
# FetchContent_Declare()/add_subdirectory(), so sigma's nested
# include(cmaize/cmaize) runs in-process, inside a fresh directory scope, and
# CMaize's own bootstrap fetches its CMakeTest self-test-framework dependency
# (another nested add_subdirectory, another directory-scoped re-bootstrap)
# whenever it sees BUILD_TESTING=ON -- which it did, because our own early,
# manual FetchContent_MakeAvailable(cmaize) above (needed for the
# CMAKE_MODULE_PATH PARENT_SCOPE workaround) ran before get_dependencies()'s
# later BUILD_TESTING=OFF masking of the main dependency batch kicked in.
# Traced with `cmake --trace-expand`: CMAIZE_TOP_PROJECT was reset and
# re-claimed three times in a single configure (CMaize's own bootstrap ->
# CMakeTest -> CMakeTest again -> sigma), each reset corresponding to a new
# add_subdirectory boundary. That repeated mid-configure re-initialization of
# state CMaize assumes is one-time-only is what corrupted the deeper
# virtual-dispatch call chain and produced the runaway recursion.
#
# Fix: scope BUILD_TESTING OFF around our own early CMaize pre-fetch (see
# above), the same save/restore pattern get_dependencies() already uses for
# the main dependency batch. That stops CMaize from ever fetching CMakeTest,
# eliminating two of the three observed CMAIZE_TOP_PROJECT resets and leaving
# only sigma's own single, legitimate cmaize_project(sigma) bootstrap --
# closely matching a clean, standalone sigma build. Verified: TensorWrapper
# configures and builds cleanly with -DBUILD_TESTING=ON -DENABLE_SIGMA=ON,
# no recursion.
#
# Angles that were tried and ruled out before finding the above:
#   - Raising CMaize's CMAKE_MAXIMUM_RECURSION_DEPTH (cmake/cmaize/cmaize_impl.cmake:28,
#     defaults to 2000 `if(NOT CMAKE_MAXIMUM_RECURSION_DEPTH)`): moves the
#     ceiling but not the failure at 8000; at 200000 the configure process
#     gets OOM-killed instead of erroring cleanly. Don't revisit -- the
#     ceiling was never the problem, the state corruption was.
#   - get_dependencies()'s existing BUILD_TESTING=OFF masking around the main
#     dependency batch (FetchContent_MakeAvailable(${_gd_fc_names})): doesn't
#     cover this file's own earlier, manual CMaize pre-fetch, which is
#     exactly why that pre-fetch needed its own scoping (see the fix above).
#
# ENABLE_EIGEN_SUPPORT=OFF is not a substitute fix -- it avoids the recursion
# by skipping sigma's Eigen dependency call entirely, but silently drops
# sigma's Eigen::NumTraits specializations, which TensorWrapper's Eigen
# tensor backend needs for correctness.

if(SKBUILD)
    LIST(APPEND _gd_targets nwx::sigma)
else()
    LIST(APPEND _gd_targets sigma)
endif()
