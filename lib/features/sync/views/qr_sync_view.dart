import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/local_backup.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/task_provider.dart';

/// 二维码本地同步 + 本地文件备份。
///
/// 家长端将全量数据打包为 JSON 快照生成二维码，
/// 另一设备扫描二维码解析后导入，实现免流面对面同步；
/// 同时支持把快照导出为本地 JSON 文件、或从本地 JSON 文件导入恢复。
class QrSyncView extends ConsumerStatefulWidget {
  const QrSyncView({super.key});

  @override
  ConsumerState<QrSyncView> createState() => _QrSyncViewState();
}

class _QrSyncViewState extends ConsumerState<QrSyncView> {
  bool _showScanner = false;
  String? _qrData;

  /// 构建当前全量数据快照的二维码字符串。
  String _buildSnapshotJson() {
    final storage = ref.read(storageProvider);
    return jsonEncode(storage.buildSnapshot());
  }

  /// 刷新所有业务 Provider，让内存态与恢复后的本地数据对齐。
  void _invalidateAllProviders() {
    ref.invalidate(familyProfileProvider);
    ref.invalidate(taskProvider);
    ref.invalidate(rewardProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(exchangeProvider);
  }

  /// 扫描到二维码后解析并导入。
  Future<void> _onDetect(String code) async {
    if (code == _qrData && code.isNotEmpty) return; // 防止重复触发
    setState(() => _qrData = code);

    try {
      final snapshot = jsonDecode(code) as Map<String, dynamic>;
      final storage = ref.read(storageProvider);
      await storage.restoreSnapshot(snapshot);

      _invalidateAllProviders();

      if (mounted) {
        setState(() => _showScanner = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据导入成功！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('二维码解析失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 导出全量数据快照到本地 JSON 文件。
  Future<void> _exportToFile() async {
    try {
      final path = await LocalBackup.exportToFile(ref.read(storageProvider));
      if (path == null) return; // 用户取消保存
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出成功：$path'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 从本地 JSON 文件导入并恢复全量数据。
  Future<void> _importFromFile() async {
    try {
      final ok = await LocalBackup.importFromFile(ref.read(storageProvider));
      if (!ok) return; // 用户取消选择

      _invalidateAllProviders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据导入成功！'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('二维码同步', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _showScanner = !_showScanner;
              _qrData = null;
            }),
            child: Text(
              _showScanner ? '生成二维码' : '扫描二维码',
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _showScanner ? _buildScanner() : _buildGenerator(),
      ),
    );
  }

  Widget _buildGenerator() {
    final qrData = _buildSnapshotJson();
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          Text(
            '生成数据快照二维码',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          Text(
            '在另一台设备上扫描此二维码，即可导入全部家庭数据（儿童档案、任务、奖励、打卡记录）。',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 280.w,
              backgroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            '数据快照大小：${qrData.length} 字符',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
          SizedBox(height: 32.h),
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
            '将另一台设备生成的二维码对准扫描框',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
