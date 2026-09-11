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

#[[[
# Resolves a local-source-directory override for a dependency.
#
# This function wraps the logic of getting ``FETCHCONTENT_SOURCE_DIR_<NAME>``
# and checking that it is a directory (if it was set).  This function can be
# extended to support other override mechanisms in the future.
#
# :param nlso_name: Dependency name as spelled in ``dependencies/<name>.cmake``.
# :type nlso_name: desc
# :param nlso_out: Name of the variable to set in the caller's scope.  Set to
#                  the override directory, or to the empty string if no
#                  override was given.
# :type nlso_out: desc
#]]
function(nwx_local_source_override nlso_name nlso_out)
    string(TOUPPER "${nlso_name}" _nlso_upper)
    set(_nlso_dir "${FETCHCONTENT_SOURCE_DIR_${_nlso_upper}}")
    if(_nlso_dir AND NOT IS_DIRECTORY "${_nlso_dir}")
        message(FATAL_ERROR
            "FETCHCONTENT_SOURCE_DIR_${_nlso_upper} was set to '${_nlso_dir}', "
            "which is not a directory."
        )
    endif()
    set(${nlso_out} "${_nlso_dir}" PARENT_SCOPE)
endfunction()

#[[[
# Shared body for every NWChemEx-owned dependency in ``dependencies/*.cmake``
# (pluginplay, chemist, tensorwrapper, utilities, parallelzone, simde,
# integrals, nux, chemcache, scf, nwchemex).
#
# Resolution order -- the first branch that matches wins, and the order
# matters:
#
# 1. **The top-level repo.**  If ``<name>`` is ``NWX_TOP_PROJECT_NAME`` (set
#    by :cmake:module:`set_default_nwx_options`), resolve to the target this
#    build already defined -- i.e. the working tree.  ``NWX_TOP_PROJECT_NAME``
#.   should not be set by hand as it is used to implement the
#    "self-override rule": a repo doing integration testing pulls in the whole
#    ecosystem (including an old version of itself), and since we want to test
#.   the local version, this repo's copy has to lose.  This branch must come
#.   first to ensure we always use the local copy of the top-level repo.
# 2. **Already resolved.**  This branch is triggered when an earlier
#    ``get_dependencies()`` call in this same configuration already produced a
#    target for ``<name>``.
# 3. **A local source directory**, via ``FETCHCONTENT_SOURCE_DIR_<NAME>`` --
#    see :cmake:command:`nwx_local_source_override`.  For developing against
#    an unpublished sibling checkout.
# 4. **An installed wheel** in the active venv's site-packages
#    (``NWX_VENV_SITE_PACKAGES``).  Every ecosystem repo publishes a wheel
#    carrying its headers, its shared libraries, and a ``<name>Config.cmake``,
#    so this reuses a released build instead of re-cloning and recompiling.
#    Scoped to exactly that directory (``NO_DEFAULT_PATH``) so it can never
#    accidentally match an unrelated system-wide install.  Skipped entirely
#    when ``NWX_ECOSYSTEM_FROM_SOURCE`` is on.
# 5. **git master**, via FetchContent.
#
# Must be a macro, not a function: this is ``include()``'d from inside
# ``get_dependencies()``'s foreach loop (via ``dependencies/<name>.cmake``), and
# the ``return()``s below need to resume that loop -- ``return()`` from a
# function would only exit the function itself, not resume the caller's
# foreach.
#
# :param ned_name: Dependency name, matching ``dependencies/<name>.cmake``.
# :type ned_name: desc
# :param ned_git_repository: URL to clone from in branch 5.
# :type ned_git_repository: desc
#]]
macro(nwx_ecosystem_dependency ned_name ned_git_repository)
    # (1) The top-level project always resolves to this working tree.
    if("${ned_name}" STREQUAL "${NWX_TOP_PROJECT_NAME}")
        if(NOT TARGET ${ned_name})
            message(FATAL_ERROR
                "'${ned_name}' is the top-level project, so it must resolve to "
                "this working tree, but no target named '${ned_name}' exists "
                "yet. This almost always means get_dependencies() was called "
                "too early: the call that (transitively) pulls in "
                "'${ned_name}' -- e.g. get_dependencies(nwchemex) for "
                "integration testing -- has to come *after* the nwx_library() "
                "call that defines this project's own target. See "
                "https://nwchemex.github.io/author/testing/integration/"
            )
        endif()
        message(STATUS
            "  ${ned_name}: this working tree (top-level project)"
        )
        set(_gd_target_${ned_name} "${ned_name}")
        list(APPEND _gd_targets ${ned_name})
        set(_gd_uses_fc FALSE)
        return()
    endif()

    # (2) Already resolved earlier in this same configure.
    if(TARGET nwx::${ned_name})
        message(STATUS "  ${ned_name}: already resolved (nwx::${ned_name})")
        set(_gd_target_${ned_name} "nwx::${ned_name}")
        list(APPEND _gd_targets nwx::${ned_name})
        set(_gd_uses_fc FALSE)
        return()
    elseif(TARGET ${ned_name})
        message(STATUS "  ${ned_name}: already resolved (${ned_name})")
        set(_gd_target_${ned_name} "${ned_name}")
        list(APPEND _gd_targets ${ned_name})
        set(_gd_uses_fc FALSE)
        return()
    endif()

    # (3) A local checkout the developer pointed us at.
    nwx_local_source_override(${ned_name} _ned_local_dir)
    if(_ned_local_dir)
        message(STATUS "  ${ned_name}: local source dir ${_ned_local_dir}")
        FetchContent_Declare(${ned_name} SOURCE_DIR "${_ned_local_dir}")
        list(APPEND _gd_targets ${ned_name})
        return()
    endif()

    # (4) An installed wheel.
    # ``unset(<name>_DIR CACHE)`` ensures this runs every time it's called. If
    # we had already found the package in a previous call to
    # ``nwx_ecosystem_dependency()``, then branch 2 would have triggered, i.e.,
    # if ``<name>_DIR`` is set it is stale.
    #
    # The success check requires ``${ned_name}_FOUND`` in addition to
    # ``TARGET nwx::${ned_name}``: the generated ``<name>Targets.cmake``
    # unconditionally defines ``nwx::<name>`` as an IMPORTED target even when
    # one of ITS OWN transitively-linked dependencies isn't resolvable yet
    # (e.g. it links against ``nwx::scf``, but ``scf`` is the
    # top-level project, so only a bare ``scf`` target exists, not
    # ``nwx::scf``) -- CMake's own install(EXPORT) boilerplate detects that
    # and sets ``<name>_FOUND FALSE``, but leaves the half-broken IMPORTED
    # target in place regardless. Checking only ``TARGET nwx::${ned_name}``
    # would treat that as a successful resolution and defer a confusing
    # link-time "target nwx::scf not defined" error instead of falling
    # through to branch 5.
    if(NWX_VENV_SITE_PACKAGES AND NOT NWX_ECOSYSTEM_FROM_SOURCE)
        unset(${ned_name}_DIR CACHE)
        find_package(${ned_name} CONFIG QUIET
            PATHS "${NWX_VENV_SITE_PACKAGES}" NO_DEFAULT_PATH
        )
        if(TARGET nwx::${ned_name} AND ${ned_name}_FOUND)
            message(STATUS
                "  ${ned_name}: installed wheel (${${ned_name}_DIR})"
            )
            set(_gd_target_${ned_name} "nwx::${ned_name}")
            list(APPEND _gd_targets nwx::${ned_name})
            set(_gd_uses_fc FALSE)
            return()
        endif()
    endif()

    # (5) git master.
    message(STATUS "  ${ned_name}: git master (${ned_git_repository})")
    FetchContent_Declare(
        ${ned_name}
        GIT_REPOSITORY ${ned_git_repository}
        GIT_TAG        master
    )

    list(APPEND _gd_targets ${ned_name})
endmacro()
