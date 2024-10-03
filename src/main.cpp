#include <Arduino.h>
#include <ChainableLED.h>

// Define the pins for the clock and data
#define CLK_PIN 7
#define DATA_PIN 8
#define NUM_LEDS 1

ChainableLED leds(CLK_PIN, DATA_PIN, NUM_LEDS);

void setup() {
  Serial.begin(9600);
  leds.setColorRGB(0, 255, 0, 0); // Set the first LED to red
}

void loop() {
  Serial.println("Hello World");
  delay(1000); // Wait for 1 second
  leds.setColorRGB(0, 0, 255, 0); // Set the first LED to green
  delay(1000); // Wait for 1 second
  leds.setColorRGB(0, 0, 0, 255); // Set the first LED to blue
  delay(1000); // Wait for 1 second
}