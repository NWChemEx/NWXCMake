# Copyright 2025 NWChemEx-Project
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
# Writes the ``<name>Config.cmake`` that ships next to ``<name>Targets.cmake``.
#
# A package config file is required to ``find_dependency()`` its own public
# dependencies before including its targets file. Ours did not, which made
# every published wheel's config unusable as soon as anything actually
# resolved from one:
#
# ``install(EXPORT)`` writes the link interface verbatim, so
# ``simdeTargets.cmake`` declares ``nwx::simde`` with
# ``INTERFACE_LINK_LIBRARIES "nwx::chemist;nwx::pluginplay"``. With nothing
# having created those targets, CMake's own generated boilerplate sets
# ``simde_FOUND FALSE`` -- which ``nwx_ecosystem_dependency`` correctly
# detects, falling through to a source build -- but the half-built
# ``nwx::simde`` IMPORTED target is *left behind*, and CMake fails at
# **generate** time on its dangling link interface:
#
#   The link interface of target "nwx::simde" contains: nwx::chemist
#   but the target was not found.
#
# Emitting the ``find_dependency()`` calls fixes it at the source: the
# dependencies exist, the FOUND check passes, and the package resolves from
# its wheel as intended.
#
# :param wcf_file: Path of the config file to write.
# :type wcf_file: desc
# :param wcf_name: Name of the target/package being installed. Passed
#                  explicitly rather than read out of the caller's scope.
# :type wcf_name: desc
#]]
function(write_config_file wcf_file wcf_name)
    # Public dependencies, recovered from the link interface that
    # install(EXPORT) is about to write out verbatim. EVERY namespaced target
    # in it has to be found here, not just the ecosystem ones: parallelzone,
    # for instance, publicly links spdlog::spdlog and cereal::cereal, and a
    # config that found only its nwx:: deps still reports
    # parallelzone_FOUND FALSE.
    #
    # Namespace-to-package mapping follows the usual CMake convention that a
    # package exports into a namespace named after itself (spdlog::spdlog ->
    # spdlog, Boost::boost -> Boost). The ecosystem's own nwx:: namespace is
    # the exception -- it is shared by every package -- so there the target
    # name is what identifies the package.
    #
    # Un-namespaced entries are skipped: they are either plain system
    # libraries (-lm, /usr/lib/libfoo.a) or targets built in this same
    # project, neither of which is find_package()-able. Generator expressions
    # are skipped because they cannot be evaluated at configure time.
    set(_wcf_deps)
    get_target_property(_wcf_links ${wcf_name} INTERFACE_LINK_LIBRARIES)
    if(_wcf_links)
        foreach(_wcf_link IN LISTS _wcf_links)
            if(_wcf_link MATCHES "\\$<")
                continue()
            elseif(_wcf_link MATCHES "^nwx::(.+)$")
                list(APPEND _wcf_deps "${CMAKE_MATCH_1}")
            elseif(_wcf_link MATCHES "^([^:]+)::")
                list(APPEND _wcf_deps "${CMAKE_MATCH_1}")
            endif()
        endforeach()
    endif()
    if(_wcf_deps)
        list(REMOVE_DUPLICATES _wcf_deps)
    endif()

    # Every emitted variable is suffixed with the package name. A config file
    # is include()d into its *caller's* scope, so a bare _IL_CONFIG_DIR is a
    # single shared slot: as soon as find_dependency() nests one config inside
    # another, the inner one overwrites the outer's value and the outer then
    # include()s its targets file out of the wrong directory. Harmless while
    # no config ever included another; a latent trap the moment one does.
    set(_wcf_dir_var "_IL_${wcf_name}_CONFIG_DIR")

    file(WRITE "${wcf_file}" "") # Erases it if it already exists
    file(APPEND
        "${wcf_file}"
        "get_filename_component(${_wcf_dir_var} "
        "\"\${CMAKE_CURRENT_LIST_FILE}\" PATH)\n"
    )

    if(_wcf_deps)
        # <prefix>/lib/cmake/<name>/<name>Config.cmake -> <prefix>, the same
        # three-PATH walk install(EXPORT)'s own _IMPORT_PREFIX does. Every
        # package installs under a shared prefix (the venv's platlib for a
        # wheel), so a sibling's config sits at <prefix>/lib/cmake/<dep> --
        # exactly where find_package looks once <prefix> is on
        # CMAKE_PREFIX_PATH.
        #
        # CMAKE_PREFIX_PATH is restored afterwards so a consumer's own
        # find_package() calls aren't silently widened by having used this
        # package.
        file(APPEND
            "${wcf_file}"
            "\n"
            "include(CMakeFindDependencyMacro)\n"
            "\n"
            "get_filename_component(_IL_${wcf_name}_PREFIX "
            "\"\${${_wcf_dir_var}}/../../..\" ABSOLUTE)\n"
            "set(_IL_${wcf_name}_SAVED_PREFIX_PATH \"\${CMAKE_PREFIX_PATH}\")\n"
            "list(APPEND CMAKE_PREFIX_PATH \"\${_IL_${wcf_name}_PREFIX}\")\n"
        )
        foreach(_wcf_dep IN LISTS _wcf_deps)
            file(APPEND "${wcf_file}" "find_dependency(${_wcf_dep})\n")
        endforeach()
        file(APPEND
            "${wcf_file}"
            "set(CMAKE_PREFIX_PATH \"\${_IL_${wcf_name}_SAVED_PREFIX_PATH}\")\n"
            "unset(_IL_${wcf_name}_SAVED_PREFIX_PATH)\n"
            "unset(_IL_${wcf_name}_PREFIX)\n"
            "\n"
        )
    endif()

    file(APPEND
        "${wcf_file}"
        "include(\"\${${_wcf_dir_var}}/${wcf_name}Targets.cmake\")\n"
        "unset(${_wcf_dir_var})\n"
    )
