import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Alamat aplikasi web Maxx Laundry. APK ini membuka alamat tersebut
/// dan menambahkan cetak langsung ke printer thermal Bluetooth.
const appUrl = 'https://dokevv.github.io/Maax-laundry/';
const pink = Color(0xFFFF4FA3);
const bg = Color(0xFF0B0B0D);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: bg,
  ));
  runApp(const MaxxApp());
}

class MaxxApp extends StatelessWidget {
  const MaxxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maxx Laundry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: pink, brightness: Brightness.dark).copyWith(primary: pink),
        scaffoldBackgroundColor: bg,
      ),
      home: const WebShell(),
    );
  }
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _web;
  bool _loading = true;
  bool _error = false;
  String? _connectedMac;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..addJavaScriptChannel('MaxxPrinter', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; _error = false; }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (err) {
          if (err.isForMainFrame ?? true) setState(() { _error = true; _loading = false; });
        },
        onNavigationRequest: (req) {
          final url = req.url;
          if (url.startsWith(appUrl) || url.startsWith('https://dokevv.github.io/Maax-laundry') || url.startsWith('about:')) {
            return NavigationDecision.navigate;
          }
          // Link lain (WhatsApp, RawBT, dll) dibuka di luar aplikasi.
          _openExternal(url);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(appUrl));

    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnShowFileSelector(_pickPhoto);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  // ---------------- Foto bukti: kamera atau galeri ----------------
  Future<List<String>> _pickPhoto(FileSelectorParams params) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF17171B),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, color: pink),
            title: const Text('Ambil foto (kamera)'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: pink),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return [];
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file == null) return [];
    return [Uri.file(file.path).toString()];
  }

  // ---------------- Pesan dari aplikasi web ----------------
  Future<void> _onMessage(String msg) async {
    if (msg.startsWith('__open__')) {
      await _openExternal(msg.substring(8));
      return;
    }
    if (msg == '__select__') {
      await _selectPrinter(force: true);
      return;
    }
    if (msg == '__test__') {
      // Struk tes singkat: untuk memastikan printer yang dipilih benar.
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('printer_name') ?? '-';
      final txt = '\x1B@\x1Ba\x01\x1BE\x01MAXX LAUNDRY\n\x1BE\x00Tes printer berhasil\nPrinter: $name\n\n\n\n';
      await _print(txt.codeUnits.map((c) => c & 0x7F).toList());
      return;
    }
    await _print(base64Decode(msg));
  }

  Future<void> _openExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Tidak bisa membuka link');
    }
  }

  Future<bool> _ensureBluetooth() async {
    final statuses = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    final denied = statuses.values.any((s) => s.isPermanentlyDenied);
    if (denied) {
      _snack('Izin Bluetooth ditolak. Aktifkan di Pengaturan HP > Aplikasi > Maxx Laundry.');
      return false;
    }
    final on = await PrintBluetoothThermal.bluetoothEnabled;
    if (!on) {
      _snack('Bluetooth mati. Nyalakan Bluetooth lalu coba lagi.');
      return false;
    }
    return true;
  }

  Future<String?> _selectPrinter({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('printer_mac');
    if (saved != null && !force) return saved;
    if (!await _ensureBluetooth()) return null;
    final list = await PrintBluetoothThermal.pairedBluetooths;
    if (!mounted) return null;
    if (list.isEmpty) {
      _snack('Belum ada printer yang di-pairing. Pairing printer di Pengaturan Bluetooth HP dulu.');
      return null;
    }
    final picked = await showModalBottomSheet<BluetoothInfo>(
      context: context,
      backgroundColor: const Color(0xFF17171B),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pilih printer struk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final d in list)
            ListTile(
              leading: const Icon(Icons.print, color: pink),
              title: Text(d.name),
              subtitle: Text(d.macAdress),
              trailing: d.macAdress == saved ? const Icon(Icons.check, color: pink) : null,
              onTap: () => Navigator.pop(ctx, d),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return null;
    await prefs.setString('printer_mac', picked.macAdress);
    await prefs.setString('printer_name', picked.name);
    _snack('Printer dipilih: ${picked.name}');
    return picked.macAdress;
  }

  Future<void> _print(List<int> bytes) async {
    if (_printing) return;
    _printing = true;
    try {
      if (!await _ensureBluetooth()) return;
      final mac = await _selectPrinter();
      if (mac == null) return;
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('printer_name') ?? mac;
      // Coba 2x: kalau gagal, putuskan koneksi lalu sambung ulang.
      for (var attempt = 0; attempt < 2; attempt++) {
        var connected = await PrintBluetoothThermal.connectionStatus;
        if (!connected || _connectedMac != mac) {
          try { await PrintBluetoothThermal.disconnect; } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 400));
          connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
          _connectedMac = connected ? mac : null;
        }
        if (!connected) {
          if (attempt == 1) {
            _snack('Tidak bisa tersambung ke $name. Pastikan printer menyala, dekat, dan tidak sedang tersambung ke HP/komputer lain.');
          }
          continue;
        }
        final ok = await PrintBluetoothThermal.writeBytes(bytes);
        if (ok) {
          _snack('Struk dicetak ✓');
          return;
        }
        try { await PrintBluetoothThermal.disconnect; } catch (_) {}
        _connectedMac = null;
        await Future.delayed(const Duration(milliseconds: 600));
      }
      _snack('Gagal mencetak ke $name. Coba "Tes printer" di Pengaturan, atau pilih printer lain.');
    } finally {
      _printing = false;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _web),
            if (_loading)
              const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('MAXX', style: TextStyle(color: pink, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 6)),
                  SizedBox(height: 16),
                  CircularProgressIndicator(color: pink),
                ]),
              ),
            if (_error)
              Container(
                color: bg,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, color: pink, size: 56),
                  const SizedBox(height: 12),
                  const Text('Tidak ada koneksi internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Periksa Wi-Fi atau data seluler, lalu coba lagi.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => _web.reload(), child: const Text('Coba lagi')),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
