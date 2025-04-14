# Copyright 2023 NWChemEx-Project
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
# Uses Git to determine the version of a git repo.
#
# :param _gvfg_result: The variable name to assign the result to.
# :type _gvfg_result: desc*
# :param _gvfg_git_root: The directory containing the .git/ directory.
# :type _gvfg_git_root: path
#
# .. code-block: cmake
#
#    get_version_from_git(MY_PROJECT_VERSION ${CMAKE_CURRENT_SOURCE_DIR})
#    message("My project's version is: ${MY_PROJECT_VERSION}")
#]]
function(get_version_from_git _gvfg_result _gvfg_git_root)
    # Just default the version to "0.1.0"
    set(_gvfg_default_version "0.1.0")
    # Alternatively, if there is a project version already set, we could grab
    # that to use as the default. However, this would require the
    # get_version_from_git() call to appear after the `project()` call, using
    # another `project()` call with the new version or manually setting the
    # correct <PROJECT_NAME>_VERSION* variables.
    # set(_gvfg_default_version "${PROJECT_VERSION}")
    # TODO: Do it this way or just default to "0.1.0"?
    message(DEBUG "Default Project Version: ${_gvfg_default_version}")


    # Make sure that Git is available
    # ZDC: Do we want Git to be required? I implemented an alternative below
    #      so that Git is not a hard requirement anymore.
    find_package(Git QUIET REQUIRED)
    message(DEBUG "Git_FOUND: ${Git_FOUND}")

    # If Git was not found, the default project version is returned
    if(NOT Git_FOUND)
        message(WARNING
            "Git installation was not found. Version cannot be acquired "
            "through this method. Using default version: ${_gvfg_default_version}"
        )
        set("${_gvfg_result}" "${_gvfg_default_version}" PARENT_SCOPE)
        return()
    endif()

    # Invoke git command to get the tag
    # ZDC: What happens when I pull the main branch and do this? Does it give
    #      a commit hash, the latest tag (which is not guaranteed to be the
    # correct version), or something else?
    message(DEBUG "_gvfg_git_root: ${_gvfg_git_root}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" describe --tags --abbrev=0
        WORKING_DIRECTORY "${_gvfg_git_root}"
        OUTPUT_VARIABLE _gvfg_version
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(DEBUG "Git version tag found: ${_gvfg_version}")

    # Remove the "v" prefix, since CMake chokes on it
    # Issue: ${_gvfg_version} needed to be in double quotes, which is generally
    #        what should be done in all cases unless you have a *very* good
    #        reason to do otherwise (some instances of dereferencing lists is
    #        the only time I can think of). It is possible for _gvfg_version to be
    #        empty, which causes string(REGEX REPLACE to throw an error about
    #        not getting enough arguments. Setting  _gvfg_version to an empty
    #        string before running `execute_process()` surprisingly does not
    #        mitigate the issue.
    # TODO: Consider using `if("${_gvfg_version}" MATCHES "<regex>")` for more
    #       fine-tuned decisions about what processing may be applied to the
    #       version string from Git.
    string(REGEX REPLACE "^v" "" _gvfg_version "${_gvfg_version}")

    # If git failed to find a version or it is an invalid format, use the
    # default version
    if(NOT "${_gvfg_version}" MATCHES "^([0-9]+(\.[0-9]+(\.[0-9]+(\.[0-9]+)?)?)?)$")
        message(WARNING
            "Git returned an invalid version tag of \"${_gvfg_version}\".\n"
            "Defaulting to version: ${_gvfg_default_version}\n"
        )
        set(_gvfg_version "${_gvfg_default_version}")
    endif()

    set("${_gvfg_result}" "${_gvfg_version}" PARENT_SCOPE)
endfunction()
