#include <stdint.h>

#define UART ((*(uint8_t *)0x10000000))

void putc(char c) {
	UART = c;
}

void puts(const char *str) {
	while (*str) putc(*str++);
}

int main() {
	puts("Hello, world!");

	return 0;
}
