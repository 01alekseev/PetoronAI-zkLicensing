cmake_minimum_required(VERSION 3.20)

project(PetoronAILicensing
    VERSION 1.0.0
    LANGUAGES CXX OBJCXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(ZKPETORON_BUILD_TESTS OFF CACHE BOOL "" FORCE)

add_subdirectory(
    zkPetoron-Core
    ${CMAKE_BINARY_DIR}/zkPetoron-Core-build
)


add_executable(petoron_ai_licensing
    src/main.mm
    src/ui/deposit.mm
    src/ui/withdraw.mm
)

target_include_directories(petoron_ai_licensing
    PRIVATE
        src
        zkPetoron-Core
)

target_link_libraries(petoron_ai_licensing
    PRIVATE
        zkpetoron
        "-framework Cocoa"
)

target_compile_options(petoron_ai_licensing
    PRIVATE
        -fobjc-arc
)

set_target_properties(petoron_ai_licensing
    PROPERTIES
        OUTPUT_NAME "petoron_ai_licensing"
)
