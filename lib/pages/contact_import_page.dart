import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/pages/membership_sheet.dart';
import 'package:time_calendar/services/contact_import_service.dart';
import 'package:time_calendar/services/membership_service.dart';

String _contactInitialLetter(String displayName) {
  if (displayName.isEmpty) return '?';
  final it = displayName.runes.iterator;
  if (!it.moveNext()) return '?';
  return String.fromCharCode(it.current).toUpperCase();
}

/// 从通讯录批量导入生日事件（高级版）。
class ContactImportPage extends StatefulWidget {
  const ContactImportPage({
    super.key,
    required this.existingEvents,
  });

  final List<ListEvent> existingEvents;

  @override
  State<ContactImportPage> createState() => _ContactImportPageState();
}

class _ContactImportPageState extends State<ContactImportPage> {
  List<ContactBirthdayCandidate> _all = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final tier = await MembershipService.currentTier();
    if (!mounted) return;
    if (!MembershipService.benefits(tier).batchImportContacts) {
      setState(() {
        _loading = false;
        _error = 'premium_required';
      });
      return;
    }

    final contactsOk = await _ensureContactsPermission();
    if (!contactsOk || !mounted) {
      setState(() {
        _loading = false;
        _error = 'permission';
      });
      return;
    }

    try {
      final raw = await ContactImportService.loadBirthdayCandidates();
      final filtered = ContactImportService.filterAlreadyImported(
        existingEvents: widget.existingEvents,
        candidates: raw,
      );
      final skipped = raw.length - filtered.length;
      if (!mounted) return;
      setState(() {
        _all = filtered;
        _selected
          ..clear()
          ..addAll(filtered.map((e) => e.stableKey));
        _loading = false;
      });
      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已跳过 $skipped 个与清单重复的生日'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'load';
      });
    }
  }

  Future<bool> _ensureContactsPermission() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    if (status.isGranted || status.isLimited) {
      return ContactImportService.ensureFlutterContactsReadPermission();
    }
    if (!mounted) return false;

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要通讯录权限'),
          content: const Text(
            '需要通讯录权限才能导入生日，您可以在系统设置中开启。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('打开设置'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('需要通讯录权限才能导入生日，您可以在系统设置中开启'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selected.length == _all.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_all.map((e) => e.stableKey));
      }
    });
  }

  Future<void> _confirmImport() async {
    final chosen =
        _all.where((c) => _selected.contains(c.stableKey)).toList();
    if (chosen.isEmpty) return;
    final events =
        chosen.map(ContactImportService.toBirthdayListEvent).toList();
    if (!mounted) return;
    Navigator.of(context).pop(events);
  }

  String _subtitleDate(ContactBirthdayCandidate c) {
    final mm = c.month.toString().padLeft(2, '0');
    final dd = c.day.toString().padLeft(2, '0');
    if (c.unknownYear) return '$mm-$dd · 未知年份 · 每年';
    return '${c.anchorYear}-$mm-$dd · 每年';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == 'premium_required') {
      return Scaffold(
        appBar: AppBar(title: const Text('导入通讯录生日')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '批量导入通讯录生日为高级版功能',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await showMembershipSheet(context);
                    if (!mounted) return;
                    await _bootstrap();
                  },
                  child: const Text('升级会员'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('导入通讯录生日'),
        actions: [
          if (!_loading && _error == null && _all.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selected.length == _all.length ? '取消全选' : '全选',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A73E8),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error == 'permission' || _error == 'load'
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error == 'load'
                          ? '读取通讯录失败，请稍后重试'
                          : '未授予通讯录权限',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _all.isEmpty
                  ? const Center(child: Text('未找到含生日的联系人'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: _all.length,
                      itemBuilder: (context, i) {
                        final c = _all[i];
                        final on = _selected.contains(c.stableKey);
                        final initials = _contactInitialLetter(c.displayName);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.white,
                            elevation: 0,
                            shadowColor: const Color(0x08000000),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (on) {
                                    _selected.remove(c.stableKey);
                                  } else {
                                    _selected.add(c.stableKey);
                                  }
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x08000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          const Color(0xFFDBEAFE),
                                      backgroundImage:
                                          c.photoBytes != null &&
                                                  c.photoBytes!.isNotEmpty
                                              ? MemoryImage(c.photoBytes!)
                                              : null,
                                      child:
                                          c.photoBytes != null &&
                                                  c.photoBytes!.isNotEmpty
                                              ? null
                                              : Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1E40AF),
                                                  ),
                                                ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.displayName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _subtitleDate(c),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: on,
                                      fillColor: WidgetStateProperty.resolveWith(
                                        (states) {
                                          if (states
                                              .contains(WidgetState.selected)) {
                                            return const Color(0xFF1A73E8);
                                          }
                                          return null;
                                        },
                                      ),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selected.add(c.stableKey);
                                          } else {
                                            _selected.remove(c.stableKey);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: (!_loading &&
              _error == null &&
              _all.isNotEmpty &&
              _selected.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _confirmImport,
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1A73E8),
                              Color(0xFF60A5FA),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '导入 ${_selected.length} 个生日',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
