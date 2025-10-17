// HM-10 BLE 模組專用程式碼
// 注意：HM-10 使用 Hardware Serial (通常是 Serial1 或 Serial2)
// 如果您的 Arduino 只有一個 Serial，請使用 SoftwareSerial

#include <SoftwareSerial.h>

// HM-10 連接設定
SoftwareSerial BTSerial(2, 3); // RX (connect to HM-10 TX), TX (connect to HM-10 RX)
bool start_recv = false;
const long baud_rate = 9600; // HM-10 預設波特率
int in = A0;
bool adc_running = false;
unsigned long last_send_time = 0;
const unsigned long send_interval = 100; // 發送間隔 (毫秒)

// 添加數據緩衝區和錯誤處理
String data_buffer = "";
bool data_ready = false;
int error_count = 0;
const int max_errors = 10;
bool hm10_initialized = false;

void setup() {
  Serial.begin(baud_rate);
  BTSerial.begin(baud_rate);
  
  // 等待 HM-10 模組初始化
  delay(2000);
  
  Serial.println("Arduino HM-10 BLE 發送器已啟動");
  Serial.println("等待 BLE 連接...");
  
  // 初始化 HM-10 模組
  initializeHM10();
  
  // 發送初始化信號
  BTSerial.println("ARDUINO_READY");
  Serial.println("📤 發送初始化信號: ARDUINO_READY");
  
  // 測試藍牙通訊
  BTSerial.println("TEST_CONNECTION");
  Serial.println("📤 發送測試信號: TEST_CONNECTION");
}

// HM-10 初始化函數
void initializeHM10() {
  Serial.println("🔧 初始化 HM-10 模組...");
  
  // 發送 AT 指令檢查連接
  BTSerial.println("AT");
  delay(1000);
  
  // 設定 HM-10 為從機模式
  BTSerial.println("AT+ROLE0");
  delay(1000);
  
  // 設定設備名稱
  BTSerial.println("AT+NAMEArduino_ECG");
  delay(1000);
  
  // 設定波特率
  BTSerial.println("AT+BAUD9600");
  delay(1000);
  
  // 開始廣播
  BTSerial.println("AT+ADVI1");
  delay(1000);
  
  Serial.println("✅ HM-10 初始化完成");
  hm10_initialized = true;
}

void loop() {
  // 檢查藍牙接收
  if (BTSerial.available()) {
    char c = BTSerial.read();
    
    if (c == '\n' || c == '\r') {
      if (data_buffer.length() > 0) {
        String received = data_buffer;
        data_buffer = "";
        
        Serial.print("📥 收到藍牙指令: ");
        Serial.println(received);
        
        // 處理接收到的指令
        if (received == "START_ADC") {
          adc_running = true;
          Serial.println("✅ 開始ADC數據傳輸");
          BTSerial.println("ADC_TRANSMISSION:STARTED");
          Serial.println("📤 發送回應: ADC_TRANSMISSION:STARTED");
          error_count = 0; // 重置錯誤計數
        }
        else if (received == "STOP_ADC") {
          adc_running = false;
          Serial.println("⏹️ 停止ADC數據傳輸");
          BTSerial.println("ADC_TRANSMISSION:STOPPED");
          Serial.println("📤 發送回應: ADC_TRANSMISSION:STOPPED");
        }
        else if (received == "STATUS") {
          Serial.println("🔍 狀態查詢");
          BTSerial.println("SYSTEM_STATUS:READY");
          Serial.println("📤 發送回應: SYSTEM_STATUS:READY");
        }
        else if (received == "HELLO") {
          Serial.println("👋 通訊測試");
          BTSerial.println("HEARTBEAT:OK");
          Serial.println("📤 發送回應: HEARTBEAT:OK");
        }
        else if (received == "PING") {
          Serial.println("🏓 收到PING");
          BTSerial.println("PONG");
          Serial.println("📤 發送回應: PONG");
        }
        else {
          Serial.print("❓ 未知指令: ");
          Serial.println(received);
          error_count++;
        }
      }
    } else {
      data_buffer += c;
    }
  }
  
  // 如果ADC正在運行，定期發送數據
  if (adc_running && (millis() - last_send_time >= send_interval)) {
    int adc_value = analogRead(A0);
    double voltage = (adc_value * 5.0) / 1023.0;
    
    // 檢查錯誤計數，如果錯誤太多則停止
    if (error_count >= max_errors) {
      Serial.println("❌ 錯誤過多，停止ADC傳輸");
      adc_running = false;
      BTSerial.println("ADC_TRANSMISSION:ERROR");
      return;
    }
    
    // 發送格式化的數據，添加時間戳
    unsigned long timestamp = millis();
    String data_string = "ADC_DATA:" + String(adc_value) + "," + String(voltage, 3) + "," + String(timestamp);
    
    // HM-10 專用數據發送
    sendToHM10(data_string);
    
    // 在序列埠監視器中也顯示
    Serial.print("📤 發送藍牙數據: ");
    Serial.println(data_string);
    Serial.print("📊 ADC: ");
    Serial.print(adc_value);
    Serial.print(" (");
    Serial.print(voltage, 3);
    Serial.print("V) - 時間: ");
    Serial.println(timestamp);
    
    last_send_time = millis();
  }
  
  // 定期發送心跳信號（即使ADC未運行）
  static unsigned long last_heartbeat = 0;
  if (millis() - last_heartbeat >= 5000) { // 每5秒發送一次心跳
    sendToHM10("HEARTBEAT:ALIVE");
    Serial.println("💓 發送心跳信號");
    last_heartbeat = millis();
  }
}

// HM-10 專用數據發送函數
void sendToHM10(String data) {
  if (!hm10_initialized) {
    Serial.println("⚠️ HM-10 未初始化，跳過發送");
    return;
  }
  
  // 檢查藍牙連接狀態
  if (BTSerial.availableForWrite() > 0) {
    // 使用 AT+NOTI 指令發送數據
    BTSerial.print("AT+NOTI");
    BTSerial.print(data);
    BTSerial.println();
    
    // 等待發送完成
    delay(10);
    
    Serial.println("✅ 數據已發送到 HM-10");
  } else {
    Serial.println("⚠️ HM-10 緩衝區已滿，跳過數據發送");
  }
}

// 檢查 HM-10 連接狀態
bool checkHM10Connection() {
  BTSerial.println("AT+CONN?");
  delay(100);
  
  if (BTSerial.available()) {
    String response = BTSerial.readString();
    response.trim();
    return response.indexOf("OK") >= 0;
  }
  return false;
}
