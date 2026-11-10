// หน้า 1 Login, หน้า 2 Create account, หน้า 4 Reset password
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';
import '../admin/admin_shell.dart';
import 'home_shell.dart';

// ======================================================================= Login
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// ปุ่ม Log in → ถ้าผ่าน ล้างหน้าเก่าทั้งหมดแล้วไปหน้า Home หรือ Admin
  void _login() {
    final err = AppStore.instance.login(_user.text, _pass.text);
    if (err != null) return toast(context, err, error: true);
    // ล็อกอินที่เดียวกัน: role = admin → หน้า Admin, นักศึกษา → หน้า Home
    final admin = AppStore.instance.me!.isAdmin;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => admin ? const AdminShell() : const HomeShell()),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          RedHeader(
            padding: EdgeInsets.fromLTRB(16.px, 34.px, 16.px, 30.px),
            child: Column(
              children: gapped([
                Container(
                  width: 54.px,
                  height: 54.px,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: C.goldBg),
                  child: Icon(TablerIcons.bolt, size: 26.px, color: C.red),
                ),
                Text('EcoRide', style: ts(22, w: FontWeight.w600, color: Colors.white)),
                Text('Electric rides around campus',
                    style: ts(12, color: const Color(0xFFFFE6E3))),
              ], h: 6),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.px, 22.px, 18.px, 18.px),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: gapped([
                AppInput(
                    key: const Key('login_user'),
                    controller: _user,
                    hint: 'Username',
                    icon: TablerIcons.user),
                AppInput(
                    key: const Key('login_pass'),
                    controller: _pass,
                    hint: 'Password',
                    icon: TablerIcons.lock,
                    obscure: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
                    child: Text('Forgot password?',
                        style: ts(11, w: FontWeight.w500, color: C.red)),
                  ),
                ),
                Btn('Log in', key: const Key('btn_login'), onTap: _login),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New here?', style: ts(11, color: C.chipText)),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text('Create account',
                          style: ts(11, w: FontWeight.w500, color: C.red)),
                    ),
                  ],
                ),
                Text('Demo: somchai.j / password123  ·  admin: admin / password123',
                    textAlign: TextAlign.center, style: ts(10, color: C.chipText)),
              ], h: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================= Create account
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _sid = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _sid, _user, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _signUp() {
    final err = AppStore.instance.register(
      fullName: _name.text,
      studentId: _sid.text,
      username: _user.text,
      password: _pass.text,
      confirm: _confirm.text,
    );
    if (err != null) return toast(context, err, error: true);
    toast(context, 'Account created. Please log in.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Create account'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.px, 8.px, 18.px, 12.px),
                children: gapped([
                  AppInput(controller: _name, hint: 'Full name'),
                  AppInput(controller: _sid, hint: 'Student ID', keyboard: TextInputType.number),
                  AppInput(controller: _user, hint: 'Username'),
                  AppInput(controller: _pass, hint: 'Password', obscure: true),
                  AppInput(controller: _confirm, hint: 'Confirm password', obscure: true),
                  Padding(
                    padding: EdgeInsets.only(left: 6.px),
                    child: Text('Use at least 8 characters.', style: muStyle),
                  ),
                ], h: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.px, 0, 18.px, 8.px),
              child: Column(
                children: [
                  Btn('Sign up', key: const Key('btn_signup'), onTap: _signUp),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Already have an account? Sign in',
                        style: ts(11, color: C.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================= Reset password
// ยืนยันตัวตน 3 อย่าง: username + student ID + full name ต้องตรงกับในระบบ ถึงจะตั้งรหัสใหม่ได้
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _user = TextEditingController();
  final _sid = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_user, _sid, _name, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _confirmReset() {
    final err = AppStore.instance.resetPassword(
      username: _user.text,
      studentId: _sid.text,
      fullName: _name.text,
      password: _pass.text,
      confirm: _confirm.text,
    );
    if (err != null) return toast(context, err, error: true);
    toast(context, 'Password changed. Please log in.');
    Navigator.of(context).pop();
  }

  /// ไปหน้าลืม username → ถ้าหาเจอ เติม username ให้ในช่องเลย
  Future<void> _forgotUsername() async {
    final found = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ForgotUsernameScreen()));
    if (found != null) setState(() => _user.text = found);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Reset password'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.px, 8.px, 18.px, 12.px),
                children: gapped([
                  Center(
                    child: Container(
                      width: 52.px,
                      height: 52.px,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: C.goldBg),
                      child: Icon(TablerIcons.lock, size: 24.px, color: C.goldIcon),
                    ),
                  ),
                  Text('Confirm who you are, then set a new password.',
                      textAlign: TextAlign.center, style: ts(11, color: C.chipText)),
                  AppInput(controller: _user, hint: 'Username', icon: TablerIcons.user),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('btn_forgot_username'),
                      onPressed: _forgotUsername,
                      child: Text('Forgot username?',
                          style: ts(11, w: FontWeight.w500, color: C.red)),
                    ),
                  ),
                  AppInput(
                      controller: _sid,
                      hint: 'Student ID',
                      icon: TablerIcons.id,
                      keyboard: TextInputType.number),
                  AppInput(controller: _name, hint: 'Full name', icon: TablerIcons.userCircle),
                  AppInput(controller: _pass, hint: 'New password', obscure: true),
                  AppInput(controller: _confirm, hint: 'Confirm new password', obscure: true),
                ], h: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.px, 0, 18.px, 14.px),
              child: Btn('Confirm', key: const Key('btn_reset'), onTap: _confirmReset),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================= Forgot username
