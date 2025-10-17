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
    // 解析ADC數據
    if (data.startsWith('ADC_DATA:')) {
      String adcData = data.substring(9); // 移除 'ADC_DATA:' 前綴
      List<String> parts = adcData.split(',');
      if (parts.length >= 2) {
        try {
          int adcValue = int.parse(parts[0]);
          double voltage = double.parse(parts[1]);
          print('解析ADC數據: ADC=$adcValue, 電壓=${voltage}V');
        } catch (e) {
          print('解析ADC數據失敗: $e');
        }
      }
    }
    // 解析系統狀態
    else if (data.startsWith('SYSTEM_STATUS:')) {
      print('系統狀態: $data');
    }
    // 解析ADC傳輸狀態
    else if (data.startsWith('ADC_TRANSMISSION:')) {
      print('ADC傳輸狀態: $data');
    }
    // 解析心跳
    else if (data.startsWith('HEARTBEAT:')) {
      print('心跳: $data');
    }
  }

  void _clearData() {
    setState(() {
      _currentData = '';
      _messageHistory.clear();
      _isReceiving = false;
    });
  }

  void _sendMessage(String message) async {
    if (message.isNotEmpty) {
      bool success = await widget.bluetoothManager.sendData(message);
      if (success) {
        setState(() {
          _messageHistory.add('${DateTime.now().toString().substring(11, 19)}: [發送] $message');
        });
      } else {
        _showDialog('發送失敗', '無法發送訊息');
      }
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
                            onPressed: () {
                              // 模擬接收ADC數據用於測試顯示
                              setState(() {
                                _currentData = 'ADC_DATA:512,2.500';
                                _messageHistory.add('${DateTime.now().toString().substring(11, 19)}: ADC_DATA:512,2.500');
                                _isReceiving = true;
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
            
            // 數據顯示區域
            SizedBox(
              height: 400, // 設定固定高度
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '藍牙數據接收',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '已接收 ${_messageHistory.length} 條訊息',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
                                  // 切換顯示模式：完整歷史 vs 最新數據
                                  setState(() {
                                    // 這裡可以添加顯示模式切換邏輯
                                  });
                                },
                                icon: const Icon(Icons.history),
                                tooltip: '查看歷史',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue[200]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue[50],
                        ),
                        child: Column(
                          children: [
                            // 當前數據顯示
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isReceiving ? Colors.green[50] : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isReceiving ? Colors.green[300]! : Colors.blue[300]!,
                                  width: _isReceiving ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _isReceiving ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                        color: _isReceiving ? Colors.green : Colors.grey,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isReceiving ? '正在接收數據...' : '最新接收數據:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: _isReceiving ? Colors.green : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isReceiving ? Colors.green[100] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _isReceiving ? Colors.green[200]! : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      _currentData.isEmpty 
                                          ? '等待 Arduino 數據...' 
                                          : _currentData,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 16,
                                        color: _isReceiving ? Colors.green[800] : Colors.black87,
                                        fontWeight: _isReceiving ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 歷史數據顯示
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '訊息歷史:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: _messageHistory.isEmpty
                                          ? const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.history,
                                                    size: 48,
                                                    color: Colors.grey,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    '暫無歷史訊息',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontStyle: FontStyle.italic,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    '連接 Arduino 後將顯示接收到的數據',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: _messageHistory.length,
                                              itemBuilder: (context, index) {
                                                final msg = _messageHistory[index];
                                                final isRecent = index >= _messageHistory.length - 5;
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, 
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isRecent ? Colors.green[50] : Colors.grey[100],
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: isRecent ? Colors.green[200]! : Colors.grey[300]!,
                                                        width: isRecent ? 1 : 0,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        if (isRecent) ...[
                                                          const Icon(
                                                            Icons.fiber_new,
                                                            size: 16,
                                                            color: Colors.green,
                                                          ),
                                                          const SizedBox(width: 4),
                                                        ],
                                                        Expanded(
                                                          child: Text(
                                                            msg,
                                                            style: TextStyle(
                                                              fontFamily: 'monospace',
                                                              fontSize: 12,
                                                              color: isRecent ? Colors.green[800] : Colors.black87,
                                                              fontWeight: isRecent ? FontWeight.w500 : FontWeight.normal,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }
}