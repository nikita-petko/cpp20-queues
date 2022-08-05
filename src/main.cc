#include <stdint.h>
#include <iostream>

auto
main([[maybe_unused]] int32_t argc, [[maybe_unused]] const char* argv[], [[maybe_unused]] const char* envp[]) -> int32_t
{
	std::cout << "Hello, World!" << std::endl;
	return 0;
}