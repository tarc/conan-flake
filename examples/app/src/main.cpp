#include "example-app.h"
#include <string>
#include <vector>

int main() {
  example_app();

  std::vector<std::string> vec;
  vec.push_back("test_package");

  example_app_print_vector(vec);
}
