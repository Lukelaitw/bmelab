

#include <SoftwareSerial.h>

const int RX_PIN = 2;  // Arduino 接 HC-06 TXD
const int TX_PIN = 3;  // Arduino 接 HC-06 RXD (建議加分壓)
SoftwareSerial BT(RX_PIN, TX_PIN);

const int SENSOR_PIN = A0;
int value = 0;

void setup() {
  Serial.begin(9600);   // 與電腦溝通
  BT.begin(9600);       // 與 HC-06 / HM-10 溝通
  Serial.println("System ready. Type AT to test connection.");
}

void loop() {
  // 讀感測器
  value = analogRead(SENSOR_PIN);

  // 傳送到手機
  BT.print("ADC=");
  BT.println(value);

  // 如果手機傳資料過來，印到 Serial Monitor
  if (BT.available()) {
    char c = BT.read();
    Serial.write(c);
  }

  delay(1000); // 每秒送一次
}