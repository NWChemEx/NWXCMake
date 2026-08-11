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

# nwx_ecosystem_dependency(name git_repository)
#
# Shared body for every NWChemEx-owned dependency in dependencies/*.cmake
# (pluginplay, chemist, tensorwrapper, utilities, parallelzone, simde,
# integrals, nux, chemcache, nwchemex). Each of those repos also publishes a
# real wheel to PyPI, so:
#
#   1. Reuse a previously-installed wheel from the active venv's
#      site-packages (NWX_VENV_SITE_PACKAGES) if one exists, instead of
#      re-cloning and rebuilding <name> from source every time. Scoped to
#      exactly that directory (NO_DEFAULT_PATH) so this can never
#      accidentally match an unrelated system-wide install.
#   2. unset(<name>_DIR CACHE) first: <name>_DIR is itself a cache variable,
#      so find_package() would otherwise short-circuit on (and trust) a
#      stale/unrelated value left behind by an earlier, unscoped
#      find_package() call for the same name -- either from a different
#      dependency fetched earlier in this same configure, or from a
#      previous configure of this same build directory.
#   3. Fall back to FetchContent (git master) only if no installed wheel was
#      found.
#
# Must be a macro, not a function: this is include()'d from inside
# get_dependencies()'s foreach loop (via dependencies/<name>.cmake), and the
# return() below needs to resume that loop -- return() from a function would
# only exit the function itself, not resume the caller's foreach.
macro(nwx_ecosystem_dependency ned_name ned_git_repository)
    if(NWX_VENV_SITE_PACKAGES)
        unset(${ned_name}_DIR CACHE)
        find_package(${ned_name} CONFIG QUIET
            PATHS "${NWX_VENV_SITE_PACKAGES}" NO_DEFAULT_PATH
        )
    endif()
    if(TARGET nwx::${ned_name})
        set(_gd_target_${ned_name} "nwx::${ned_name}")
        list(APPEND _gd_targets nwx::${ned_name})
        set(_gd_uses_fc FALSE)
        return()
    endif()

    FetchContent_Declare(
        ${ned_name}
        GIT_REPOSITORY ${ned_git_repository}
        GIT_TAG        master
    )

    list(APPEND _gd_targets ${ned_name})
endmacro()
