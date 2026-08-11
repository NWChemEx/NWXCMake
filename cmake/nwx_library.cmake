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

# Helper: resolve a list of dep short-names to real CMake targets.
# For each name, checks NWX_DEP_TARGET_<name> (published by get_dependencies);
# falls back to using the name itself (ecosystem deps whose name == target).
function(_nwx_resolve_dep_names out_var)
    set(_resolved)
    foreach(_dep ${ARGN})
        if(DEFINED CACHE{NWX_DEP_TARGET_${_dep}})
            list(APPEND _resolved "${NWX_DEP_TARGET_${_dep}}")
        else()
            list(APPEND _resolved "${_dep}")
        endif()
    endforeach()
    set(${out_var} "${_resolved}" PARENT_SCOPE)
endfunction()

# nwx_library(name inc_dir src_dir
#     [ecosystem_dep ...]          <- PUBLIC ecosystem deps (utilities, parallelzone, …)
#     [PUBLIC  ext_dep ...]        <- additional PUBLIC deps by NWX short name
#     [PRIVATE ext_dep ...]        <- PRIVATE deps by NWX short name
#     [SOURCES file ...]           <- explicit source list, overrides the
#                                     default `${src_dir}/*.cpp` glob (use
#                                     when src_dir contains other, unrelated
#                                     .cpp files that must not be swept in)
#     [TYPE <STATIC|SHARED|...>]   <- forwarded to add_library(); omit to use
#                                     the default (BUILD_SHARED_LIBS-controlled)
#     [NO_INSTALL])                <- skip install_library() for this target
#
# PUBLIC and PRIVATE deps use the same short names as get_dependencies() so
# callers never need to know the underlying CMake target names.
# get_dependencies() publishes NWX_DEP_TARGET_<name> cache vars that this
# function reads to resolve short names → real targets.
function(nwx_library nl_project_name nl_inc_dir nl_src_dir)
    cmake_parse_arguments(nl "NO_INSTALL" "TYPE" "PUBLIC;PRIVATE;SOURCES" ${ARGN})
    # nl_UNPARSED_ARGUMENTS = positional ecosystem deps (stay PUBLIC)
    # nl_PUBLIC              = extra PUBLIC deps by short name
    # nl_PRIVATE             = PRIVATE deps by short name
    # nl_SOURCES             = explicit source list (overrides the glob)
    # nl_TYPE                = library type forwarded to add_library()
    # nl_NO_INSTALL          = skip install_library()

    # Positional ecosystem deps must also be resolved: now that
    # get_dependencies() can satisfy a dep via find_package() against an
    # installed wheel instead of FetchContent, its real target is
    # "nwx::<name>", not the bare short name -- so this can no longer assume
    # short name == target name the way it could when every dep was
    # unconditionally FetchContent'd in-tree.
    _nwx_resolve_dep_names(_nl_eco       ${nl_UNPARSED_ARGUMENTS})
    _nwx_resolve_dep_names(_nl_pub_extra ${nl_PUBLIC})
    _nwx_resolve_dep_names(_nl_priv      ${nl_PRIVATE})

    if(nl_SOURCES)
        set(__nl_source_files ${nl_SOURCES})
    else()
        file(GLOB_RECURSE __nl_source_files CONFIGURE_DEPENDS ${nl_src_dir}/*.cpp)
        list(FILTER __nl_source_files EXCLUDE REGEX ".*/export_.*\\.cpp$")
    endif()

    if(__nl_source_files)
        add_library(${nl_project_name} ${nl_TYPE} ${__nl_source_files})
        target_link_libraries(${nl_project_name}
            PUBLIC  ${_nl_eco} ${_nl_pub_extra}
            PRIVATE ${_nl_priv}
        )
        target_include_directories(${nl_project_name}
            PUBLIC
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${nl_inc_dir}>
                $<INSTALL_INTERFACE:include>
            PRIVATE
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${nl_src_dir}/${nl_project_name}>
        )
        set_target_properties(
            ${nl_project_name} PROPERTIES POSITION_INDEPENDENT_CODE ON
        )
        # When shared, this library may itself need another shared library
        # (e.g. a FetchContent'd spdlog) at runtime. Both land in the same
        # "lib" directory via their own install_library() call below, so
        # $ORIGIN alone covers that placement -- but this library is also
        # sometimes co-installed a second time, flat, next to a pybind11
        # extension (see nwx_python_module.cmake), where its sibling would be
        # one directory down at "lib/", hence $ORIGIN/lib too. A no-op when
        # static (nothing dynamically loads at runtime).
        if(APPLE)
            set_target_properties(${nl_project_name}
                PROPERTIES INSTALL_RPATH "@loader_path;@loader_path/lib"
            )
        else()
            set_target_properties(${nl_project_name}
                PROPERTIES INSTALL_RPATH "$ORIGIN;$ORIGIN/lib"
            )
        endif()
    else()
        # Header-only library — INTERFACE target.
        # PRIVATE deps have no meaning for INTERFACE targets; they are silently
        # dropped (the library has no TUs to compile against them).
        add_library(${nl_project_name} INTERFACE)
        target_link_libraries(${nl_project_name}
            INTERFACE ${_nl_eco} ${_nl_pub_extra}
        )
        target_include_directories(${nl_project_name}
            INTERFACE
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${nl_inc_dir}>
                $<INSTALL_INTERFACE:include>
        )
    endif()

    if(NOT nl_NO_INSTALL)
        include(install_target)
        install_library(
            ${nl_project_name}
            "${CMAKE_CURRENT_SOURCE_DIR}/${nl_inc_dir}"
        )
    endif()
endfunction()
