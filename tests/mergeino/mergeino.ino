#include <ESP8266WiFi.h>
#include <Ticker.h>
#include <ESP8266WebServer.h>
#include <ESP8266mDNS.h>
#include <myLib.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266httpUpdate.h> // for OTA
#include "other.h"
#include "other1.h"

ESP8266WebServer httpServer(80);


Other other;
void setup() {
  other1(8);
  myLib("toto");
//  secondFunction(true);
}



void loop() {
  
}