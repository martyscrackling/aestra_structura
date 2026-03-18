import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/app_theme_tokens.dart';

class SupervisorUserBadge extends StatefulWidget {
  final bool showSubtitle;
  final bool showName;
  final String subtitle;
  final double gap;
  final double avatarSize;
  final TextStyle? nameStyle;
  final TextStyle? subtitleStyle;

  const SupervisorUserBadge({
    super.key,
    this.showSubtitle = true,
    this.showName = true,
    this.subtitle = 'Supervisor',
    this.gap = 10,
    this.avatarSize = 36,
    this.nameStyle,
    this.subtitleStyle,
  });

  @override
  State<SupervisorUserBadge> createState() => _SupervisorUserBadgeState();
}

class _SupervisorUserBadgeState extends State<SupervisorUserBadge> {
  Map<String, dynamic>? _profileUser;

  @override
  void initState() {
    super.initState();
    _hydrateSupervisorProfileIfNeeded();
  }

  Future<void> _hydrateSupervisorProfileIfNeeded() async {
    try {
      final auth = AuthService();
      final user = auth.currentUser;
      final first = (user?['first_name'] as String? ?? '').trim();
      final last = (user?['last_name'] as String? ?? '').trim();
      final hasName = ('$first $last').trim().isNotEmpty;

      if (hasName) {
        if (!mounted) return;
        setState(() {
          _profileUser = user;
        });
        return;
      }

      final supervisorIdRaw = user?['supervisor_id'];
      final supervisorId = supervisorIdRaw is int
          ? supervisorIdRaw
          : int.tryParse(supervisorIdRaw?.toString() ?? '');

      final projectIdRaw = user?['project_id'];
      final projectId = projectIdRaw is int
          ? projectIdRaw
          : int.tryParse(projectIdRaw?.toString() ?? '');

      if (supervisorId == null || projectId == null) {
        if (!mounted) return;
        setState(() {
          _profileUser = user;
        });
        return;
      }

      final response = await http.get(
        AppConfig.apiUri('supervisors/$supervisorId/?project_id=$projectId'),
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _profileUser = user;
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        if (!mounted) return;
        setState(() {
          _profileUser = user;
        });
        return;
      }

      final profile = Map<String, dynamic>.from(decoded);
      await auth.updateLocalUserFields({
        'first_name': profile['first_name'],
        'last_name': profile['last_name'],
        'email': profile['email'],
      });

      if (!mounted) return;
      setState(() {
        _profileUser = auth.currentUser;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileUser = AuthService().currentUser;
      });
    }
  }

  String _displayName(Map<String, dynamic>? user) {
    final first = (user?['first_name'] as String? ?? '').trim();
    final last = (user?['last_name'] as String? ?? '').trim();
    final full = ('$first $last').trim();
    if (full.isNotEmpty) return full;
    final email = (user?['email'] as String? ?? '').trim();
    if (email.isNotEmpty) return email;
    return 'AESTRA';
  }

  String _avatarLetter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = _profileUser ?? auth.currentUser;
    final name = _displayName(user);

    final nameStyle =
        widget.nameStyle ??
        TextStyle(
          color: AppColors.textPrimary,
          fontSize: widget.showSubtitle ? 13 : null,
          fontWeight: FontWeight.w700,
        );

    final subtitleStyle =
        widget.subtitleStyle ??
        const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.avatarSize,
          height: widget.avatarSize,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border.all(color: AppColors.borderSubtle),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _avatarLetter(name),
              style: TextStyle(
                color: AppColors.accent,
                fontSize: widget.avatarSize * 0.48,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (widget.showName) SizedBox(width: widget.gap),
        if (widget.showName && widget.showSubtitle)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
            ],
          )
        else if (widget.showName)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
      ],
    );
  }
}
