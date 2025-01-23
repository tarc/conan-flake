cmake_minimum_required(VERSION 3.15)
project(example-app CXX)



add_executable(example-app src/example-app.cpp src/main.cpp)



install(TARGETS example-app DESTINATION "."
        RUNTIME DESTINATION bin
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        )
