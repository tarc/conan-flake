#include <string>
#include <vector>

#include "foo.h"
#include "hello.h"


int main() {
  hello();

  std::vector<std::string> vec;
  vec.push_back("test_package");

  foo_print_vector(vec);
}