endfunction()

function(install_library il_name il_header_dir)
    #TODO: Get these values programmatically
    set(_il_archive_dir lib)
    set(_il_library_dir lib)
    set(_il_runtime_dir bin)
    set(_il_includes_dir include)

    # -- Install target that is a library --
    get_target_property(_il_type ${il_name} TYPE)
    if(_il_type STREQUAL "INTERFACE_LIBRARY")
        install(TARGETS ${il_name} EXPORT ${il_name}Targets)
    else()
        install(TARGETS ${il_name}
            EXPORT ${il_name}Targets
            ARCHIVE DESTINATION "${_il_archive_dir}"
            LIBRARY DESTINATION "${_il_library_dir}"
            RUNTIME DESTINATION "${_il_runtime_dir}"
            INCLUDES DESTINATION "${_il_includes_dir}"
        )
    endif()

    # -- Install CMake Config Files --
    install(EXPORT ${il_name}Targets
        FILE ${il_name}Targets.cmake
        NAMESPACE nwx::
        DESTINATION "${_il_library_dir}/cmake/${il_name}"
    )

    set(_il_config_file "${CMAKE_CURRENT_BINARY_DIR}/${il_name}Config.cmake")
    write_config_file("${_il_config_file}" "${il_name}")

    install(FILES "${_il_config_file}"
        DESTINATION "${_il_library_dir}/cmake/${il_name}"
    )

    # -- Install Headers --
    # Trailing slash installs the *contents* of il_header_dir into include/,
    # giving <prefix>/include/<pkg>/... (matches the INSTALL_INTERFACE:include
    # usage requirement). Without it CMake appends the last path component,
    # yielding <prefix>/include/include/<pkg>/...
    # An empty il_header_dir means the target has no headers (e.g. a
    # pure-aggregator INTERFACE target); skip header installation entirely.
    if(il_header_dir)
        install(DIRECTORY "${il_header_dir}/"
            DESTINATION "${_il_includes_dir}"
            FILES_MATCHING
                PATTERN "*.hpp"
                PATTERN "*.h"
                PATTERN "*.ipp"
        )
    endif()
endfunction()
