from conan import ConanFile
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout


class fooRecipe(ConanFile):
    name = "foo"
    version = "1.0"
    package_type = "application"

    # Optional metadata
    license = "MIT"
    author = "Tarcisio G. Rodrigues"
    homepage = "https://codeberg.org:tarcisio/conan-flake"
    description = "This is the Foo dev project."
    topics = ("testing", "foo", "conan")

    # Binary configuration
    settings = "os", "compiler", "build_type", "arch"

    # Sources are located in the same place as this recipe, copy them to the recipe
    exports_sources = "CMakeLists.txt", "src/*"

    def layout(self):
        cmake_layout(self)

    def requirements(self):
        self.requires("hello/0.1")

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()
