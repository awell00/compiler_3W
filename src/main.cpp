#include <Arduino.h>
#include <Wire.h>
#include <ChainableLED.h>
#include <SD.h>
#include <SPI.h>
#include <RTClib.h>
#include "Seeed_BME280.h"

#define LUM_PIN 0

BME280 bme280;

ChainableLED led(4, 5, 1);

RTC_DS1307 rtc;

File myFile;

void setup()
{
    Serial.begin(9600);
    pinMode(LUM_PIN, INPUT);
    if(!bme280.init()){
        Serial.println("Device error!");
    }
    if (! rtc.begin()) {
        Serial.println("Couldn't find RTC");
        Serial.flush();
        while (1) delay(10);
    }
    if (! rtc.isrunning())
    {
        Serial.println("RTC is NOT running, let's set the time!");
        rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
    }

    while (!Serial);

    Serial.print("Initializing SD card...");

    if (!SD.begin(4)) {
        Serial.println("initialization failed. Things to check:");
        Serial.println("1. is a card inserted?");
        Serial.println("2. is your wiring correct?");
        Serial.println("3. did you change the chipSelect pin to match your shield or module?");
        Serial.println("Note: press reset button on the board and reopen this Serial Monitor after fixing your issue!");
        while (true);
    }

    Serial.println("initialization done.");

    myFile = SD.open("test.txt", FILE_WRITE);
    myFile.println("testing 1, 2, 3.");
    myFile.close();

}

void loop()
{
    led.setColorRGB(0, 255, 125, 0);

    int raw_lum = analogRead(LUM_PIN);
    int lum = map(raw_lum, 0, 1023, 0, 100);
    Serial.print("Luminosity: ");
    Serial.print(lum);
    Serial.println("%");

    Serial.print("Temp: ");
    Serial.print(bme280.getTemperature());
    Serial.println("C");//The unit for  Celsius because original arduino don't support speical symbols

    //get and print atmospheric pressure data
    Serial.print("Pressure: ");
    Serial.print(bme280.getPressure());
    Serial.println("Pa");

    //get and print humidity data
    Serial.print("Humidity: ");
    Serial.print(bme280.getHumidity());
    Serial.println("%");

    DateTime time = rtc.now();
    Serial.print("Date: ");
    Serial.println(time.timestamp(DateTime::TIMESTAMP_DATE));
    Serial.print("Time: ");
    Serial.println(time.timestamp(DateTime::TIMESTAMP_TIME));

    myFile = SD.open("test.txt");
    Serial.println("test.txt:");
    while (myFile.available()) {
        Serial.write(myFile.read());
    }
    myFile.close();

    delay(10000);
}