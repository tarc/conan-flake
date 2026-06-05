cmake_minimum_required(VERSION 3.15)
project(example CXX CUDA)

find_package(hello-world CONFIG REQUIRED)

find_package(CUDAToolkit 9.0 REQUIRED)

find_package(cuda-api-wrappers CONFIG REQUIRED)

add_executable(example src/example.cpp src/main.cpp)

target_link_libraries(example hello-world::hello-world)

install(
  TARGETS example
  DESTINATION "."
  RUNTIME DESTINATION bin
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib)
