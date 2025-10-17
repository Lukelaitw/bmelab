/*
 * Arduino 藍牙模組傳送訊息給手機
 * 支援 HC-05, HC-06, HM-10 等藍牙模組
 * 
 * 接線說明：
 * HC-05/HC-06:
 * - VCC -> 5V (或 3.3V)
 * - GND -> GND
 * - TXD -> Arduino Pin 2 (RX)
 * - RXD -> Arduino Pin 3 (TX)
 * 
 * HM-10:
 * - VCC -> 3.3V
 * - GND -> GND
 * - TXD -> Arduino Pin 2 (RX)
 * - RXD -> Arduino Pin 3 (TX)
 */

#include <SoftwareSerial.h>

// 藍牙模組接腳設定
const int BT_RX_PIN = 2;  // Arduino 接藍牙模組 TXD
const int BT_TX_PIN = 3;  // Arduino 接藍牙模組 RXD
SoftwareSerial bluetooth(BT_RX_PIN, BT_TX_PIN);

// 感測器接腳
const int SENSOR_PIN = A0;        // 類比感測器
const int BUTTON_PIN = 4;         // 按鈕
const int LED_PIN = 13;           // 內建LED

// 變數
int sensorValue = 0;
bool buttonState = false;
bool lastButtonState = false;
unsigned long lastSendTime = 0;
const unsigned long SEND_INTERVAL = 1000; // 每秒傳送一次

void setup() {
  // 初始化序列埠
  Serial.begin(9600);
  bluetooth.begin(9600);
  
  // 設定接腳模式
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  
  // 等待藍牙模組初始化
  delay(1000);
  
  Serial.println("=== Arduino 藍牙傳送系統 ===");
  Serial.println("系統已就緒，等待手機連接...");
  Serial.println("請在手機上開啟藍牙並搜尋裝置");
  
  // 發送初始訊息
  sendMessage("Arduino已連接！");
}

void loop() {
  // 讀取感測器數據
  sensorValue = analogRead(SENSOR_PIN);
  
  // 讀取按鈕狀態
  buttonState = !digitalRead(BUTTON_PIN); // 使用內部上拉電阻，所以按鈕按下時為LOW
  
  // 檢查按鈕是否被按下
  if (buttonState && !lastButtonState) {
    sendMessage("按鈕被按下！");
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
  }
  lastButtonState = buttonState;
  
  // 定期傳送感測器數據
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    sendSensorData();
    lastSendTime = millis();
  }
  
  // 檢查是否收到手機的指令
  if (bluetooth.available()) {
    String command = bluetooth.readString();
    command.trim();
    handleCommand(command);
  }
  
  // 將收到的藍牙訊息轉發到序列埠監視器
  if (bluetooth.available()) {
    char c = bluetooth.read();
    Serial.write(c);
  }
  
  delay(50); // 短暫延遲
}

// 傳送訊息到手機
void sendMessage(String message) {
  bluetooth.println(message);
  Serial.println("傳送到手機: " + message);
}

// 傳送感測器數據
void sendSensorData() {
  String data = "感測器數值: " + String(sensorValue);
  sendMessage(data);
  
  // 根據感測器數值發送不同訊息
  if (sensorValue > 800) {
    sendMessage("感測器數值很高！");
  } else if (sensorValue < 200) {
    sendMessage("感測器數值很低！");
  }
}

// 處理來自手機的指令
void handleCommand(String command) {
  Serial.println("收到指令: " + command);
  
  if (command == "LED_ON") {
    digitalWrite(LED_PIN, HIGH);
    sendMessage("LED已開啟");
  }
  else if (command == "LED_OFF") {
    digitalWrite(LED_PIN, LOW);
    sendMessage("LED已關閉");
  }
  else if (command == "STATUS") {
    sendMessage("系統狀態正常");
    sendMessage("感測器數值: " + String(sensorValue));
    sendMessage("按鈕狀態: " + String(buttonState ? "按下" : "未按下"));
  }
  else if (command == "HELLO") {
    sendMessage("你好！我是Arduino！");
  }
  else {
    sendMessage("未知指令: " + command);
  }
}
