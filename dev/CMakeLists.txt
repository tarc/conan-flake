cmake_minimum_required(VERSION 3.15)
project(foo CXX)

find_package(hello-world CONFIG REQUIRED)

add_executable(foo src/foo.cpp src/main.cpp)

target_link_libraries(foo hello-world::hello-world)

install(TARGETS foo DESTINATION "."
        RUNTIME DESTINATION bin
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        )
