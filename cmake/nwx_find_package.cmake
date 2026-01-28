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

include(cmaize/cmaize)

#[[[
# Registers the given existing CMake target with CMaize.
#
# This adds the given existing CMake target to both the top-level CMaize
# project and the CMaize package manager instance for CMake packages.
#
# :param cmaize_name: Name of the target as identified in CMaize.
# :type cmaize_name: desc
# :param target: Name of the underlying CMake target to be wrapped.
# :type target: target
# :param **kwargs: Additional keyword arguments will be passed to CMaize's
#     ``_fob_parse_arguments()`` (`link <https://github.com/CMakePP/CMaize/blob/master/cmake/cmaize/user_api/dependencies/impl_/parse_arguments.cmake>`__)
#     and ``CMakePackageManager(register_dependency`` (`link <https://github.com/CMakePP/CMaize/blob/master/cmake/cmaize/package_managers/cmake/cmake_package_manager.cmake#L120>`__).
#]]
function(nwx_wrap_target _nwt_cmaize_name _nwt_target)
    # Prepare the new target to be added to the top-level project
    cpp_get_global(_nwt_top_project CMAIZE_TOP_PROJECT)
    CMaizeTarget(CTOR _nwt_tgt_obj "${_nwt_target}")

    # install_path needs to be set to something or CMaize ignores the target
    # during config file generation. This will be treated as a pre-installed
    # target found by find_package(), but without a real install path
    CMaizeTarget(SET "${_nwt_tgt_obj}" install_path "tmp")
    CMaizeProject(add_target
        "${_nwt_top_project}" "${_nwt_cmaize_name}" "${_nwt_tgt_obj}"
    )

    # Create package specification object
    _fob_parse_arguments(
        _nwt_pkg_spec _nwt_pkg_name "${_nwt_cmaize_name}" ${ARGN}
    )

    # Register the dependency with the current CMake package manager
    CMaizeProject(get_package_manager "${_nwt_top_project}" _nwt_pm "cmake")

    # TODO: This probably can be eliminated if CMaizeProject(get_package_manager
    #       uses get_package_manager_instance under the hood
    # Create new package manager if it doesn't exist
    if("${_nwt_pm}" STREQUAL "")
        get_package_manager_instance(_nwt_pm "cmake")
        CMaizeProject(add_package_manager "${_nwt_top_project}" "${_nwt_pm}")
    endif()

    # TODO: Call this with NAME arg to handle components better
    CMakePackageManager(register_dependency
        "${_nwt_pm}" __dep "${_nwt_pkg_spec}"
        # Set both find and built target to avoid having COMPONENTS "" added
        # to every find_dependency() call generated
        FIND_TARGET "${_nwt_target}"
        ${ARGN}
    )
endfunction()

#[[[
# Wraps the CMake ``find_package()`` call, also adding the target to CMaize.
#
# :param package_name: Name of the package to be found.
# :type package_name: desc
# :param TARGETS: Keyword argument of "CMaize name" "CMake target" pairs,
#     defaults to "package_name" "package_name".
# :type TARGETS: List of desc or target
# :param **kwargs: Additional keyword arguments will be passed to CMaize's
#     ``find_packages()`` (`link <https://cmake.org/cmake/help/latest/command/find_package.html>`__).
#]]
function(nwx_find_package _nfp_package_name)
    set(_nfp_options "")
    set(_nfp_one_value "")
    # TARGETS option comes in pairs of "CMaize name" "CMake target"
    set(_nfp_multi_value "TARGETS")
    cmake_parse_arguments(_nfp "${_nfp_options}" "${_nfp_one_value}" "${_nfp_multi_value}" ${ARGN})

    # If TARGETS is not given, default the pairing to "${_nfp_package_name}" "${_nfp_package_name}"
    list(LENGTH _nfp_TARGETS _nfp_TARGETS_len)
    if(_nfp_TARGETS_len LESS_EQUAL 0)
        message(WARNING "No targets provided. Using default dependency target \"${_nfp_package_name}\" for \"${_nfp_package_name}\"")
        set(_nfp_TARGETS "${_nfp_package_name}" "${_nfp_package_name}")
    endif()

    # Validate that TARGETS is in the correct pair-wise form, simultaneously
    list(LENGTH _nfp_TARGETS _nfp_TARGETS_len)
    math(EXPR _nfp_TARGETS_is_odd "${_nfp_TARGETS_len} % 2")
    if(_nfp_TARGETS_is_odd EQUAL 0)
        cpp_raise(InvalidArgument "TARGETS list length is odd, but must be even pairs.")
    endif()

    # Turn TARGETS into a map of CMaize name -> CMake target
    cpp_map(CTOR _nfp_target_map)
    foreach(_nfp_i RANGE 0 "${_nfp_TARGETS_len}" 2)
        # Grab the key-value pair of items
        list(POP_FRONT _nfp_TARGETS _nfp_cmaize_name)
        list(POP_FRONT _nfp_TARGETS _nfp_cmake_target)

        cpp_map(APPEND "${_nfp_target_map}"
            "${_nfp_cmaize_name}" "${_nfp_cmake_target}"
        )
    endforeach()
    # Grab the keys for later usage
    cpp_map(KEYS "${_nfp_target_map}" _nfp_cmaize_names)

    # Call find_package() to do the heavy lifting and find everything
    message(STATUS "Searching for ${_nfp_package_name}")
    find_package("${_nfp_package_name}" ${_nfp_UNPARSED_ARGUMENTS})

    message(DEBUG "${_nfp_package_name}_FOUND: ${${_nfp_package_name}_FOUND}")

    # Make sure each expected target exists after the find_package() call
    foreach(_nfp_cmaize_name ${_nfp_cmaize_names})
        cpp_map(GET "${_nfp_target_map}"
            _nfp_cmake_target "${_nfp_cmaize_name}"
        )

        if(NOT TARGET "${_nfp_cmake_target}")
            cpp_raise(TargetNotFound
                "Could not find target (${_nfp_cmaize_name}, ${_nfp_cmake_target}) after find_package()"
            )
        endif()
    endforeach()

    # Default to matching NAME and BUILD_TARGET so the find_dependency() call
    # doesn't have components
    set(_nfp_build_target "${_nfp_package_name}")

    # Handle components
    set(_nfp_multi_value "COMPONENTS")
    cmake_parse_arguments(
        _nfp
        "${_nfp_options}" "${_nfp_one_value}" "${_nfp_multi_value}"
        ${_nfp_UNPARSED_ARGUMENTS}
    )

    # If components were given, we want find_dependency() called with them
    if(NOT "${_nfp_COMPONENTS}" STREQUAL "")
        set(_nfp_build_target "${_nfp_COMPONENTS}")
    endif()

    # Add all targets to CMaize
    foreach(_nfp_cmaize_name ${_nfp_cmaize_names})
        cpp_map(GET "${_nfp_target_map}"
            _nfp_cmake_target "${_nfp_cmaize_name}"
        )

        nwx_wrap_target("${_nfp_cmaize_name}" "${_nfp_cmake_target}"
            NAME "${_nfp_package_name}"
            BUILD_TARGET "${_nfp_build_target}"
        )
    endforeach()

endfunction()
