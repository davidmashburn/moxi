cmake_minimum_required(VERSION 3.22)
project(moxi_android_host LANGUAGES CXX)

add_library(moxi_host SHARED
    ../hosts/moxi_android_host.cpp
    src/main/cpp/moxi_android_jni.cpp
)

target_include_directories(moxi_host PRIVATE ../hosts)
target_compile_features(moxi_host PRIVATE cxx_std_17)
target_compile_options(moxi_host PRIVATE -Wall -Wextra -Werror)
target_link_libraries(moxi_host PRIVATE android log)
