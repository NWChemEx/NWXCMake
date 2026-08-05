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

#[[[
# Wires up the shared NWChemEx pre-commit hooks for local development, with
# no developer action required beyond an editable pip install.
#
# Fetches the shared ``.pre-commit-config.yaml`` (from
# github.com/NWChemEx/pre-commit-config) into the repo root, and writes a
# ``.git/hooks/pre-commit`` script that looks up ``pre-commit`` on ``PATH``
# *at commit time*.
#
# Deliberately does NOT shell out to ``pre-commit install``: that command
# bakes the absolute path of whichever Python ran it into the hook's
# shebang/launcher. If this macro runs during a build-isolated
# ``pip install`` (pip's default), that Python is a throwaway env pip
# deletes right after the build, silently breaking the hook. Resolving
# ``pre-commit`` via ``PATH`` at commit time instead means it works
# regardless of whether the install that wrote the hook was isolated, and
# regardless of which Python wrote it — only the developer's active shell
# at commit time matters, and pre-commit is installed there via each
# package's ``dev`` extra.
#
# No-op if ``CMAKE_SOURCE_DIR`` is not a git checkout (e.g. building from an
# extracted sdist, as a PyPI-deploy dry run would), so it is safe to call
# unconditionally from editable/developer builds.
#
# .. code-block:: cmake
#
#    if(DEVELOPER_SETUP)
#        include(nwx_setup_pre_commit)
#        nwx_setup_pre_commit()
#    endif()
#]]
macro(nwx_setup_pre_commit)
    if(EXISTS "${CMAKE_SOURCE_DIR}/.git")
        file(DOWNLOAD
            "https://raw.githubusercontent.com/NWChemEx/pre-commit-config/master/.pre-commit-config.yaml"
            "${CMAKE_SOURCE_DIR}/.pre-commit-config.yaml"
            STATUS _nsp_download_status
        )
        list(GET _nsp_download_status 0 _nsp_download_rc)

        if(NOT _nsp_download_rc EQUAL 0)
            message(WARNING
                "nwx_setup_pre_commit: failed to fetch the shared "
                ".pre-commit-config.yaml; leaving any existing pre-commit "
                "hook as-is."
            )
        else()
            set(_nsp_marker "# nwx-managed-pre-commit-hook")
            set(_nsp_hook "${CMAKE_SOURCE_DIR}/.git/hooks/pre-commit")

            set(_nsp_write_hook TRUE)
            if(EXISTS "${_nsp_hook}")
                file(READ "${_nsp_hook}" _nsp_existing)
                if(NOT _nsp_existing MATCHES "${_nsp_marker}")
                    set(_nsp_write_hook FALSE)
                    message(STATUS
                        "nwx_setup_pre_commit: an existing "
                        ".git/hooks/pre-commit was not created by NWXCMake; "
                        "leaving it untouched."
                    )
                endif()
            endif()

            if(_nsp_write_hook)
                file(WRITE "${_nsp_hook}"
"#!/usr/bin/env bash
${_nsp_marker}
# Regenerated automatically by CMake (nwx_setup_pre_commit) on every
# editable install/reconfigure -- do not edit by hand.
if command -v pre-commit >/dev/null 2>&1; then
    exec pre-commit run --hook-stage pre-commit
else
    echo 'pre-commit not found on PATH -- skipping checks.' >&2
    echo 'Activate the virtualenv you ran \"pip install -e .[dev]\" in to enable them.' >&2
    exit 0
fi
"
                )
                file(CHMOD "${_nsp_hook}" PERMISSIONS
                    OWNER_READ OWNER_WRITE OWNER_EXECUTE
                    GROUP_READ GROUP_EXECUTE
                    WORLD_READ WORLD_EXECUTE
                )
                message(STATUS
                    "nwx_setup_pre_commit: installed .git/hooks/pre-commit"
                )
            endif()
        endif()
    endif()
endmacro()
