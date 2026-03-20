cmake_minimum_required(VERSION 3.25)

if(NOT ORBIS_SDK_ROOT)
  set(ORBIS_SDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/orbis-wine/sdk/sdk" CACHE PATH "")
endif()

if(NOT ORBIS_TOOLCHAIN_ROOT)
  set(ORBIS_TOOLCHAIN_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/orbis-wine/toolchain" CACHE PATH "")
endif()

if(NOT ORBIS_TOOLCHAIN_BIN)
  set(ORBIS_TOOLCHAIN_BIN "${ORBIS_TOOLCHAIN_ROOT}/sdk/host_tools/bin" CACHE PATH "")
endif()

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
  message(FATAL_ERROR
    "Configure with -DCMAKE_TOOLCHAIN_FILE=${CMAKE_CURRENT_LIST_DIR}/scripts/orbis.cmake"
  )
endif()

project(MinecraftOrbis LANGUAGES C CXX)

set(_generated_dir "${CMAKE_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${_generated_dir}")

find_package(Python3 REQUIRED COMPONENTS Interpreter)

function(generate_orbis_metadata project_path prefix)
  set(output_file "${_generated_dir}/${prefix}.cmake")
  string(TOUPPER "${prefix}" prefix_upper)
  execute_process(
    COMMAND
      "${Python3_EXECUTABLE}"
      "${CMAKE_CURRENT_SOURCE_DIR}/scripts/gen_orbis_project.py"
      --project "${project_path}"
      --config Release
      --platform ORBIS
      --output "${output_file}"
      --var-prefix "${prefix}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMAND_ERROR_IS_FATAL ANY
  )
  include("${output_file}")
  foreach(var_suffix IN ITEMS PROJECT_DIR SOURCES INCLUDE_DIRS DEFINES LINK_DEPS COMPILE_SETTINGS)
    set(var_name "${prefix_upper}_${var_suffix}")
    set(${var_name} "${${var_name}}" PARENT_SCOPE)
  endforeach()
endfunction()

function(orbis_apply_compile_settings target settings)
  set(extra_options)
  foreach(setting IN LISTS settings)
    string(REPLACE "=" ";" setting_parts "${setting}")
    list(GET setting_parts 0 setting_key)
    list(REMOVE_AT setting_parts 0)
    string(JOIN "=" setting_value ${setting_parts})

    if(setting_key STREQUAL "RuntimeTypeInfo")
      if(setting_value STREQUAL "true")
        list(APPEND extra_options -frtti)
      elseif(setting_value STREQUAL "false")
        list(APPEND extra_options -fno-rtti)
      endif()
    elseif(setting_key STREQUAL "ExceptionHandling")
      if(setting_value STREQUAL "Sync")
        list(APPEND extra_options -fexceptions)
      elseif(setting_value STREQUAL "false" OR setting_value STREQUAL "None")
        list(APPEND extra_options -fno-exceptions)
      endif()
    elseif(setting_key STREQUAL "OptimizationLevel")
      if(setting_value STREQUAL "Level0")
        list(APPEND extra_options -O0)
      elseif(setting_value STREQUAL "Level1")
        list(APPEND extra_options -O1)
      elseif(setting_value STREQUAL "Level2")
        list(APPEND extra_options -O2)
      elseif(setting_value STREQUAL "Level3")
        list(APPEND extra_options -O3)
      elseif(setting_value STREQUAL "Levels")
        list(APPEND extra_options -Os)
      endif()
    elseif(setting_key STREQUAL "FastMath" AND setting_value STREQUAL "true")
      list(APPEND extra_options -ffast-math)
    endif()
  endforeach()

  if(extra_options)
    list(REMOVE_DUPLICATES extra_options)
    target_compile_options(${target} PRIVATE ${extra_options})
  endif()
endfunction()

generate_orbis_metadata("${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.World/Minecraft.World.vcxproj" world)
generate_orbis_metadata("${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Minecraft.Client.vcxproj" client)

function(orbis_resolve_path project_dir input output_var)
  set(value "${input}")
  string(REPLACE "$(ProjectDir)" "${project_dir}/" value "${value}")
  string(REPLACE "$(SCE_ORBIS_SDK_DIR)" "${ORBIS_SDK_ROOT}" value "${value}")
  string(REPLACE "\\\\" "/" value "${value}")
  string(REPLACE "\\" "/" value "${value}")
  if(NOT IS_ABSOLUTE "${value}")
    set(value "${project_dir}/${value}")
  endif()
  set(${output_var} "${value}" PARENT_SCOPE)
endfunction()

function(orbis_resolve_existing_path project_dir input output_var)
  orbis_resolve_path("${project_dir}" "${input}" resolved_path)

  if(EXISTS "${resolved_path}")
    set(${output_var} "${resolved_path}" PARENT_SCOPE)
    return()
  endif()

  if(IS_ABSOLUTE "${resolved_path}")
    set(current_path "/")
    string(SUBSTRING "${resolved_path}" 1 -1 resolved_without_root)
    string(REPLACE "/" ";" resolved_parts "${resolved_without_root}")

    foreach(part IN LISTS resolved_parts)
      if(part STREQUAL "")
        continue()
      endif()

      set(candidate_path "${current_path}${part}")
      if(EXISTS "${candidate_path}")
        set(current_path "${candidate_path}/")
        continue()
      endif()

      if(NOT EXISTS "${current_path}")
        break()
      endif()

      string(TOLOWER "${part}" part_lower)
      file(GLOB path_candidates LIST_DIRECTORIES TRUE "${current_path}*")
      set(found_match FALSE)
      foreach(candidate IN LISTS path_candidates)
        get_filename_component(candidate_name "${candidate}" NAME)
        string(TOLOWER "${candidate_name}" candidate_name_lower)
        if(candidate_name_lower STREQUAL part_lower)
          set(current_path "${candidate}/")
          set(found_match TRUE)
          break()
        endif()
      endforeach()

      if(NOT found_match)
        break()
      endif()
    endforeach()

    string(REGEX REPLACE "/$" "" current_path "${current_path}")
    if(EXISTS "${current_path}")
      set(${output_var} "${current_path}" PARENT_SCOPE)
      return()
    endif()
  endif()

  set(${output_var} "${resolved_path}" PARENT_SCOPE)
endfunction()

set(orbis_common_include_dirs
  "${ORBIS_SDK_ROOT}/target/include"
  "${ORBIS_SDK_ROOT}/target/include_common"
  "${ORBIS_SDK_ROOT}/host_tools/lib/clang/include"
)

set(orbis_common_compile_options
  -fPIC
  -integrated-as
  -fshort-wchar
  -w
)

add_library(MinecraftWorld_orbis STATIC ${WORLD_SOURCES})
set_target_properties(MinecraftWorld_orbis PROPERTIES
  OUTPUT_NAME "Minecraft.World"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/ORBIS_Release"
)
target_compile_options(MinecraftWorld_orbis PRIVATE ${orbis_common_compile_options})
orbis_apply_compile_settings(MinecraftWorld_orbis "${WORLD_COMPILE_SETTINGS}")
target_compile_definitions(MinecraftWorld_orbis PRIVATE ${WORLD_DEFINES} __ORBIS__)
target_include_directories(MinecraftWorld_orbis PRIVATE ${orbis_common_include_dirs})

foreach(dir IN LISTS WORLD_INCLUDE_DIRS)
  orbis_resolve_path("${WORLD_PROJECT_DIR}" "${dir}" resolved_dir)
  if(EXISTS "${resolved_dir}")
    target_include_directories(MinecraftWorld_orbis PRIVATE "${resolved_dir}")
  endif()
endforeach()

add_executable(MinecraftClient_orbis ${CLIENT_SOURCES})
set_target_properties(MinecraftClient_orbis PROPERTIES
  OUTPUT_NAME "Minecraft.Client"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/ORBIS_Release"
)
target_compile_options(MinecraftClient_orbis PRIVATE ${orbis_common_compile_options})
orbis_apply_compile_settings(MinecraftClient_orbis "${CLIENT_COMPILE_SETTINGS}")
target_compile_definitions(MinecraftClient_orbis PRIVATE ${CLIENT_DEFINES} __ORBIS__)
target_include_directories(MinecraftClient_orbis PRIVATE ${orbis_common_include_dirs})

# The 1.700 NP Toolkit import libs in this environment do not provide
# FutureImpl RTTI, so these call sites still need the original local workaround.
set_source_files_properties(
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/ClientConnection.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Leaderboards/OrbisLeaderboardManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Network/Orbis_NPToolkit.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Network/SonyCommerce_Orbis.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Network/SQRNetworkManager_Orbis.cpp"
  PROPERTIES COMPILE_OPTIONS "-fno-rtti;-fno-exceptions"
)

foreach(dir IN LISTS CLIENT_INCLUDE_DIRS)
  orbis_resolve_path("${CLIENT_PROJECT_DIR}" "${dir}" resolved_dir)
  if(EXISTS "${resolved_dir}")
    target_include_directories(MinecraftClient_orbis PRIVATE "${resolved_dir}")
  endif()
endforeach()

target_link_directories(MinecraftClient_orbis PRIVATE
  "${ORBIS_SDK_ROOT}/target/lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/4JLibs/Libs"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Iggy/lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Miles/lib"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Common/Network/Sony/sceRemoteStorage/ps4/lib"
)

target_link_libraries(MinecraftClient_orbis PRIVATE MinecraftWorld_orbis)

set(orbis_local_client_archives
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/4JLibs/Libs/4J_Render.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/4JLibs/Libs/4J_Input_r.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/4JLibs/Libs/4J_Storage_r.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/4JLibs/Libs/4J_Profile_r.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Iggy/lib/libiggy_orbis.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Iggy/lib/libiggyperfmon_orbis.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Miles/lib/mssorbis.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Miles/lib/mssorbismidi.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Miles/lib/fltorbis.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Orbis/Miles/lib/binkaorbis.a"
  "${CMAKE_CURRENT_SOURCE_DIR}/Minecraft.Client/Common/Network/Sony/sceRemoteStorage/ps4/lib/sceRemoteStorage.a"
)

foreach(archive IN LISTS orbis_local_client_archives)
  if(EXISTS "${archive}")
    target_link_libraries(MinecraftClient_orbis PRIVATE "${archive}")
  endif()
endforeach()

foreach(dep IN LISTS CLIENT_LINK_DEPS)
  if(dep MATCHES "^\\.\\./Minecraft\\.World/")
    continue()
  elseif(dep MATCHES "^[-]")
    string(REGEX REPLACE "^-l" "" dep_name "${dep}")
    target_link_libraries(MinecraftClient_orbis PRIVATE "${dep_name}")
  elseif(dep MATCHES "\\.(a|lib)$")
    orbis_resolve_existing_path("${CLIENT_PROJECT_DIR}" "${dep}" dep_path)
    if(EXISTS "${dep_path}" AND NOT IS_DIRECTORY "${dep_path}")
      target_link_libraries(MinecraftClient_orbis PRIVATE "${dep_path}")
    endif()
  endif()
endforeach()
