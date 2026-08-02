import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/room_store.dart';
import '../services/tor_engine.dart';
import '../state/room_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/profile_avatar.dart';
import 'avatar_picker_screen.dart';
import 'splash_screen.dart';
import 'theme_screen.dart';
import 'tor_log_screen.dart';

const _githubUrl = 'https://github.com/arcangel0/OnionChat';

/// Bridge presets bundled with Tor Browser itself (the built-in obfs4
/// defaults, plus snowflake and meek-azure). Picking one fills the bridge
/// lines; "Custom" leaves the field free for the user's own bridges.
const _bridgePresets = <(String, String)>[
  (
    'Obfs4 (Tor Browser default)',
    'obfs4 192.95.36.142:443 CDF2E852BF539B82BD10E27E9115A31734E378C2 '
        'cert=qUVQ0srL1JI/vO6V6m/24anYXiJD3QP2HgzUKQtQ7GRqqUvs7P+tG43RtAqdhLOALP7DJQ iat-mode=1\n'
        'obfs4 37.218.245.14:38224 D9A82D2F9C2F65A18407B1D2B764F130847F8B5D '
        'cert=bjRaMrr1BRiAW8IE9U5z27fQaYgOhX1UCmOpg2pFpoMvo6ZgQMzLsaTzzQNTlm7hNcb+Sg iat-mode=0\n'
        'obfs4 85.31.186.98:443 011F2599C0E9B27EE74B353155E244813763C3E5 '
        'cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=0\n'
        'obfs4 85.31.186.26:443 91A6354697E6B02A386312F68D82CF86824D3606 '
        'cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=0\n'
        'obfs4 193.11.166.194:27015 2D82C2E354D531A68469ADF7F878FA6060C6BACA '
        'cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW/NHkUwIdjLSS3KYf0Nv4/nQiiI8dY2TcsQx01NniOg iat-mode=0\n'
        'obfs4 193.11.166.194:27020 86AC7B8D430DAC4117E9F42C9EAED18133863AAF '
        'cert=0LDeJH4JzMDtkJJrFphJCiPqKx7loozKN7VNfuukMGfHO0Z8OGdzHVkhVAOfo1mUdv9cMg iat-mode=0',
  ),
  (
    'Snowflake',
    'snowflake 192.0.2.1:80 2B280B23E1107BB62ABFC40DDCC882B4A0B0F381',
  ),
  (
    'Meek-azure',
    'meek_lite 0.0.2.0:2 97700DFE9F0B2A2D84A23B0A0F3E2947E6BF62AF '
        'url=https://meek.azureedge.net/',
  ),
];

const _customBridge = '__custom__';

