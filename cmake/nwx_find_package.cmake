include_guard()

include(cmaize/cmaize)

function(nwx_wrap_target _cmaize_name _target)
    # Prepare the new target to be added to the top-level project
    cpp_get_global(_top_project CMAIZE_TOP_PROJECT)
    CMaizeTarget(CTOR _tgt_obj "${_target}")
    # install_path needs to be set to something or CMaize ignores the target
    # during config file generation. This will be treated as a pre-installed
    # target found by find_package(), but without a real install path
    CMaizeTarget(SET "${_tgt_obj}" install_path "tmp")
    CMaizeProject(add_target "${_top_project}" "${_cmaize_name}" "${_tgt_obj}")

    # Create package specification objct
    _fob_parse_arguments(_pkg_spec _pkg_name "${_cmaize_name}" ${ARGN})

    # Register the dependency with the current CMake package manager
    CMaizeProject(get_package_manager "${_top_project}" _pm "cmake")

    # TODO: This probably can be eliminated if CMaizeProject(get_package_manager
    #       uses get_package_manager_instance under the hood
    # Create new package manager if it doesn't exist
    if("${_pm}" STREQUAL "")
        get_package_manager_instance(_pm "cmake")
        CMaizeProject(add_package_manager "${_top_project}" "${_pm}")
    endif()

    # TODO: Call this with NAME arg to handle components better
    CMakePackageManager(register_dependency
        "${_pm}" __dep "${_pkg_spec}"
        # Set both find and built target to avoid having COMPONENTS "" added
        # to every find_dependency() call generated
        FIND_TARGET "${_target}"
        ${ARGN}
    )
endfunction()

function(nwx_find_package _package_name)
    set(_nfp_options "")
    set(_nfp_one_value "")
    # TARGETS option comes in pairs of "CMaize name" "CMake target"
    set(_nfp_multi_value "TARGETS")
    cmake_parse_arguments(_nfp "${_nfp_options}" "${_nfp_one_value}" "${_nfp_multi_value}" ${ARGN})

    # If TARGETS is not given, default the pairing to "${_package_name}" "${_package_name}"
    list(LENGTH _nfp_TARGETS _nfp_TARGETS_len)
    if(_nfp_TARGETS_len LESS_EQUAL 0)
        message(WARNING "No targets provided. Using default dependency target \"${_package_name}\" for \"${_package_name}\"")
        set(_nfp_TARGETS "${_package_name}" "${_package_name}")
        list(LENGTH _nfp_TARGETS _nfp_TARGETS_len)
    endif()

    # Validate that TARGETS is in the correct pair-wise form, simultaneously
    # TODO: Assert that length is even

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
    message(STATUS "Searching for ${_package_name}")
    find_package("${_package_name}" ${_nfp_UNPARSED_ARGUMENTS})

    message(DEBUG "${_package_name}_FOUND: ${${_package_name}_FOUND}")

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
    set(_nfp_build_target "${_package_name}")

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

        # nwx_wrap_target("${_nfp_cmaize_name}" "${_nfp_cmake_target}")

        nwx_wrap_target("${_nfp_cmaize_name}" "${_nfp_cmake_target}"
            NAME "${_package_name}"
            BUILD_TARGET "${_nfp_build_target}"
        )
    endforeach()

    # foreach(_nfp_component ${_nfp_COMPONENTS})
    #     set(_nfp_cmaize_name "${_package_name}_${_nfp_component}")
    #     nwx_wrap_target("${_nfp_cmaize_name}" "${_nfp_component}"
    #         NAME "${_package_name}"
    #         BUILD_TARGET "${_nfp_component}"
    #     )
    # endforeach()

endfunction()
