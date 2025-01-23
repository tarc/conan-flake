#include "example.h"
#include <string>
#include <vector>

int main() {
  example();

  std::vector<std::string> vec;
  vec.push_back("test_package");

  example_print_vector(vec);
}