// ใส่ student ID + full name → โชว์ username ของบัญชีนั้น แล้วกดกลับไปหน้า reset พร้อมเติมให้
class ForgotUsernameScreen extends StatefulWidget {
  const ForgotUsernameScreen({super.key});

  @override
  State<ForgotUsernameScreen> createState() => _ForgotUsernameScreenState();
}

class _ForgotUsernameScreenState extends State<ForgotUsernameScreen> {
  final _sid = TextEditingController();
  final _name = TextEditingController();
  String? _found;

  @override
  void dispose() {
    _sid.dispose();
    _name.dispose();
    super.dispose();
  }

  void _find() {
    final (username, err) =
        AppStore.instance.findUsername(studentId: _sid.text, fullName: _name.text);
    if (err != null) {
      setState(() => _found = null);
      return toast(context, err, error: true);
    }
    setState(() => _found = username);
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Forgot username'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.px, 8.px, 18.px, 12.px),
                children: gapped([
                  Center(
                    child: Container(
                      width: 52.px,
                      height: 52.px,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: C.goldBg),
                      child: Icon(TablerIcons.userSearch, size: 24.px, color: C.goldIcon),
                    ),
                  ),
                  Text('Enter your student ID and full name to find your username.',
                      textAlign: TextAlign.center, style: ts(11, color: C.chipText)),
                  AppInput(
                      controller: _sid,
                      hint: 'Student ID',
                      icon: TablerIcons.id,
                      keyboard: TextInputType.number),
                  AppInput(controller: _name, hint: 'Full name', icon: TablerIcons.userCircle),
                  if (found != null)
                    Container(
                      padding: EdgeInsets.all(12.px),
                      decoration: BoxDecoration(
                          color: C.goldBg, borderRadius: BorderRadius.circular(16.px)),
                      child: Column(
                        children: [
                          Text('Your username is', style: ts(11, color: C.kpText)),
                          Text(found, style: ts(17, w: FontWeight.w600, color: C.red)),
                        ],
                      ),
                    ),
                ], h: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.px, 0, 18.px, 14.px),
              child: found == null
                  ? Btn('Find my username', key: const Key('btn_find_username'), onTap: _find)
                  : Btn('Use this username',
                      kind: BtnKind.gold, onTap: () => Navigator.of(context).pop(found)),
            ),
          ],
        ),
      ),
    );
  }
}
