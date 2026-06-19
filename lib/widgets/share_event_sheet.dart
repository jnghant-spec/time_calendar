import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/share_contact.dart';

/// 事件分享底部分享 Sheet（清单页与添加事件页共用）。
class _ShareResultEntry {
  const _ShareResultEntry({required this.phone, required this.registered});
  final String phone;
  final bool registered;
}

class ShareEventSheet extends StatefulWidget {
  const ShareEventSheet({super.key, required this.parentContext});

  final BuildContext parentContext;

  @override
  State<ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends State<ShareEventSheet> {
  static const _kThemeBlue = Color(0xFF1A73E8);
  static const _kBorderColor = Color(0xFFE2E8F0);
  static const _kTitleColor = Color(0xFF0F172A);
  static const _kMutedGrey = Color(0xFF94A3B8);
  static const _kPrefsContacts = 'tc.share_management.contacts_v1';
  static const _kMaxShare = 5;
  static const _kMaxShareSnack =
      '本 app 现阶段仅支持同一事件单次分享给 5 人，如需分享超过 5 人，请再次点击分享';
  static const _kAvatarColors = <int>[
    0xFF8B5CF6,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF10B981,
    0xFF06B6D4,
    0xFFEC4899,
    0xFF6366F1,
    0xFF14B8A6,
  ];
  static final _phoneMobile = RegExp(r'^1[3-9]\d{9}$');

  final List<ShareContact> _selectedContacts = [];
  final List<ShareContact> _appContacts = [];
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _nicknameFocusNode = FocusNode();
  final PageController _gridPageController = PageController();
  int _gridPageIndex = 0;

  bool _showNicknameInput = false;
  String _currentPhoneForNickname = '';

  bool _resultsPhase = false;
  List<_ShareResultEntry> _results = [];
  int _registeredCount = 0;
  int _smsCount = 0;

  bool get _canConfirm => _selectedContacts.isNotEmpty && !_resultsPhase;

  bool get _phoneValid => _phoneMobile.hasMatch(_phoneController.text.trim());

  bool get _isFull => _selectedContacts.length >= _kMaxShare;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _loadAppContacts();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    _phoneFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _gridPageController.dispose();
    super.dispose();
  }

