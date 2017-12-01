#include <Hash.h>

void myLib(const char *name) {
  uint8_t * hash = (uint8_t*)malloc(20);
  sha1("MYKEY", hash);
  Serial.println(name);
}