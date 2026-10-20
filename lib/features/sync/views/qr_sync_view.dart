import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/lan_sync_server.dart';
import '../../../core/utils/local_backup.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/task_provider.dart';

/// 局域网面对面同步（换机助手式）+ 本地文件备份。
///
/// 发送方开启本地 HTTP 服务器，二维码只承载「http://IP:端口/token」握手信息，
/// 另一设备扫描后通过局域网 HTTP 拉取全量快照（含图片）导入。
/// 需两台设备连接同一 WiFi（或一台开热点）。
class QrSyncView extends ConsumerStatefulWidget {
  const QrSyncView({super.key});

  @override
  ConsumerState<QrSyncView> createState() => _QrSyncViewState();
}

class _QrSyncViewState extends ConsumerState<QrSyncView> {
  bool _showScanner = false;

  // 发送方状态
  bool _isServing = false;
  String? _handshakeUrl;
  String? _localIp;
  LanServerInfo? _serverInfo;

  /// 刷新所有业务 Provider，让内存态与恢复后的本地数据对齐。
  void _invalidateAllProviders() {
    ref.invalidate(familyProfileProvider);
    ref.invalidate(taskProvider);
    ref.invalidate(rewardProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(exchangeProvider);
  }

  /// 发送方：开启局域网服务器并生成握手二维码。
  Future<void> _startServing() async {
    if (_isServing) return;
    try {
      final storage = ref.read(storageProvider);
      final info = await LanSyncServer.start(storage);
      if (!mounted) {
        await info.server.close(force: true);
        return;
      }
      setState(() {
        _isServing = true;
        _serverInfo = info;
        _localIp = info.ip;
        _handshakeUrl = LanSyncServer.handshakeUrl(info);
      });
    } catch (e) {
      if (!mounted) return;
      _showLanHint(e.toString());
    }
  }

  /// 停止服务器（离开页面 / 手动停止）。
  void _stopServing() {
    _serverInfo?.server.close(force: true);
    _serverInfo = null;
    setState(() {
      _isServing = false;
      _handshakeUrl = null;
      _localIp = null;
    });
  }

  @override
  void dispose() {
    _serverInfo?.server.close(force: true);
    super.dispose();
  }

  /// 提示需连接同一 WiFi / 开启热点。
  void _showLanHint([String? msg]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('无法建立局域网连接'),
        content: Text(
          msg ??
              '未检测到局域网连接。\n\n请确保两台设备连接了同一个 WiFi，'
                  '或其中一台开启手机热点让另一台连接。',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 接收方：扫描到二维码后解析握手信息并拉取数据。
  Future<void> _onDetect(String code) async {
    if (!code.startsWith('http://')) {
      _showSnack('无法识别的二维码，请扫描另一台设备生成的同步码', red: true);
      return;
    }
    // 解析 http://ip:port/sync/token
    final uri = Uri.tryParse(code);
    if (uri == null ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments[0] != 'sync') {
      _showSnack('二维码格式不正确', red: true);
      return;
    }
    final ip = uri.host;
    final port = uri.hasPort ? uri.port : 80;
    final token = uri.pathSegments[1];

    setState(() => _showScanner = false);

    // 显示拉取进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final storage = ref.read(storageProvider);
      await LanSyncServer.fetchAndRestore(storage, ip, port, token);
      _invalidateAllProviders();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack('数据导入成功！', red: false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack('导入失败：$e', red: true);
      }
    }
  }

  void _showSnack(String msg, {required bool red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: red ? Colors.red : Colors.green,
      ),
    );
  }

  /// 导出全量数据快照到本地 JSON 文件。
  Future<void> _exportToFile() async {
    try {
      final path = await LocalBackup.exportToFile(ref.read(storageProvider));
      if (path == null) return;
      if (!mounted) return;
      _showSnack('导出成功：$path', red: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('导出失败：$e', red: true);
    }
  }

  /// 从本地 JSON 文件导入并恢复全量数据。
  Future<void> _importFromFile() async {
    try {
      final ok = await LocalBackup.importFromFile(ref.read(storageProvider));
      if (!ok) return;
      _invalidateAllProviders();
      if (!mounted) return;
      _showSnack('数据导入成功！', red: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('导入失败：$e', red: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('面对面同步', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
        actions: [
          TextButton(
            onPressed: () {
              _stopServing();
              setState(() {
                _showScanner = !_showScanner;
              });
            },
            child: Text(
              _showScanner ? '发起传输' : '扫描接收',
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _showScanner ? _buildScanner() : _buildSender(),
      ),
    );
  }

  /// 发送方界面：发起局域网传输 + 本地文件备份。
  Widget _buildSender() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '面对面传输（局域网）',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          Text(
            '两台设备连接同一个 WiFi（或一台开热点），本机发起传输，另一台扫描二维码即可接收全部数据（含图片）。',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
          SizedBox(height: 32.h),

          // 二维码 / 提示区
          if (_isServing && _handshakeUrl != null) ...[
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _handshakeUrl!,
                    version: QrVersions.auto,
                    size: 280.w,
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '等待另一台设备扫描…',
                    style: TextStyle(fontSize: 14.sp, color: Colors.blue),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '本机地址：$_localIp',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('停止传输'),
              onPressed: _stopServing,
            ),
          ] else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('开始面对面传输'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              onPressed: _startServing,
            ),
          ],

          SizedBox(height: 32.h),
          const Divider(),
          SizedBox(height: 16.h),
          Text(
            '本地文件备份',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('导出到本地文件'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            onPressed: _exportToFile,
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('从本地文件导入'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            onPressed: _importFromFile,
          ),
          SizedBox(height: 8.h),
          Text(
            '导出会生成 JSON 备份文件；导入会覆盖当前全部家庭数据。',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 接收方界面：扫描二维码。
  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _onDetect(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            '扫描另一台设备生成的同步码（需连接同一 WiFi）',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