  void _showMaxShareSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_kMaxShareSnack)),
    );
  }

  Future<void> _loadAppContacts() async {
    final contacts = <ShareContact>[];
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsContacts);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            contacts.add(ShareContact.fromJson(e));
          } else if (e is Map) {
            contacts.add(
              ShareContact.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _appContacts
          ..clear()
          ..addAll(contacts);
      });
    }
  }

  Future<void> _persistContact(ShareContact contact) async {
    final updated = [
      contact,
      ..._appContacts.where((c) => c.phone != contact.phone),
    ];
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kPrefsContacts,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
    if (mounted) {
      setState(() {
        _appContacts
          ..clear()
          ..addAll(updated);
      });
    }
  }

  bool _isSelected(ShareContact contact) =>
      _selectedContacts.any((c) => c.phone == contact.phone);

  bool _isAtMaxShare() => _selectedContacts.length >= _kMaxShare;

  bool _tryAddSelected(ShareContact contact) {
    if (_isSelected(contact)) return true;
    if (_isAtMaxShare()) {
      _showMaxShareSnackBar();
      return false;
    }
    setState(() {
      _selectedContacts.add(contact);
      if (_selectedContacts.length >= _kMaxShare) {
        _showNicknameInput = false;
      }
    });
    return true;
  }

  void _removeSelected(ShareContact contact) {
    setState(() {
      _selectedContacts.removeWhere((c) => c.phone == contact.phone);
    });
  }

  void _toggleContact(ShareContact contact) {
    if (_isSelected(contact)) {
      _removeSelected(contact);
      return;
    }
    _tryAddSelected(contact);
  }

  Color _avatarColor(int index) => Color(_kAvatarColors[index % _kAvatarColors.length]);

  int _colorIndexForContact(ShareContact contact) {
    final phone = contact.phone;
    final appIndex = _appContacts.indexWhere((c) => c.phone == phone);
    if (appIndex >= 0) return appIndex;
    if (phone.isEmpty) return 0;
    var hash = 0;
    for (var i = 0; i < phone.length; i++) {
      hash = (hash + phone.codeUnitAt(i)) % _kAvatarColors.length;
    }
    return hash;
  }

  static const double _kAvatarInnerSize = 56;
  static const double _kAvatarOuterSelectedSize = 64;
  static const double _kSelectedAreaAvatarSize = 48;
  static const double _kSelectedAreaItemWidth = 60;
  static const double _kSelectedAreaItemSpacing = 8;
  static const double _kSelectedAreaHeight = 56;

  String _avatarDisplayText(ShareContact contact) {
    final name = contact.name.trim();
    if (name.isNotEmpty) {
      if (name.length >= 2) return name.substring(0, 2);
      return name;
    }
    final phone = contact.phone.trim();
    if (phone.length >= 4) return phone.substring(phone.length - 4);
    if (phone.isNotEmpty) return phone;
    return '?';
  }

  bool _avatarTextIsPhoneDigits(ShareContact contact, String text) {
    return contact.name.trim().isEmpty && RegExp(r'^\d+$').hasMatch(text);
  }

  Widget _buildColoredAvatar({
    required Color color,
    required ShareContact contact,
  }) {
    final text = _avatarDisplayText(contact);
    final fontSize = _avatarTextIsPhoneDigits(contact, text) ? 14.0 : 16.0;
    return Container(
      width: _kAvatarInnerSize,
      height: _kAvatarInnerSize,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAreaAvatar({
    required Color color,
    required ShareContact contact,
  }) {
    final name = contact.name.trim();
    final phone = contact.phone.trim();
    final isDirectShare = RegExp(r'^\d{4}$').hasMatch(name);
    final String text;
    if (isDirectShare) {
      text = name;
    } else if (name.isNotEmpty) {
      text = name.length >= 2 ? name.substring(0, 2) : name;
    } else {
      text = phone.length >= 4
          ? phone.substring(phone.length - 4)
          : (phone.isNotEmpty ? phone : '?');
    }
    final fontSize = isDirectShare ? 11.0 : 14.0;
    return Container(
      width: _kSelectedAreaAvatarSize,
      height: _kSelectedAreaAvatarSize,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildGridAvatar({
    required Color color,
    required ShareContact contact,
    required bool selected,
  }) {
    final inner = _buildColoredAvatar(color: color, contact: contact);
    if (!selected) {
      return SizedBox(
        width: _kAvatarOuterSelectedSize,
        height: _kAvatarOuterSelectedSize,
        child: Center(child: inner),
      );
    }
    return SizedBox(
      width: _kAvatarOuterSelectedSize,
      height: _kAvatarOuterSelectedSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: _kAvatarOuterSelectedSize,
            height: _kAvatarOuterSelectedSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _kThemeBlue, width: 2),
            ),
            child: inner,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _kThemeBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _directShare() {
    if (_showNicknameInput) {
      setState(() => _showNicknameInput = false);
    }
    if (!_phoneValid) return;
    if (_isAtMaxShare()) {
      _showMaxShareSnackBar();
      return;
    }
    final phone = _phoneController.text.trim();
    final suffix = phone.substring(phone.length - 4);
    final contact = ShareContact(name: suffix, phone: phone);
    if (_tryAddSelected(contact)) {
      _phoneController.clear();
    }
  }

  void _addAsAppContactAndShare() {
    if (!_phoneValid) return;
    final phone = _phoneController.text.trim();
    setState(() {
      _showNicknameInput = true;
      _currentPhoneForNickname = phone;
      _nicknameController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nicknameFocusNode.canRequestFocus) {
        _nicknameFocusNode.requestFocus();
      }
    });
  }

  void _cancelNicknameInput() {
    setState(() => _showNicknameInput = false);
  }

  Future<void> _confirmNicknameInput() async {
    final name = _nicknameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入称呼')),
      );
      return;
    }
    if (_isAtMaxShare()) {
      _showMaxShareSnackBar();
      return;
    }
    final contact = ShareContact(name: name, phone: _currentPhoneForNickname);
    await _persistContact(contact);
    if (!mounted) return;
    if (_tryAddSelected(contact)) {
      setState(() {
        _showNicknameInput = false;
        _phoneController.clear();
        _nicknameController.clear();
      });
    }
  }

  Future<void> _submitShare() async {
    if (!_canConfirm) return;
    final phones = _selectedContacts.map((c) => c.phone).toList();

    final results = <_ShareResultEntry>[];
    var reg = 0;
    var sms = 0;
    for (final p in phones) {
      final registered = _appContacts.any((c) => c.phone == p);
      results.add(_ShareResultEntry(phone: p, registered: registered));
      if (registered) {
        reg++;
      } else {
        sms++;
      }
    }

    setState(() {
      _results = results;
      _registeredCount = reg;
      _smsCount = sms;
      _resultsPhase = true;
    });
  }

  void _finishSheet() {
    final n = _results.length;
    final m = _registeredCount;
    final k = _smsCount;
    final String message;
    if (k == 0) {
      message = '已分享给 $n 人，等待确认';
    } else if (m == 0) {
      message = '已分享给 $n 人，短信发送中（免费）';
    } else {
      message = '已分享 $n 人：$m 人 App 内，$k 人短信（免费）';
    }
    Navigator.of(context).pop();
    if (!widget.parentContext.mounted) return;
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildSelectedContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _kSelectedAreaHeight,
          child: _selectedContacts.isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '请选择联系人',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_selectedContacts.length, (index) {
                      final contact = _selectedContacts[index];
                      final item = SizedBox(
                        width: _kSelectedAreaItemWidth,
                        height: _kSelectedAreaHeight,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _removeSelected(contact),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: _kSelectedAreaAvatarSize,
                              height: _kSelectedAreaAvatarSize,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  _buildSelectedAreaAvatar(
                                    color: _avatarColor(
                                      _colorIndexForContact(contact),
                                    ),
                                    contact: contact,
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _kBorderColor,
                                          width: 0.7,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: _kTitleColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      if (index == 0) return item;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: _kSelectedAreaItemSpacing),
                          item,
                        ],
                      );
                    }),
                  ),
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildGridCell(ShareContact contact, int colorIndex) {
    final selected = _isSelected(contact);
    final disabled = _isFull && !selected;
    final nameColor = selected
        ? _kThemeBlue
        : (disabled ? Colors.grey.shade400 : _kTitleColor);

    return GestureDetector(
      onTap: disabled ? null : () => _toggleContact(contact),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGridAvatar(
              color: _avatarColor(colorIndex),
              contact: contact,
              selected: selected,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 22,
              width: double.infinity,
              child: Text(
                contact.name.trim().isNotEmpty ? contact.name : contact.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.0,
                  color: nameColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactGridPage(
    List<ShareContact> pageItems,
    int startIndex, {
    bool shrinkWrap = true,
  }) {
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 0.88,
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 12.0,
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(pageItems.length, (i) {
        return _buildGridCell(pageItems[i], startIndex + i);
      }),
    );
  }

  Widget _buildContactGrid() {
    if (_appContacts.isEmpty) return const SizedBox.shrink();

    if (_appContacts.length <= 8) {
      return _buildContactGridPage(_appContacts, 0);
    }

    final pageCount = (_appContacts.length / 8).ceil();
    return SizedBox(
      height: 210,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _gridPageController,
              onPageChanged: (index) => setState(() => _gridPageIndex = index),
              itemCount: pageCount,
              itemBuilder: (context, pageIndex) {
                final start = pageIndex * 8;
                final pageItems = _appContacts.skip(start).take(8).toList();
                return _buildContactGridPage(
                  pageItems,
                  start,
                  shrinkWrap: false,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (index) {
                  final active = index == _gridPageIndex;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? _kThemeBlue : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    final borderColor = _isFull ? Colors.grey.shade300 : _kBorderColor;
    final hintColor = _isFull ? Colors.grey.shade400 : const Color(0xFFCBD5E1);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 0.7),
        color: _isFull ? Colors.grey.shade50 : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 72,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Text(
              '+86',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _isFull ? Colors.grey.shade400 : _kMutedGrey,
              ),
            ),
          ),
          Container(width: 1, height: 48, color: const Color(0xFFE5E7EB)),
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              enabled: !_isFull,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '输入手机号',
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameInput() {
    final hintColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _kBorderColor, width: 0.7),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          '为 +86 $_currentPhoneForNickname 设置称呼',
          style: TextStyle(fontSize: 14, color: hintColor),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _nicknameController,
                focusNode: _nicknameFocusNode,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: '称呼',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _kThemeBlue, width: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _cancelNicknameInput,
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _confirmNicknameInput,
              style: FilledButton.styleFrom(
                backgroundColor: _kThemeBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutlineAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final disabledColor = cs.onSurface.withValues(alpha: 0.3);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kThemeBlue,
        disabledForegroundColor: disabledColor,
        side: BorderSide(
          color: onPressed != null ? _kThemeBlue : disabledColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(_ShareResultEntry r) {
    final contact = _appContacts.firstWhere(
      (c) => c.phone == r.phone,
      orElse: () => ShareContact(name: '', phone: r.phone),
    );
    final name = contact.name.trim();
    final primaryText = name.isNotEmpty
        ? name
        : '尾号 ${r.phone.substring(r.phone.length - 4)}';
    final maskedPhone =
        '${r.phone.substring(0, 3)}****${r.phone.substring(r.phone.length - 4)}';
    final statusText = r.registered
        ? '已发送至对方账号，等待确认'
        : '已发送邀请短信（免费）';
    final statusColor = r.registered ? _kThemeBlue : _kMutedGrey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primaryText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kTitleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                maskedPhone,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kMutedGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Align(
            alignment: Alignment.center,
            child: Tooltip(
              message: r.registered
                  ? '通过App内消息发送'
                  : '通过短信邀请发送',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    r.registered
                        ? Icons.chat_bubble_outline
                        : Icons.mail_outline,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    r.registered ? 'App内' : '短信',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPhase() {
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _finishSheet,
            style: FilledButton.styleFrom(
              backgroundColor: _kThemeBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '完成',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _results.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildResultRow(_results[i]),
          ),
          if (i < _results.length - 1)
            const Divider(
              height: 1,
              color: Color(0xFFF1F5F9),
              indent: 16,
              endIndent: 16,
            ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _finishSheet,
              style: FilledButton.styleFrom(
                backgroundColor: _kThemeBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showNicknameInput = _showNicknameInput && !_isFull;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '分享给…',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _kTitleColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close, color: _kMutedGrey, size: 22),
                  ),
                ],
              ),
              if (_resultsPhase)
                _buildResultsPhase()
              else ...[
                _buildSelectedContacts(),
                const Text(
                  'App 内联系人',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactGrid(),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  onTap: () {},
                  leading: const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 22,
                    color: _kTitleColor,
                  ),
                  title: const Text(
                    '从手机通讯录选择',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _kTitleColor,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _kMutedGrey,
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                const Text(
                  '手动输入手机号',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTitleColor,
                  ),
                ),
                if (_isFull) ...[
                  const SizedBox(height: 4),
                  Text(
                    '已选满 5 人，如需添加请先删除已选联系人',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
                const SizedBox(height: 12),
                _buildPhoneInput(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildOutlineAction(
                        label: '添加联系人并分享',
                        icon: Icons.person_add_outlined,
                        onPressed: _isFull
                            ? null
                            : (_phoneValid ? _addAsAppContactAndShare : null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOutlineAction(
                        label: '直接分享',
                        icon: Icons.send_outlined,
                        onPressed: _isFull
                            ? null
                            : (_phoneValid ? _directShare : null),
                      ),
                    ),
                  ],
                ),
                if (showNicknameInput) _buildNicknameInput(),
                const SizedBox(height: 12),
                const Text(
                  '该事件单次最多可分享给 5 人',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _kMutedGrey),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _canConfirm ? _submitShare : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kThemeBlue,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: _kMutedGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _canConfirm
                            ? '确认分享 (${_selectedContacts.length})'
                            : '确认分享',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _canConfirm ? Colors.white : _kMutedGrey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
