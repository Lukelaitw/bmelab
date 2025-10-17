import 'package:flutter/material.dart';
import 'dart:async';
import 'bluetooth_manager.dart';

class DataPage extends StatefulWidget {
  final BluetoothManager bluetoothManager;
  
  const DataPage({
    super.key,
    required this.bluetoothManager,
  });

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final List<String> _messageHistory = [];
  StreamSubscription<String>? _dataSubscription;
  String _currentData = '';
  bool _isReceiving = false;
  final TextEditingController _messageController = TextEditingController();
  
  // Arduino數據解析相關
  int _latestAdcValue = 0;
  double _latestVoltage = 0.0;
  String _systemStatus = '未知';
  String _adcTransmissionStatus = '停止';
  String _heartbeatStatus = '無';
  List<int> _adcHistory = [];
  List<double> _voltageHistory = [];
  DateTime? _lastDataTime;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startListening() {
    print('開始監聽藍牙數據流...');
    _dataSubscription = widget.bluetoothManager.dataStream.listen(
      (data) {
        print('DataPage 收到數據: $data');
        setState(() {
          // 處理接收到的數據
          String cleanData = data.trim();
          if (cleanData.isNotEmpty) {
            // 如果數據包含換行符，分割成多行
            List<String> lines = cleanData.split('\n');
            for (String line in lines) {
              line = line.trim();
              if (line.isNotEmpty) {
                _processReceivedData(line);
                _currentData = line; // 更新當前數據
                _messageHistory.add('${DateTime.now().toString().substring(11, 19)}: $line');
                _isReceiving = true;
              }
            }
          }
          
          // 限制歷史記錄數量
          if (_messageHistory.length > 100) {
            _messageHistory.removeAt(0);
          }
        });
      },
      onError: (error) {
        print('數據流錯誤: $error');
        setState(() {
          _isReceiving = false;
        });
      },
      onDone: () {
        print('數據流已關閉');
        setState(() {
          _isReceiving = false;
        });
      },
    );
  }

