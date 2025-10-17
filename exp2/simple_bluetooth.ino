/*
 * Arduino 藍牙ADC數據傳輸程式
 * 讀取ADC信號並透過藍牙發送到手機
 * 
 * 接線：
 * 藍牙模組 TXD -> Arduino Pin 2
 * 藍牙模組 RXD -> Arduino Pin 3
 * 藍牙模組 VCC -> 5V
 * 藍牙模組 GND -> GND
 * ADC信號 -> Arduino A0 (類比輸入)
 * 
 * 功能：
 * - 讀取A0引腳的ADC值
 * - 透過藍牙發送ADC數據到手機
 * - 接收並回應來自手機的指令
 * - 支援數據傳輸控制指令
 */

#include <SoftwareSerial.h>

// 建立藍牙序列埠
SoftwareSerial bluetooth(2, 3); // RX=2, TX=3

// 數據傳輸控制變數
bool dataTransmissionEnabled = false;
unsigned long lastDataTime = 0;
const unsigned long dataInterval = 100; // 100ms間隔發送數據 (10Hz)

void setup() {
  // 初始化序列埠
  Serial.begin(9600);
  bluetooth.begin(9600);
  
  // 等待藍牙模組初始化
  delay(2000);
  
  Serial.println("Arduino ADC藍牙傳輸系統已啟動！");
  Serial.println("請在手機上搜尋並連接藍牙裝置");
  
  // 測試藍牙模組
  Serial.println("測試藍牙模組...");
  bluetooth.println("Arduino ADC系統已連接！");
  Serial.println("已發送歡迎訊息");
  
  // 發送系統狀態
  delay(1000);
  bluetooth.println("ADC_READY");
  delay(1000);
  bluetooth.println("SYSTEM_STATUS:READY");
  Serial.println("系統已準備就緒");
}

void loop() {
  // 檢查是否收到手機訊息
  if (bluetooth.available()) {
    String message = bluetooth.readString();
    message.trim(); // 移除多餘的空白字符
    
    // 在序列埠監視器打印收到的訊息
    Serial.println("收到來自手機的訊息: " + message);
    
    // 處理控制指令
    if (message.equals("START_ADC")) {
      dataTransmissionEnabled = true;
      Serial.println("開始ADC數據傳輸");
      bluetooth.println("ADC_TRANSMISSION:STARTED");
    } else if (message.equals("STOP_ADC")) {
      dataTransmissionEnabled = false;
      Serial.println("停止ADC數據傳輸");
      bluetooth.println("ADC_TRANSMISSION:STOPPED");
    } else if (message.equals("STATUS")) {
      Serial.println("執行: 狀態查詢");
      String statusMsg = "SYSTEM_STATUS:READY,ADC_ENABLED:" + String(dataTransmissionEnabled ? "TRUE" : "FALSE");
      bluetooth.println(statusMsg);
    } else {
      // 回應一般訊息
      bluetooth.println("Arduino收到: " + message);
    }
  }
  
  // ADC數據傳輸
  if (dataTransmissionEnabled && (millis() - lastDataTime >= dataInterval)) {
    // 讀取A0引腳的ADC值
    int adcValue = analogRead(A0);
    
    // 轉換為電壓值 (0-5V)
    float voltage = (adcValue * 5.0) / 1023.0;
    
    // 發送ADC數據到手機
    String dataMsg = "ADC_DATA:" + String(adcValue) + "," + String(voltage, 3);
    bluetooth.println(dataMsg);
    
    // 在序列埠監視器顯示
    Serial.println("ADC: " + String(adcValue) + " (" + String(voltage, 3) + "V)");
    
    lastDataTime = millis();
  }
  
  // 每5秒發送一次心跳訊息
  static unsigned long lastHeartbeat = 0;
  if (millis() - lastHeartbeat > 5000) {
    String heartbeatMsg = "HEARTBEAT:" + String(millis()/1000) + "s";
    Serial.println("發送心跳: " + heartbeatMsg);
    bluetooth.println(heartbeatMsg);
    lastHeartbeat = millis();
  }
}
