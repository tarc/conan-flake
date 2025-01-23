cmake_minimum_required(VERSION 3.15)
project(example-library CXX)




add_library(example-library src/example.cpp)
target_include_directories(example-library PUBLIC include)



set_target_properties(example-library PROPERTIES PUBLIC_HEADER "include/example.h")
install(TARGETS example-library)