  void _processReceivedData(String data) {
    // 在終端中顯示所有接收到的原始數據
    print('🔵 Arduino 原始數據: "$data"');
    
    // 解析ADC數據
    if (data.startsWith('ADC_DATA:')) {
      String adcData = data.substring(9); // 移除 'ADC_DATA:' 前綴
      List<String> parts = adcData.split(',');
      if (parts.length >= 2) {
        try {
          int adcValue = int.parse(parts[0]);
          double voltage = double.parse(parts[1]);
          int timestamp = parts.length >= 3 ? int.parse(parts[2]) : 0;
          
          setState(() {
            _latestAdcValue = adcValue;
            _latestVoltage = voltage;
            _lastDataTime = DateTime.now();
            
            // 添加到歷史記錄（限制數量）
            _adcHistory.add(adcValue);
            _voltageHistory.add(voltage);
            if (_adcHistory.length > 50) {
              _adcHistory.removeAt(0);
              _voltageHistory.removeAt(0);
            }
          });
          
          // 在命令行中詳細顯示ADC數據
          print('=' * 80);
          print('📊 [Arduino ADC 數據解析]');
          print('=' * 80);
          print('⏰ 接收時間: ${DateTime.now().toString().substring(11, 19)}');
          print('🔢 ADC 數值: $adcValue (0-1023)');
          print('⚡ 電壓值: ${voltage.toStringAsFixed(3)} V');
          if (timestamp > 0) {
            print('⏱️ Arduino時間戳: ${timestamp}ms');
          }
          print('📈 數據點數: ${_adcHistory.length}');
          if (_adcHistory.length > 1) {
            double avgAdc = _adcHistory.reduce((a, b) => a + b) / _adcHistory.length;
            double avgVoltage = _voltageHistory.reduce((a, b) => a + b) / _voltageHistory.length;
            print('📊 平均ADC: ${avgAdc.toStringAsFixed(1)}');
            print('📊 平均電壓: ${avgVoltage.toStringAsFixed(3)} V');
          }
          print('=' * 80);
        } catch (e) {
          print('❌ 解析ADC數據失敗: $e');
        }
      }
    }
    // 解析系統狀態
    else if (data.startsWith('SYSTEM_STATUS:')) {
      String status = data.substring(14);
      setState(() {
        _systemStatus = status;
      });
      print('=' * 60);
      print('🔧 [Arduino 系統狀態]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('📋 狀態: $status');
      print('=' * 60);
    }
    // 解析ADC傳輸狀態
    else if (data.startsWith('ADC_TRANSMISSION:')) {
      String status = data.substring(17);
      setState(() {
        _adcTransmissionStatus = status == 'STARTED' ? '運行中' : '停止';
      });
      print('=' * 60);
      print('⚡ [Arduino ADC 傳輸狀態]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('🔄 傳輸狀態: ${status == 'STARTED' ? '運行中' : '停止'}');
      print('=' * 60);
    }
    // 解析心跳
    else if (data.startsWith('HEARTBEAT:')) {
      String heartbeat = data.substring(10);
      setState(() {
        _heartbeatStatus = heartbeat;
      });
      print('=' * 60);
      print('💓 [Arduino 心跳檢測]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('💗 心跳狀態: $heartbeat');
      print('=' * 60);
    }
    // 處理PONG回應
    else if (data == 'PONG') {
      print('=' * 60);
      print('🏓 [Arduino PONG 回應]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('✅ 通訊正常');
      print('=' * 60);
    }
    // 處理初始化信號
    else if (data == 'ARDUINO_READY') {
      print('=' * 60);
      print('🚀 [Arduino 初始化完成]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('✅ Arduino 已準備就緒');
      print('=' * 60);
    }
    // 處理測試連接回應
    else if (data == 'TEST_CONNECTION') {
      print('=' * 60);
      print('🔗 [Arduino 連接測試]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('✅ 連接測試成功');
      print('=' * 60);
    }
    // 處理其他類型的數據
    else {
      print('=' * 60);
      print('📝 [Arduino 其他數據]');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('📄 內容: $data');
      print('=' * 60);
    }
  }

  void _clearData() {
    setState(() {
      _currentData = '';
      _messageHistory.clear();
      _isReceiving = false;
      _latestAdcValue = 0;
      _latestVoltage = 0.0;
      _systemStatus = '未知';
      _adcTransmissionStatus = '停止';
      _heartbeatStatus = '無';
      _adcHistory.clear();
      _voltageHistory.clear();
      _lastDataTime = null;
    });
  }

  void _sendMessage(String message) async {
    if (message.isNotEmpty) {
      // 在命令行中顯示即將發送的指令
      print('=' * 60);
      print('📤 [Flutter 發送指令] 到 Arduino');
      print('=' * 60);
      print('⏰ 時間: ${DateTime.now().toString().substring(11, 19)}');
      print('📝 指令: "$message"');
      print('🎯 指令類型: ${_getCommandType(message)}');
      print('=' * 60);
      
      bool success = await widget.bluetoothManager.sendData(message);
      if (success) {
        setState(() {
          _messageHistory.add('${DateTime.now().toString().substring(11, 19)}: [發送] $message');
        });
        print('✅ 指令發送成功');
      } else {
        print('❌ 指令發送失敗');
        _showDialog('發送失敗', '無法發送訊息');
      }
    }
  }
  
  String _getCommandType(String message) {
    switch (message) {
      case 'START_ADC':
        return '開始ADC數據傳輸';
      case 'STOP_ADC':
        return '停止ADC數據傳輸';
      case 'STATUS':
        return '查詢系統狀態';
      case 'HELLO':
        return '通訊測試';
      default:
        return '自定義指令';
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('數據接收'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearData,
            icon: const Icon(Icons.clear),
            tooltip: '清除數據',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 連接狀態
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.bluetoothManager.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: widget.bluetoothManager.isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.bluetoothManager.isConnected 
                              ? '已連接到: ${widget.bluetoothManager.deviceName}'
                              : '未連接藍牙設備',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_isReceiving) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('正在接收數據...', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 發送訊息區域
            if (widget.bluetoothManager.isConnected) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '發送訊息',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: '輸入要發送的訊息',
                                border: OutlineInputBorder(),
                              ),
                              ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (_messageController.text.isNotEmpty) {
                                _sendMessage(_messageController.text);
                                _messageController.clear();
                              }
                            },
                            child: const Text('發送'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ADC控制按鈕
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendMessage('START_ADC'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('開始ADC'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _sendMessage('STOP_ADC'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('停止ADC'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _sendMessage('STATUS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('狀態查詢'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 測試按鈕
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendMessage('HELLO'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('測試通訊'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _sendMessage('PING'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('PING測試'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // 模擬接收ADC數據用於測試顯示
                              setState(() {
                                _currentData = 'ADC_DATA:512,2.500,12345';
                                _messageHistory.add('${DateTime.now().toString().substring(11, 19)}: ADC_DATA:512,2.500,12345');
                                _isReceiving = true;
                                _processReceivedData('ADC_DATA:512,2.500,12345');
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('測試ADC'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Arduino數據狀態卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arduino 系統狀態',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            '系統狀態',
                            _systemStatus,
                            Icons.settings,
                            _systemStatus == 'READY' ? Colors.green : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusCard(
                            'ADC傳輸',
                            _adcTransmissionStatus,
                            Icons.speed,
                            _adcTransmissionStatus == '運行中' ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            '心跳狀態',
                            _heartbeatStatus,
                            Icons.favorite,
                            _heartbeatStatus == 'OK' ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusCard(
                            '最後更新',
                            _lastDataTime != null 
                                ? '${_lastDataTime!.hour.toString().padLeft(2, '0')}:${_lastDataTime!.minute.toString().padLeft(2, '0')}:${_lastDataTime!.second.toString().padLeft(2, '0')}'
                                : '無數據',
                            Icons.access_time,
                            _lastDataTime != null ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ADC數據顯示區域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ADC 數據監控',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _clearData,
                              icon: const Icon(Icons.clear),
                              tooltip: '清除數據',
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  // 切換顯示模式
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              tooltip: '刷新數據',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // 當前ADC數據
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isReceiving ? Colors.green[50] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isReceiving ? Colors.green[300]! : Colors.blue[300]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isReceiving ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: _isReceiving ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isReceiving ? '正在接收數據...' : '等待 Arduino 數據',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isReceiving ? Colors.green[800] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (_isReceiving && _latestAdcValue > 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildDataDisplay(
                                  'ADC 數值',
                                  '$_latestAdcValue',
                                  Icons.signal_cellular_alt,
                                  Colors.blue,
                                ),
                                _buildDataDisplay(
                                  '電壓值',
                                  '${_latestVoltage.toStringAsFixed(3)} V',
                                  Icons.electrical_services,
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 數據統計
                    if (_adcHistory.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '數據統計',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem('總數據點', '${_adcHistory.length}'),
                                _buildStatItem('平均ADC', '${(_adcHistory.reduce((a, b) => a + b) / _adcHistory.length).round()}'),
                                _buildStatItem('平均電壓', '${(_voltageHistory.reduce((a, b) => a + b) / _voltageHistory.length).toStringAsFixed(2)}V'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 原始數據顯示區域
            SizedBox(
              height: 300,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '原始數據流',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_messageHistory.length} 條訊息',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _messageHistory.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      '暫無數據',
                                      style: TextStyle(color: Colors.grey, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _messageHistory.length,
                                itemBuilder: (context, index) {
                                  final msg = _messageHistory[index];
                                  final isRecent = index >= _messageHistory.length - 3;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isRecent ? Colors.green[50] : Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isRecent ? Colors.green[200]! : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        msg,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: isRecent ? Colors.green[800] : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 構建狀態卡片
  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // 構建數據顯示
  Widget _buildDataDisplay(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  // 構建統計項目
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}