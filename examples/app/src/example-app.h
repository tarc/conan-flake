#pragma once

#include <string>
#include <vector>

#ifdef _WIN32
#define EXAMPLE_APP_EXPORT __declspec(dllexport)
#else
#define EXAMPLE_APP_EXPORT
#endif

EXAMPLE_APP_EXPORT void example_app();
EXAMPLE_APP_EXPORT void
example_app_print_vector(const std::vector<std::string> &strings);
