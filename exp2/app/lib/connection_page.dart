import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';

class ConnectionPage extends StatefulWidget {
  final BluetoothManager bluetoothManager;
  final VoidCallback onConnected;

  const ConnectionPage({
    super.key,
    required this.bluetoothManager,
    required this.onConnected,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String _statusMessage = '準備掃描藍牙設備';
  BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _checkBluetoothStatus();
  }

  Future<void> _checkBluetoothStatus() async {
    setState(() {
      _statusMessage = '檢查藍牙狀態...';
    });

    // 請求權限
    bool hasPermission = await widget.bluetoothManager.requestPermissions();
    if (!hasPermission) {
      setState(() {
        _statusMessage = '藍牙權限被拒絕，請在設定中允許';
      });
      return;
    }

    // 檢查藍牙是否開啟
    bool isEnabled = await widget.bluetoothManager.isBluetoothEnabled();
    if (!isEnabled) {
      setState(() {
        _statusMessage = '藍牙未開啟，請開啟藍牙後重試';
      });
    } else {
      setState(() {
        _statusMessage = '藍牙已開啟，準備掃描設備';
      });
    }
  }

  Future<void> _scanForDevices() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = '正在掃描藍牙設備...';
    });

    try {
      // 掃描所有藍牙設備，不過濾名稱
      List<BluetoothDevice> devices = await widget.bluetoothManager.scanForDevices(
        deviceNameFilter: null, // 移除名稱過濾
      );
      setState(() {
        _devices = devices;
        _isScanning = false;
        _statusMessage = '掃描完成，找到 ${devices.length} 個藍牙設備';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = '掃描失敗: $e';
      });
    }
  }

  Future<void> _scanForHM10Devices() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = '正在掃描 HM-10 BLE 設備...';
    });

    try {
      // 專門掃描 HM-10 BLE 設備
      List<BluetoothDevice> devices = await widget.bluetoothManager.scanForHM10Devices();
      setState(() {
        _devices = devices;
        _isScanning = false;
        _statusMessage = 'BLE 掃描完成，找到 ${devices.length} 個設備';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'BLE 掃描失敗: $e';
      });
    }
  }

  Future<void> _getPairedDevices() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = '正在查找已配對的藍牙設備...';
    });

    try {
      // 獲取所有已配對的設備
      List<BluetoothDevice> devices = await widget.bluetoothManager.getPairedDevices(
        deviceNameFilter: null, // 移除名稱過濾
      );
      
      print('獲取到已配對設備數量: ${devices.length}');
      for (var device in devices) {
        print('已配對設備: ${device.platformName} (${device.remoteId})');
      }
      
      setState(() {
        _devices = devices;
        _isScanning = false;
        _statusMessage = '找到 ${devices.length} 個已配對的藍牙設備';
      });
    } catch (e) {
      print('獲取已配對設備錯誤: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = '獲取已配對設備失敗: $e';
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _selectedDevice = device;
      _statusMessage = '正在連接到 ${device.platformName}...';
    });

    try {
      bool success = await widget.bluetoothManager.connectToDevice(device);
      if (success) {
        setState(() {
          _statusMessage = '已成功連接到 ${device.platformName}';
        });
        // 延遲一下再切換頁面，讓用戶看到成功訊息
        await Future.delayed(const Duration(seconds: 1));
        widget.onConnected();
      } else {
        setState(() {
          _statusMessage = '連接失敗，請重試';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '連接時發生錯誤: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
        _selectedDevice = null;
      });
    }
  }

  Future<void> _disconnect() async {
    await widget.bluetoothManager.disconnect();
    setState(() {
      _statusMessage = '已斷開連接';
    });
  }

  Widget _buildDeviceList() {
    print('構建設備列表，設備數量: ${_devices.length}');
    
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '未發現藍牙設備',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '請點擊上方按鈕掃描設備',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isSelected = _selectedDevice?.remoteId == device.remoteId;
        final isConnecting = _isConnecting && isSelected;
        
        print('顯示設備: ${device.platformName} (${device.remoteId})');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isConnecting ? Colors.orange : Colors.blue,
              child: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.bluetooth, color: Colors.white),
            ),
            title: Text(
              device.platformName.isNotEmpty ? device.platformName : '未知設備',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${device.remoteId}'),
                Text('信號強度: 未知'),
              ],
            ),
            trailing: widget.bluetoothManager.isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : ElevatedButton(
                    onPressed: isConnecting
                        ? null
                        : () => _connectToDevice(device),
                    child: Text(isConnecting ? '連接中...' : '連接'),
                  ),
            onTap: isConnecting ? null : () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('藍牙連接'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (widget.bluetoothManager.isConnected)
            IconButton(
              onPressed: _disconnect,
              icon: const Icon(Icons.bluetooth_disabled),
              tooltip: '斷開連接',
            ),
        ],
      ),
      body: Column(
        children: [
          // 狀態顯示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: widget.bluetoothManager.isConnected ? Colors.green[50] : Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      widget.bluetoothManager.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: widget.bluetoothManager.isConnected ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.bluetoothManager.isConnected
                            ? '已連接到: ${widget.bluetoothManager.deviceName}'
                            : _statusMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.bluetoothManager.isConnected) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '點擊下方按鈕開始接收數據',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 控制按鈕
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanForDevices,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(_isScanning ? '掃描中...' : '掃描新設備'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _getPairedDevices,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bluetooth_connected),
                        label: Text(_isScanning ? '查找中...' : '已配對設備'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // HM-10 專用掃描按鈕
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanForHM10Devices,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bluetooth_searching),
                        label: Text(_isScanning ? 'BLE 掃描中...' : '掃描 HM-10'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.bluetoothManager.isConnected
                            ? () => widget.onConnected()
                            : null,
                        icon: const Icon(Icons.data_usage),
                        label: const Text('查看數據'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 設備列表
          Expanded(
            child: _buildDeviceList(),
          ),
        ],
      ),
    );
  }
}