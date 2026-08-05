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
#   NO_INSTALL       -- skip installing the module (and re-installing
#                        ${PROJECT_NAME}). Use for modules that only exist to
#                        support the test suite.
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
    # runtime via an rpath. Search both the extension's own directory --
    # where ${PROJECT_NAME} is co-installed, below -- and its "lib"
    # subdirectory, which is where a FetchContent'd shared dependency lands
    # via *its own* bundled install() rule (e.g. spdlog installs itself to
    # the plain relative "lib" destination, regardless of this function's
    # SKBUILD-aware _nwx_py_dest). Harmless when everything is static (the
    # extension is then self-contained and there's nothing at either path).
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
    install(TARGETS ${nwx_python_module_name}_python DESTINATION "${_nwx_py_dest}")
    # Co-install the C++ library next to the extension too (in addition to
    # its own normal "lib" install elsewhere in the project) so a
    # self-contained wheel (or plain install) can load it via the rpath set
    # above without depending on relative-path math between the two
    # locations. This is a no-op for a static library (nothing to install
    # under LIBRARY/RUNTIME).
    install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION "${_nwx_py_dest}"
        RUNTIME DESTINATION "${_nwx_py_dest}"
    )
endfunction()
