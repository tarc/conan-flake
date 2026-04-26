#include <string>
#include <vector>

#include "example.h"
#include "hello-conan.h"


int main() {
  hello_conan();

  std::vector<std::string> vec;
  vec.push_back("test_package");

  example_print_vector(vec);
}
