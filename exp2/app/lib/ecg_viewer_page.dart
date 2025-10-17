import 'package:flutter/material.dart';
import 'dart:async';
import 'bluetooth_manager.dart';

class ECGViewerPage extends StatefulWidget {
  final BluetoothManager bluetoothManager;
  
  const ECGViewerPage({
    super.key,
    required this.bluetoothManager,
  });

  @override
  State<ECGViewerPage> createState() => _ECGViewerPageState();
}

class _ECGViewerPageState extends State<ECGViewerPage> {
  final List<double> _ecgData = [];
  final int _maxDataPoints = 200;
  StreamSubscription<String>? _dataSubscription;
  bool _isReceiving = false;
  String _currentStatus = '等待連接...';

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    print('開始監聽ECG數據流...');
    _dataSubscription = widget.bluetoothManager.dataStream.listen(
      (data) {
        print('ECG頁面收到數據: $data');
        setState(() {
          _processECGData(data);
          _isReceiving = true;
          _currentStatus = '正在接收ECG數據...';
        });
      },
      onError: (error) {
        print('ECG數據流錯誤: $error');
        setState(() {
          _isReceiving = false;
          _currentStatus = '數據接收錯誤';
        });
      },
      onDone: () {
        print('ECG數據流已關閉');
        setState(() {
          _isReceiving = false;
          _currentStatus = '數據流已關閉';
        });
      },
    );
  }

  void _processECGData(String data) {
    // 解析ECG數據
    if (data.startsWith('ADC_DATA:')) {
      String adcData = data.substring(9); // 移除 'ADC_DATA:' 前綴
      List<String> parts = adcData.split(',');
      if (parts.length >= 2) {
        try {
          int adcValue = int.parse(parts[0]);
          double voltage = double.parse(parts[1]);
          
          // 將ADC值轉換為ECG數據點
          double ecgValue = (adcValue / 1024.0) * 3.3; // 假設3.3V參考電壓
          
          _ecgData.add(ecgValue);
          
          // 限制數據點數量
          if (_ecgData.length > _maxDataPoints) {
            _ecgData.removeAt(0);
          }
          
          print('ECG數據點: $ecgValue V (ADC: $adcValue)');
        } catch (e) {
          print('解析ECG數據失敗: $e');
        }
      }
    }
  }

  void _clearData() {
    setState(() {
      _ecgData.clear();
      _isReceiving = false;
      _currentStatus = '數據已清除';
    });
  }

  void _startECG() async {
    bool success = await widget.bluetoothManager.sendData('START_ADC');
    if (success) {
      setState(() {
        _currentStatus = '已發送開始ECG指令';
      });
    }
  }

  void _stopECG() async {
    bool success = await widget.bluetoothManager.sendData('STOP_ADC');
    if (success) {
      setState(() {
        _currentStatus = '已發送停止ECG指令';
      });
    }
  }

  Widget _buildECGChart() {
    if (_ecgData.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                '等待ECG數據...',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '請確保Arduino已連接並發送ADC數據',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue[50],
      ),
      child: CustomPaint(
        painter: ECGChartPainter(_ecgData),
        size: const Size(double.infinity, double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG 數據顯示'),
        backgroundColor: Colors.red,
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
                          widget.bluetoothManager.isConnected 
                              ? Icons.bluetooth_connected 
                              : Icons.bluetooth_disabled,
                          color: widget.bluetoothManager.isConnected 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.bluetoothManager.isConnected 
                                ? '已連接到: ${widget.bluetoothManager.deviceName}'
                                : '未連接藍牙設備',
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isReceiving 
                              ? Icons.radio_button_checked 
                              : Icons.radio_button_unchecked,
                          color: _isReceiving ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentStatus,
                          style: TextStyle(
                            color: _isReceiving ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_ecgData.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '已接收 ${_ecgData.length} 個數據點',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 控制按鈕
            if (widget.bluetoothManager.isConnected) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ECG 控制',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _startECG,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('開始ECG'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _stopECG,
                              icon: const Icon(Icons.stop),
                              label: const Text('停止ECG'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // ECG圖表
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ECG 波形圖',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '數據點: ${_ecgData.length} / $_maxDataPoints',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    _buildECGChart(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 數據統計
            if (_ecgData.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '數據統計',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildDataStats(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataStats() {
    if (_ecgData.isEmpty) return const SizedBox.shrink();
    
    double minValue = _ecgData.reduce((a, b) => a < b ? a : b);
    double maxValue = _ecgData.reduce((a, b) => a > b ? a : b);
    double avgValue = _ecgData.reduce((a, b) => a + b) / _ecgData.length;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最小值:'),
            Text('${minValue.toStringAsFixed(3)} V'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最大值:'),
            Text('${maxValue.toStringAsFixed(3)} V'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('平均值:'),
            Text('${avgValue.toStringAsFixed(3)} V'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('數據點數:'),
            Text('${_ecgData.length}'),
          ],
        ),
      ],
    );
  }
}

class ECGChartPainter extends CustomPainter {
  final List<double> data;
  
  ECGChartPainter(this.data);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    // 計算數據範圍
    double minValue = data.reduce((a, b) => a < b ? a : b);
    double maxValue = data.reduce((a, b) => a > b ? a : b);
    double range = maxValue - minValue;
    
    if (range == 0) range = 1; // 避免除零
    
    // 繪製ECG波形
    for (int i = 0; i < data.length; i++) {
      double x = (i / (data.length - 1)) * size.width;
      double y = size.height - ((data[i] - minValue) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // 繪製網格線
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    
    // 水平網格線
    for (int i = 0; i <= 5; i++) {
      double y = (i / 5) * size.height;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 垂直網格線
    for (int i = 0; i <= 10; i++) {
      double x = (i / 10) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}