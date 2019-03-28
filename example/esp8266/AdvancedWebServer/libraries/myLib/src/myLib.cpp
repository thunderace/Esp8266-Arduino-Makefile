#include <Hash.h>

void myLib(const char *name) {
  uint8_t hash[20];
  sha1("test", &hash[0]);
  Serial.println(name);
}