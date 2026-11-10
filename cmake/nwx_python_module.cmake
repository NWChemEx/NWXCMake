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
# Builds a pybind11 extension module from the export_*.cpp files under
# nwx_python_src_dir.
#
# Keyword args (both optional; needed for test-only helper modules like
# py_test_<repo> or <repo>_examples, which shouldn't ship in the wheel and
# may need to link libraries beyond ${PROJECT_NAME}):
#   NO_INSTALL       -- skip installing the module. Use for modules that only
#                        exist to support the test suite.
#   DEPENDS <libs>    -- extra libraries linked into the module PRIVATEly,
#                        in addition to ${PROJECT_NAME}.
#]]
function(nwx_python_module nwx_python_module_name nwx_python_src_dir)
    cmake_parse_arguments(npm "NO_INSTALL" "" "DEPENDS" ${ARGN})

    if(NOT BUILD_PYBIND11_BINDINGS)
        return()
    endif()

    include(get_dependencies)
    get_dependencies(pybind11)
    # pybind11 v3 builds extensions via python_add_library, which is provided by
    # the modern FindPython module's Development.Module component.
    find_package(Python REQUIRED COMPONENTS Interpreter Development.Module)
    # DEPENDS may name an ecosystem dep (e.g. "parallelzone") whose real
    # target is only known via NWX_DEP_TARGET_<name> -- it can be
    # "nwx::parallelzone" (found via find_package against an installed
    # wheel) rather than the bare short name (FetchContent'd in-tree).
    include(nwx_library)
    _nwx_resolve_dep_names(npm_DEPENDS ${npm_DEPENDS})
    file(
        GLOB_RECURSE __nwx_python_module_source_files
        CONFIGURE_DEPENDS ${nwx_python_src_dir}/*.cpp
    )
    list(FILTER __nwx_python_module_source_files INCLUDE REGEX ".*/export_.*\\.cpp$")
    pybind11_add_module(
        ${nwx_python_module_name}_python ${__nwx_python_module_source_files}
    )
    target_link_libraries(${nwx_python_module_name}_python PRIVATE
        ${PROJECT_NAME} ${npm_DEPENDS}
    )
    # The bindings live alongside the library sources; add that dir so their
    # sibling helper headers resolve regardless of the repo's cxx/ vs cpp/
    # layout. The linked library already carries its public include dir.
    target_include_directories(${nwx_python_module_name}_python PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/${nwx_python_src_dir}
    )
    set_target_properties(
        ${nwx_python_module_name}_python
        PROPERTIES OUTPUT_NAME ${nwx_python_module_name}
    )

    # When ${PROJECT_NAME} (and anything *it* links shared, e.g. a
    # FetchContent'd spdlog) is a shared library, the extension loads it at
    # runtime via an rpath. Shared libraries are installed only to "lib"
    # (install_library() for ${PROJECT_NAME}, and each FetchContent'd
    # dependency's own install() rule), which is the extension's "lib"
    # subdirectory in a wheel and its own directory in a plain install, so
    # search both. Harmless when everything is static (the extension is then
    # self-contained and there's nothing at either path).
    if(APPLE)
        set_target_properties(${nwx_python_module_name}_python
            PROPERTIES INSTALL_RPATH "@loader_path;@loader_path/lib"
        )
    else()
        set_target_properties(${nwx_python_module_name}_python
            PROPERTIES INSTALL_RPATH "$ORIGIN;$ORIGIN/lib"
        )
    endif()

    if(npm_NO_INSTALL)
        return()
    endif()

    set(_nwx_py_dest
        "$<IF:$<BOOL:${SKBUILD_PLATLIB_DIR}>,${SKBUILD_PLATLIB_DIR},lib>"
    )
    # Same per-project component as install_library() (see install_target.cmake).
    # N.B. ${PROJECT_NAME} is NOT installed a second time next to the
    # extension. Two copies of a library in one wheel can both be loaded into
    # one process (e.g., one found through an "@loader_path" rpath and one
    # through "@loader_path/lib"). Each copy then has its own RTTI and
    # statics, so, e.g., a dynamic_cast across the two copies fails.
    install(TARGETS ${nwx_python_module_name}_python
        DESTINATION "${_nwx_py_dest}"
        COMPONENT "${PROJECT_NAME}"
    )
endfunction()