/// Full settings: profile (name, picture, bio), notifications, appearance,
/// advanced Tor options (bridges, ports, logs, erase everything) and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _socksPort;
  late final TextEditingController _controlPort;
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _bridges;

  String? _torVersion;
  String? _appVersion;
  bool _portsDirty = false;
  String? _bridgePreset;

  @override
  void initState() {
    super.initState();
    final s = ThemeController.instance.settings;
    _socksPort = TextEditingController(text: s.socksPort.toString());
    _controlPort = TextEditingController(text: s.controlPort.toString());
    _name = TextEditingController();
    _bio = TextEditingController();
    _bridges = TextEditingController(text: s.bridges);
    // Only present a preset as selected when bridges are actually enabled;
    // otherwise the dropdown would look like a bridge is configured already.
    _bridgePreset = s.useBridges ? _presetLabelFor(s.bridges) : null;
    _bridges.addListener(_onBridgesEdited);
    _socksPort.addListener(_markPortsDirty);
    _controlPort.addListener(_markPortsDirty);
    _loadProfile();
    _loadVersions();
  }

  static String? _presetLabelFor(String lines) {
    // Unset bridges default to the bundled Obfs4 preset (Tor Browser's own).
    if (lines.trim().isEmpty) return _bridgePresets.first.$1;
    for (final p in _bridgePresets) {
      if (p.$2 == lines) return p.$1;
    }
    return null;
  }

  void _onBridgesEdited() {
    if (_bridgePreset == null) return;
    final presetText =
        _bridgePresets.firstWhere((p) => p.$1 == _bridgePreset).$2;
    if (_bridges.text != presetText) {
      setState(() => _bridgePreset = null);
    }
  }

  void _onBridgePresetChanged(String? value) {
    if (value == null) return;
    if (value == _customBridge) {
      setState(() => _bridgePreset = null);
      return;
    }
    final lines = _bridgePresets.firstWhere((p) => p.$1 == value).$2;
    _bridges.text = lines;
    _bridgePreset = value;
    setState(() {});
    ThemeController.instance.setBridges(bridges: lines);
  }

  Future<void> _loadProfile() async {
    final store = await RoomStore.load();
    final tc = ThemeController.instance;
    if (!mounted) return;
    _name.text = store.username ?? '';
    _bio.text = store.bio ?? tc.settings.bio ?? '';
    setState(() {});
  }

  void _markPortsDirty() {
    if (!mounted || _portsDirty) return;
    setState(() => _portsDirty = true);
  }

  Future<void> _loadVersions() async {
    final info = await PackageInfo.fromPlatform();
    final version = await TorEngine.instance.torVersion();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _torVersion = version;
    });
  }

  @override
  void dispose() {
    _socksPort.dispose();
    _controlPort.dispose();
    _name.dispose();
    _bio.dispose();
    _bridges.removeListener(_onBridgesEdited);
    _bridges.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- profile

  Future<void> _saveName(String value) async {
    final store = await RoomStore.load();
    await store.setUsername(value.trim());
  }

  Future<void> _saveBio(String value) async {
    final store = await RoomStore.load();
    await store.setBio(value.trim());
    await ThemeController.instance.setBio(value);
  }

  Future<void> _changeAvatar() async {
    final tc = ThemeController.instance;
    final picked =
        await AvatarPickerScreen.pick(context, current: tc.settings.avatar);
    if (picked != null && mounted) {
      await tc.setAvatar(picked.value);
      if (mounted) setState(() {});
    }
  }

  // ------------------------------------------------------------------- tor

  Future<void> _saveTorPorts() async {
    final socks = int.tryParse(_socksPort.text.trim());
    final control = int.tryParse(_controlPort.text.trim());
    if (socks == null || control == null || socks <= 0 || control <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ports must be valid numbers')),
      );
      return;
    }
    await ThemeController.instance.setTorPorts(socks: socks, control: control);
    if (!mounted) return;
    setState(() => _portsDirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved. Takes effect the next time Tor starts.'),
      ),
    );
  }

  // --------------------------------------------------------------- wipe-all

  Future<void> _eraseAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
        title: const Text('Erase all data?'),
        content: const Text(
          'Your own messages are deleted on every room you joined or hosted. '
          'Then this device wipes every saved room, message history, profile '
          'picture, custom wallpaper and all settings. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Delete the user's own messages on every server they're connected to
    // (rooms they joined and rooms they host), then wipe this device.
    await RoomController.instance.eraseAllData();

    final store = await RoomStore.load();
    await store.eraseAll();
    await ThemeController.instance.resetAll();

    final dir = await getApplicationDocumentsDirectory();
    for (final name in ['media', 'themes']) {
      final folder = Directory('${dir.path}/$name');
      if (folder.existsSync()) {
        try {
          folder.deleteSync(recursive: true);
        } catch (_) {}
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    final scheme = Theme.of(context).colorScheme;
    final s = tc.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _Header('Profile'),
          ListenableBuilder(
            listenable: tc,
            builder: (context, _) => ListTile(
              leading: ProfileAvatar(
                avatar: tc.settings.avatar,
                initial: 'Me',
                size: 42,
                color: scheme.primary,
              ),
              title: const Text('Profile picture'),
              subtitle: const Text('Shown as your avatar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changeAvatar,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 32,
              onSubmitted: _saveName,
              decoration: InputDecoration(
                labelText: 'Display name',
                hintText: 'Type a cool username…',
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: IconButton(
                  tooltip: 'Save',
                  icon: const Icon(Icons.check),
                  onPressed: () => _saveName(_name.text),
                ),
                counterText: '',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: _bio,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 160,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'Say something about yourself…',
                helperText:
                    'Used as a placeholder whenever you join a room',
                prefixIcon: const Icon(Icons.notes_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Save',
                  icon: const Icon(Icons.check),
                  onPressed: () => _saveBio(_bio.text),
                ),
                counterText: '',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const Divider(),
          const _Header('Notifications'),
          _SwitchTile(
            title: 'Notifications allowed',
            subtitle: 'Show a notification for new messages',
            icon: Icons.notifications_active_outlined,
            value: s.notificationsEnabled,
            onChanged: tc.setNotif,
          ),
          _SwitchTile(
            title: 'Play sound on notification',
            subtitle: 'Chime when a message arrives while you\u2019re away',
            icon: Icons.music_note_outlined,
            value: s.notifSound,
            onChanged: tc.setNotifSound,
          ),
          _SwitchTile(
            title: 'Vibrate on notification',
            icon: Icons.vibration,
            value: s.notifVibrate,
            onChanged: tc.setNotifVibrate,
          ),
          _SwitchTile(
            title: 'Sound when receiving a message',
            subtitle: 'In the chat too, not just notifications',
            icon: Icons.call_received,
            value: s.soundReceive,
            onChanged: tc.setSoundReceive,
          ),
          _SwitchTile(
            title: 'Sound when sending a message',
            icon: Icons.call_made,
            value: s.soundSend,
            onChanged: tc.setSoundSend,
          ),
          _SwitchTile(
            title: 'Click sounds',
            subtitle: 'Small sound when tapping around the app',
            icon: Icons.touch_app_outlined,
            value: s.soundClick,
            onChanged: tc.setSoundClick,
          ),
          const Divider(),
          const _Header('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: const Text(
                'Import/export themes, colors for every element, wallpaper'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeScreen()),
            ),
          ),
          const Divider(),
          const _Header('Advanced'),
          _SwitchTile(
            title: 'Use Tor bridges',
            subtitle: 'Help bypass Tor blocking in your region',
            icon: Icons.hub_outlined,
            value: s.useBridges,
            onChanged: (v) {
              // Default the bridge lines to the bundled Obfs4 preset when
              // bridges are first enabled.
              if (v && _bridges.text.trim().isEmpty) {
                _bridges.text = _bridgePresets.first.$2;
                _bridgePreset = _bridgePresets.first.$1;
              }
              tc.setBridges(useBridges: v);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _bridgePreset ?? _customBridge,
              key: ValueKey(_bridgePreset ?? _customBridge),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Bridge preset',
                helperText:
                    'The built-in bridges shipped with Tor Browser, or your own',
                prefixIcon: const Icon(Icons.lan_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: [
                for (final p in _bridgePresets)
                  DropdownMenuItem(
                    value: p.$1,
                    child: Text(p.$1, overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(
                  value: _customBridge,
                  child: Text('Custom (type below)'),
                ),
              ],
              onChanged: s.useBridges ? _onBridgePresetChanged : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _bridges,
              enabled: s.useBridges,
              maxLines: 3,
              minLines: 2,
              autocorrect: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Bridge lines',
                helperText:
                    'One bridge per line, e.g. obfs4 … or 1.2.3.4:443 '
                    'FINGERPRINT',
                prefixIcon: const Icon(Icons.hub_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => tc.setBridges(bridges: v),
            ),
          ),
          _PortField(
            controller: _socksPort,
            icon: Icons.router,
            label: 'SOCKS port',
            helper: 'Tor SOCKS proxy (default 9050)',
          ),
          _PortField(
            controller: _controlPort,
            icon: Icons.tune,
            label: 'Control port',
            helper: 'Tor control interface (default 9051)',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _portsDirty ? _saveTorPorts : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Tor ports'),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Tor logs'),
            subtitle: const Text('View the Tor daemon log on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TorLogScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.redAccent),
            title: const Text('Erase all data'),
            subtitle: const Text('Chats, history, pictures, settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _eraseAll,
          ),
          const Divider(),
          const _Header('About'),
          ListTile(
            leading: const ClipOval(child: AppLogo(size: 34)),
            title: const Text('OnionChat'),
            subtitle: const Text('Anonymous P2P chat via Tor hidden services'),
            trailing: Text('v${_appVersion ?? '…'}'),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Bundled Tor'),
            subtitle: Text(_torVersion ?? 'Tor —'),
            trailing: _torVersion == null
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Developed by arcangelo'),
            subtitle: const Text('Open source on GitHub'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(Uri.parse(_githubUrl)),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'OnionChat · no servers, no tracking. All traffic goes through '
              'your own Tor daemon; rooms are hosted on the phone itself.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PortField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String helper;

  const _PortField({
    required this.controller,
    required this.icon,
    required this.label,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(helper),
      trailing: SizedBox(
        width: 84,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
