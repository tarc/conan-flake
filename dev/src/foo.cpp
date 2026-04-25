#include <iostream>

#include "foo.h"

void foo_print_vector(const std::vector<std::string> &strings) {
  for (std::vector<std::string>::const_iterator it = strings.begin();
       it != strings.end(); ++it) {
    std::cout << "foo/1.0 " << *it << std::endl;
  }
}
