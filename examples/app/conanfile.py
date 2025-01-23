import os
from conan import ConanFile
from conan.tools.build import check_min_cppstd
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout, CMakeDeps
from conan.tools.files import copy


class example_appRecipe(ConanFile):
    name = "example-app"
    version = "0.1.0"
    package_type = "application"

    # Optional metadata
    license = "Copyleft"
    author = "John Doe john@doe.com"
    url = "https://doe.com/example-library"
    description = "Example Application"
    topics = ("flake", "library")

    # Binary configuration
    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    # Sources are located in the same place as this recipe, copy them to the recipe
    exports_sources = "CMakeLists.txt", "src/*", "tests/*"

    def deploy(self):
        copy(self, "*", src=self.package_folder, dst=self.deploy_folder)

    def build_requirements(self):
        self.tool_requires("cmake/[>=3.30]")
        self.test_requires("catch2/[>=3.2.1]")

    def validate(self):
        check_min_cppstd(self, "17")

    def config_options(self):
        if self.settings.os == "Windows":
            del self.options.fPIC

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
        cmake.test()

    def package(self):
        cmake = CMake(self)
        cmake.install()
