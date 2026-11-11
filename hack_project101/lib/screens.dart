import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import 'language.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'services.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ErrorView extends StatelessWidget {
  final String message;
  const ErrorView({super.key, required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
    ),
  );
}

void showProblem(BuildContext context, Object error) {
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        duration: const Duration(seconds: 5),
      ),
    );
}

String dateLabel(dynamic value) {
  if (value is! Timestamp) return 'Just now';
  final d = value.toDate().toLocal();
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Widget sectionTitle(String title, {String? subtitle}) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      if (subtitle != null)
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
    ],
  ),
);
Widget infoCard({
  required IconData icon,
  required String title,
  required String description,
  VoidCallback? onTap,
}) => Card(
  child: ListTile(
    contentPadding: const EdgeInsets.all(14),
    leading: CircleAvatar(child: Icon(icon)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(description),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  ),
);

class PageShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool signOut;
  final Widget? action;
  const PageShell({
    super.key,
    required this.title,
    required this.children,
    this.signOut = false,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        TextButton(
          onPressed: () => appLanguage.value = isUrdu ? 'English' : 'Urdu',
          child: Text(isUrdu ? 'English' : 'اردو'),
        ),
        ?action,
        if (signOut)
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 790),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      phone = TextEditingController();
  final registration = TextEditingController(),
      hospital = TextEditingController(),
      cnic = TextEditingController();
  bool create = false, worker = false, busy = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    phone.dispose();
    registration.dispose();
    hospital.dispose();
    cnic.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (create) {
        await MotherCareService.register(
          name: name.text,
          email: email.text,
          password: password.text,
          phone: phone.text,
          worker: worker,
          registration: registration.text,
          hospital: hospital.text,
          cnic: cnic.text,
          language: appLanguage.value,
        );
      } else {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        if (credential.user != null) {
          final record = await db
              .collection('users')
              .doc(credential.user!.uid)
              .get();
          if (record.data()?['role'] == 'patient') {
            await db.collection('patients').doc(credential.user!.uid).update({
              'language': appLanguage.value,
            });
          }
        }
      }
    } catch (e) {
      if (mounted) showProblem(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 55,
                  color: Color(0xFFC04467),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MotherCare Connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Better awareness. Connected care.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'English', label: Text('English')),
                    ButtonSegment(value: 'Urdu', label: Text('اردو')),
                  ],
                  selected: {appLanguage.value},
                  onSelectionChanged: (v) {
                    languageChosenBeforeLogin = true;
                    appLanguage.value = v.first;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  create
                      ? tr('Create your account', 'اپنا اکاؤنٹ بنائیں')
                      : tr('Welcome back', 'خوش آمدید'),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                if (create) ...[
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: tr('Full name', 'پورا نام'),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? tr('Enter your name', 'نام لکھیں')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    decoration: InputDecoration(
                      labelText: tr('Phone (optional)', 'فون (اختیاری)'),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: email,
                  decoration: InputDecoration(labelText: tr('Email', 'ای میل')),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@')
                      ? tr('Enter a valid email', 'درست ای میل لکھیں')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: tr('Password', 'پاس ورڈ'),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? tr(
                          'Use at least 6 characters',
                          'کم از کم ۶ حروف استعمال کریں',
                        )
                      : null,
                ),
                if (create) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr(
                        'Register as healthcare worker',
                        'بطور صحت کارکن رجسٹر کریں',
                      ),
                    ),
                    subtitle: Text(
                      tr(
                        'Worker accounts require administrator approval',
                        'صحت کارکن کی منظوری منتظم دے گا',
                      ),
                    ),
                    value: worker,
                    onChanged: (v) => setState(() => worker = v),
                  ),
                ],
                if (create && worker) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: registration,
                    decoration: InputDecoration(
                      labelText: tr(
                        'Professional registration number',
                        'رجسٹریشن نمبر',
                      ),
                    ),
                    validator: (v) => worker && (v ?? '').trim().isEmpty
                        ? 'Enter registration number'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: hospital,
                    decoration: InputDecoration(
                      labelText: tr(
                        'Hospital or healthcare facility',
                        'ہسپتال یا مرکز صحت',
                      ),
                    ),
                    validator: (v) => worker && (v ?? '').trim().isEmpty
                        ? 'Enter workplace'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cnic,
                    decoration: InputDecoration(
                      labelText: tr(
                        'CNIC (demo only: use fictional data)',
                        'شناختی نمبر (صرف فرضی معلومات)',
                      ),
                    ),
                    validator: (v) => worker && (v ?? '').trim().isEmpty
                        ? 'Enter identifier'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registration details are submitted for manual admin verification. Enter no real CNIC or medical data during the demo.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Text(
                      busy
                          ? tr('Please wait...', 'انتظار کریں...')
                          : create
                          ? tr('Create account', 'اکاؤنٹ بنائیں')
                          : tr('Sign in', 'لاگ ان'),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => create = !create),
                  child: Text(
                    create
                        ? tr(
                            'Already registered? Sign in',
                            'اکاؤنٹ ہے؟ لاگ ان کریں',
                          )
                        : tr(
                            'New here? Create an account',
                            'نیا اکاؤنٹ بنائیں',
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Prototype only. Not a replacement for antenatal visits or emergency services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MissingProfileScreen extends StatelessWidget {
  final String uid;
  const MissingProfileScreen({super.key, required this.uid});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Account setup incomplete',
    signOut: true,
    children: [
      const Text(
        'Your Firebase Authentication account exists, but its Firestore profile is missing. Ask an administrator to resolve this before continuing.',
      ),
      SelectableText('Account UID: $uid'),
    ],
  );
}

class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageShell(
    title: 'Worker request declined',
    signOut: true,
    children: [
      Text(
        'Your healthcare-worker registration was not approved. Contact the project administrator if this is an error.',
      ),
    ],
  );
}

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageShell(
    title: 'Approval pending',
    signOut: true,
    children: [
      SizedBox(height: 40),
      Icon(Icons.verified_user_outlined, size: 70, color: Color(0xFFC04467)),
      SizedBox(height: 22),
      Text(
        'Your healthcare-worker request has been received.',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 10),
      Text(
        'An administrator must verify your identity and approve access before you can view patient information.',
      ),
    ],
  );
}

class PatientDashboard extends StatelessWidget {
  final String uid, name;
  const PatientDashboard({super.key, required this.uid, required this.name});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: db.collection('patients').doc(uid).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');
      if (!snapshot.hasData) return const LoadingView();
      final patient = snapshot.data!.data() ?? {};
      // On an existing signed-in account, restore the stored preference once.
      // A selection made on the login screen takes precedence for this session.
      if (languageHydratedForUid != uid) {
        languageHydratedForUid = uid;
        final savedLang = patient['language'] as String?;
        if (!languageChosenBeforeLogin &&
            (savedLang == 'English' || savedLang == 'Urdu') &&
            savedLang != appLanguage.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (savedLang != null) {
              appLanguage.value = savedLang;
            }
          });
        }
      }
      final gdm = patient['hasGdm'] == true;
      final lang = appLanguage.value;
      final urdu = isUrdu;
      return PageShell(
        title: 'MotherCare',
        signOut: true,
        children: [
          sectionTitle(
            urdu ? 'خوش آمدید، $name' : 'Hello, $name',
            subtitle: urdu
                ? 'آپ کی حمل کی صحت کا ساتھی'
                : 'Your pregnancy health companion',
          ),
          Card(
            color: const Color(0xFFFFE4EA),
            child: Padding(
              padding: const EdgeInsets.all(19),
              child: Text(
                urdu ? 'اپنی علامات رپورٹ کریں اور ڈاکٹر سے رابطے میں رہیں۔' : 'Report symptoms, understand warning signs, and keep your care team updated.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if ((patient['pregnancyWeeks'] ?? 0) == 0)
            infoCard(
              icon: Icons.info_outline,
              title: urdu
                  ? 'اپنی پروفائل مکمل کریں'
                  : 'Complete your pregnancy profile',
              description: urdu
                  ? 'کیا ڈاکٹر نے آپ میں حمل کی ذیابیطس کی تشخیص کی ہے؟'
                  : 'Tell us whether a clinician has diagnosed GDM.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
              ),
            ),
          sectionTitle(urdu ? 'آپ کی سہولیات' : 'Your care tools'),
          if (gdm)
            infoCard(
              icon: Icons.bloodtype_outlined,
              title: urdu ? 'شوگر کی نگرانی' : 'GDM glucose monitoring',
              description: urdu
                  ? 'میٹر کی تصویر یا ریڈنگ محفوظ کریں'
                  : 'Photograph your meter or enter a confirmed reading',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GlucoseScreen(uid: uid)),
              ),
            ),
          if (!gdm)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  urdu
                      ? 'اگر ڈاکٹر حمل کی ذیابیطس کی تشخیص کرے تو پروفائل میں GDM منتخب کریں۔'
                      : 'GDM monitoring is optional and appears if you report a clinician-confirmed diagnosis.',
                ),
              ),
            ),
          infoCard(
            icon: Icons.healing_outlined,
            title: urdu ? 'علامات رپورٹ کریں' : 'Report symptoms',
            description: urdu
                ? 'آواز، تحریر یا فہرست کے ذریعے'
                : 'Speak, type, or select symptoms',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SymptomScreen(uid: uid, language: lang),
              ),
            ),
          ),
          infoCard(
            icon: Icons.menu_book_outlined,
            title: urdu ? 'خطرے کی علامات' : 'Understand warning signs',
            description: urdu
                ? 'اہم علامات کی آسان معلومات'
                : 'Simple maternal warning-sign education',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EducationScreen(language: lang),
              ),
            ),
          ),
          infoCard(
            icon: Icons.person_outline,
            title: urdu ? 'میری پروفائل' : 'My pregnancy profile',
            description: urdu
                ? 'حمل اور رابطے کی معلومات'
                : 'Pregnancy, diagnosis, language, emergency contact',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
            ),
          ),
          if (gdm) ...[
            sectionTitle(urdu ? 'حالیہ شوگر ریڈنگ' : 'Recent glucose readings'),
            ReadingList(patientId: uid, limit: 3),
          ],
          sectionTitle(urdu ? 'حالیہ علامات' : 'Recent symptom reports'),
          ReportList(patientId: uid, limit: 3),
          sectionTitle(urdu ? 'ڈاکٹر کے نوٹس' : 'Care-team notes'),
          PatientNotes(patientId: uid),
          const SizedBox(height: 16),
          Text(
            tr(
              'Emergency warning signs: seek care immediately. Do not wait for an app or doctor reply.',
              'خطرے کی علامات پر فوری طبی مدد لیں۔ ایپ یا ڈاکٹر کے جواب کا انتظار نہ کریں۔',
            ),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
      );
    },
  );
}

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final phone = TextEditingController(),
      emergency = TextEditingController(),
      weeks = TextEditingController(text: '0');
  bool gdm = false, busy = false, loaded = false;
  String language = 'English';
  @override
  void dispose() {
    phone.dispose();
    emergency.dispose();
    weeks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('My pregnancy profile', 'میری حمل کی پروفائل')),
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('patients').doc(widget.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data();
        if (data == null)
          return const Center(
            child: Text('Patient profile missing. Contact administrator.'),
          );
        if (!loaded) {
          loaded = true;
          phone.text = data['phone'] as String? ?? '';
          emergency.text = data['emergencyContact'] as String? ?? '';
          weeks.text = '${data['pregnancyWeeks'] ?? 0}';
          gdm = data['hasGdm'] == true;
          language = appLanguage.value;
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                sectionTitle(tr('Pregnancy details', 'حمل کی تفصیلات')),
                TextFormField(
                  controller: weeks,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr(
                      'Pregnancy weeks (0–42)',
                      'حمل کے ہفتے (۰–۴۲)',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tr(
                      'Already diagnosed with GDM',
                      'کیا ڈاکٹر نے حمل کی ذیابیطس کی تشخیص کی ہے؟',
                    ),
                  ),
                  subtitle: Text(
                    tr(
                      'Only select if a clinician has diagnosed you',
                      'صرف ڈاکٹر کی تشخیص پر منتخب کریں',
                    ),
                  ),
                  value: gdm,
                  onChanged: (v) => setState(() => gdm = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration: InputDecoration(
                    labelText: tr('Preferred language', 'زبان'),
                  ),
                  items: ['English', 'Urdu']
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => setState(() => language = v ?? 'English'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phone,
                  decoration: InputDecoration(labelText: tr('Phone', 'فون')),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emergency,
                  decoration: InputDecoration(
                    labelText: tr('Emergency contact', 'ہنگامی رابطہ'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${tr('Assigned healthcare worker', 'مقررہ صحت کارکن')}: ${(data['assignedWorkerId'] as String? ?? '').isEmpty ? tr('Not yet assigned', 'ابھی مقرر نہیں') : tr('Assigned', 'مقرر ہے')}',
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final w = int.tryParse(weeks.text);
                          if (w == null || w < 0 || w > 42) {
                            showProblem(
                              context,
                              'Enter pregnancy weeks from 0 to 42',
                            );
                            return;
                          }
                          setState(() => busy = true);
                          try {
                            await MotherCareService.savePatientProfile(
                              widget.uid,
                              weeks: w,
                              gdm: gdm,
                              language: language,
                              phone: phone.text,
                              emergencyContact: emergency.text,
                            );
                            appLanguage.value = language;
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated'),
                                ),
                              );
                          } catch (e) {
                            if (context.mounted) showProblem(context, e);
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: Text(tr('Save profile', 'پروفائل محفوظ کریں')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class GlucoseScreen extends StatefulWidget {
  final String uid;
  const GlucoseScreen({super.key, required this.uid});
  @override
  State<GlucoseScreen> createState() => _GlucoseScreenState();
}

class _GlucoseScreenState extends State<GlucoseScreen> {
  final value = TextEditingController();
  Uint8List? photo;
  String mime = 'image/jpeg';
  String type = 'Fasting', unit = 'mg/dL';
  bool busy = false;
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  Future<void> chooseImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024)
        throw Exception('Image must be smaller than 8 MB');
      setState(() {
        photo = bytes;
        mime = picked.mimeType ?? 'image/jpeg';
      });
    } catch (e) {
      if (mounted) showProblem(context, e);
    }
  }

  Future<void> captureFromCamera() async {
    try {
      final capture = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
      if (capture != null && mounted)
        setState(() {
          photo = capture;
          mime = 'image/jpeg';
        });
    } catch (e) {
      if (mounted) showProblem(context, e);
    }
  }

  Future<void> extract() async {
    if (photo == null) return;
    setState(() => busy = true);
    try {
      final data = await GeminiAssist.readGlucose(photo!, mime);
      if (mounted)
        setState(() {
          value.text = '${data['value']}';
          unit = data['unit'] as String;
        });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI extracted a possible value. Verify it on the meter before saving.',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        showProblem(
          context,
          '${tr('Gemini extraction failed', 'جیمینائی سے تصویر پڑھنے میں مسئلہ')}: $e',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final number = double.tryParse(value.text.trim());
    if (number == null || number <= 0 || number > 1000) {
      showProblem(context, 'Enter a valid positive meter reading');
      return;
    }
    setState(() => busy = true);
    try {
      await MotherCareService.saveReading(
        patientId: widget.uid,
        value: number,
        unit: unit,
        type: type,
        photoBytes: photo,
        mime: mime,
      );
      if (mounted) {
        value.clear();
        setState(() => photo = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Confirmed reading saved', 'ریڈنگ محفوظ ہو گئی')),
          ),
        );
      }
    } catch (e) {
      if (mounted) showProblem(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: tr('Glucose monitoring', 'شوگر کی نگرانی'),
    children: [
      sectionTitle(
        tr('Add a reading', 'شوگر ریڈنگ درج کریں'),
        subtitle: tr(
          'For patients already monitoring glucose with a meter',
          'ان مریضات کے لیے جو گلوکوز میٹر استعمال کرتی ہیں',
        ),
      ),
      Text(
        tr(
          'Take or upload a clear glucometer photo. Gemini can suggest the displayed number, but you must check the value and unit yourself.',
          'گلوکوز میٹر کی واضح تصویر لیں۔ جیمینائی نمبر پڑھنے میں مدد کرے گا، لیکن محفوظ کرنے سے پہلے خود تصدیق کریں۔',
        ),
      ),
      const SizedBox(height: 12),
      if (photo != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(photo!, height: 180, fit: BoxFit.contain),
        ),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : () => chooseImage(ImageSource.gallery),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(tr('Choose photo', 'تصویر منتخب کریں')),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : captureFromCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(tr('Use camera', 'کیمرہ کھولیں')),
          ),
        ],
      ),
      if (photo != null)
        OutlinedButton.icon(
          onPressed: busy ? null : extract,
          icon: const Icon(Icons.auto_awesome),
          label: Text(tr('Read number with Gemini', 'جیمینائی سے نمبر پڑھیں')),
        ),
      const SizedBox(height: 10),
      TextField(
        controller: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: tr('Confirmed glucose value', 'تصدیق شدہ شوگر ریڈنگ'),
          hintText: '102',
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: unit,
        decoration: InputDecoration(labelText: tr('Unit', 'اکائی')),
        items: ['mg/dL', 'mmol/L']
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  v == 'Fasting'
                      ? tr('Fasting', 'خالی پیٹ')
                      : v == 'After meal'
                      ? tr('After meal', 'کھانے کے بعد')
                      : v == 'Other'
                      ? tr('Other', 'دیگر')
                      : v,
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => unit = v ?? 'mg/dL'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: type,
        decoration: InputDecoration(
          labelText: tr('When measured', 'ریڈنگ کب لی گئی؟'),
        ),
        items: ['Fasting', 'After meal', 'Other']
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  v == 'Fasting'
                      ? tr('Fasting', 'خالی پیٹ')
                      : v == 'After meal'
                      ? tr('After meal', 'کھانے کے بعد')
                      : v == 'Other'
                      ? tr('Other', 'دیگر')
                      : v,
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => type = v ?? 'Other'),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: busy ? null : save,
        icon: const Icon(Icons.check),
        label: Text(
          busy
              ? tr('Processing...', 'عمل جاری ہے...')
              : tr('Confirm and save reading', 'تصدیق کر کے محفوظ کریں'),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        tr(
          'This app records values; it does not diagnose GDM or interpret a reading as safe or dangerous.',
          'یہ ایپ ریڈنگ محفوظ کرتی ہے؛ تشخیص یا علاج نہیں کرتی۔',
        ),
        style: const TextStyle(color: Colors.black54),
      ),
      sectionTitle(tr('Reading history', 'پچھلی ریڈنگز')),
      ReadingList(patientId: widget.uid),
    ],
  );
}

/// Live camera preview instead of the desktop browser's file picker.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});
  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? controller;
  String? problem;
  bool taking = false;
  @override
  void initState() {
    super.initState();
    open();
  }

  Future<void> open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty)
        throw Exception(
          'No camera detected. Check browser camera permissions.',
        );
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() => controller = next);
    } catch (e) {
      if (mounted) setState(() => problem = '$e');
    }
  }

  Future<void> capture() async {
    if (taking || controller == null) return;
    setState(() => taking = true);
    try {
      final picture = await controller!.takePicture();
      final bytes = await picture.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024)
        throw Exception('Photo is larger than 8 MB');
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) showProblem(context, e);
    } finally {
      if (mounted) setState(() => taking = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Take glucometer photo', 'گلوکوز میٹر کی تصویر لیں')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: problem != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              '${tr('Camera unavailable', 'کیمرہ دستیاب نہیں')}: $problem',
                            ),
                          ),
                        )
                      : controller == null
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: AspectRatio(
                            aspectRatio: controller!.value.aspectRatio,
                            child: CameraPreview(controller!),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: controller == null || taking ? null : capture,
                icon: const Icon(Icons.camera_alt),
                label: Text(tr('Capture photo', 'تصویر لیں')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                tr(
                  'Allow camera access in Chrome. Use localhost or HTTPS.',
                  'کروم میں کیمرے کی اجازت دیں۔ لوکل ہوسٹ یا HTTPS استعمال کریں۔',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ReadingList extends StatelessWidget {
  final String patientId;
  final int? limit;
  const ReadingList({super.key, required this.patientId, this.limit});
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = db
        .collection('patients')
        .doc(patientId)
        .collection('readings')
        .orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit!);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Text('Unable to load readings: ${snapshot.error}');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        if (snapshot.data!.docs.isEmpty)
          return Text(
            tr('No readings recorded yet.', 'ابھی کوئی ریڈنگ موجود نہیں۔'),
            style: const TextStyle(color: Colors.black54),
          );
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final d = doc.data();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.bloodtype_outlined),
                title: Text(
                  '${d['value']} ${d['unit']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${d['type'] == 'Fasting'
                      ? tr('Fasting', 'خالی پیٹ')
                      : d['type'] == 'After meal'
                      ? tr('After meal', 'کھانے کے بعد')
                      : tr('Other', 'دیگر')} • ${dateLabel(d['createdAt'])}',
                ),
                trailing: (d['photoPath'] as String?)?.isNotEmpty == true
                    ? IconButton(
                        tooltip: 'View photo',
                        icon: const Icon(Icons.image_outlined),
                        onPressed: () async {
                          try {
                            final url = await FirebaseStorage.instance
                                .ref(d['photoPath'] as String)
                                .getDownloadURL();
                            if (context.mounted)
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Glucose meter photo'),
                                  content: Image.network(url),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                          } catch (e) {
                            if (context.mounted) showProblem(context, e);
                          }
                        },
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

const Map<String, String> _urduSymptomLabels = {
  'Nausea or vomiting': 'متلی یا قے',
  'Swelling': 'سوجن',
  'Fatigue': 'تھکاوٹ',
  'Dizziness': 'چکر آنا',
  'Fever': 'بخار',
  'Heavy bleeding': 'زیادہ خون بہنا',
  'Seizure or fainting': 'دورہ یا بے ہوشی',
  'Severe headache or vision changes': 'شدید سر درد یا نظر میں تبدیلی',
  'Chest pain or difficulty breathing': 'سینے میں درد یا سانس کی دشواری',
  'Severe abdominal pain': 'پیٹ میں شدید درد',
  'Baby moving much less than usual': 'بچے کی حرکت معمول سے کم',
  'Fluid leaking': 'پانی کا بہنا',
  'High fever': 'تیز بخار',
  'Sudden severe swelling': 'اچانک شدید سوجن',
  'Other symptom': 'دیگر علامت',
};
String symptomLabel(String original) =>
    isUrdu ? (_urduSymptomLabels[original] ?? original) : original;

class SymptomScreen extends StatefulWidget {
  final String uid, language;
  const SymptomScreen({
    super.key,
    required this.uid,
    this.language = 'English',
  });
  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final description = TextEditingController();
  final Set<String> selected = {};
  final stt.SpeechToText speech = stt.SpeechToText();
  bool busy = false, listening = false;
  SymptomAssessment? assessment;
  String summary = '';
  static const options = [
    'Nausea or vomiting',
    'Swelling',
    'Fatigue',
    'Dizziness',
    'Fever',
    'Heavy bleeding',
    'Seizure or fainting',
    'Severe headache or vision changes',
    'Chest pain or difficulty breathing',
    'Severe abdominal pain',
    'Baby moving much less than usual',
    'Fluid leaking',
    'High fever',
    'Sudden severe swelling',
    'Other symptom',
  ];
  bool get selectedUrgent => SymptomRules.localCodes(
    description.text,
    selected,
  ).any(SymptomRules.urgentCodes.contains);
  bool get urdu => isUrdu;
  @override
  void dispose() {
    speech.stop();
    description.dispose();
    super.dispose();
  }

  Future<void> toggleVoice() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    try {
      final available = await speech.initialize();
      if (!available)
        throw Exception(
          'Microphone or browser speech recognition unavailable.',
        );
      final locales = await speech.locales();
      final requested = urdu ? 'ur' : 'en';
      final supported = locales
          .where((l) => l.localeId.toLowerCase().startsWith(requested))
          .toList();
      if (supported.isEmpty)
        throw Exception(
          tr(
            'Speech recognition for the selected language is unavailable on this browser/device. Type your symptoms or use the symptom buttons.',
            'اس براؤزر میں منتخب زبان کی آواز پہچاننے کی سہولت دستیاب نہیں۔ علامات لکھیں یا بٹن منتخب کریں۔',
          ),
        );
      final prefix = description.text.trim();
      await speech.listen(
        localeId: supported.first.localeId,
        onResult: (result) {
          if (mounted) {
            setState(() {
              description.text = [
                prefix,
                result.recognizedWords,
              ].where((x) => x.isNotEmpty).join(' ');
              assessment = null;
            });
          }
        },
      );
      if (mounted) setState(() => listening = true);
    } catch (e) {
      if (mounted) showProblem(context, e);
    }
  }

  Future<void> processAndSubmit() async {
    if (description.text.trim().isEmpty && selected.isEmpty) {
      showProblem(
        context,
        urdu ? 'براہ کرم علامات درج کریں' : 'Describe or select a symptom',
      );
      return;
    }
    await speech.stop();
    setState(() => busy = true);
    try {
      // Hardcoded checks always run, including if Gemini fails.
      final result = await SymptomRules.analyze(
        description.text.trim(),
        selected.toList(),
      );
      if (!mounted) return;
      setState(() => assessment = result);
      if (!result.aiUsed && SymptomRules.lastAiError != null && mounted) {
        showProblem(context, 'Gemini: ${SymptomRules.lastAiError}');
      }
      // Summary failure cannot prevent an urgent report from being submitted.
      String aiSummary = '';
      if (result.aiUsed) {
        try {
          aiSummary = await GeminiAssist.summarizeSymptoms(
            description.text,
            selected.toList(),
          );
        } catch (_) {
          aiSummary = '';
        }
      }
      await MotherCareService.saveSymptom(
        patientId: widget.uid,
        description: description.text,
        selected: selected.toList(),
        assessment: result,
        aiSummary: aiSummary,
        language: appLanguage.value,
      );
      if (!mounted) return;
      setState(() => summary = aiSummary);
      await showDialog<void>(
        context: context,
        barrierDismissible: !result.urgent,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            result.urgent
                ? Icons.warning_amber_rounded
                : Icons.fact_check_outlined,
            color: result.urgent ? Colors.red : Colors.deepOrange,
            size: 45,
          ),
          title: Text(
            result.urgent
                ? (urdu
                      ? 'فوری طبی مدد حاصل کریں'
                      : 'Urgent medical care required')
                : (result.processingStatus == 'ai_unavailable_review_needed'
                      ? tr(
                          'Human review required • AI unavailable',
                          'انسانی جائزہ ضروری • جیمینائی دستیاب نہیں',
                        )
                      : (urdu
                            ? 'رپورٹ ڈاکٹر کو بھیج دی گئی'
                            : 'Sent for routine doctor review')),
          ),
          content: Text(
            result.urgent
                ? (urdu
                      ? 'آپ کی بتائی گئی علامات خطرناک ہو سکتی ہیں۔ فوراً ہسپتال جائیں یا مقامی ایمرجنسی سروس سے رابطہ کریں۔ ڈاکٹر کے جواب کا انتظار نہ کریں۔'
                      : 'Your reported symptoms include a pregnancy warning sign. Seek emergency care immediately. Do not wait for a response from this app. In Pakistan, call 1122 where available.')
                : (result.processingStatus == 'ai_unavailable_review_needed'
                      ? (urdu
                            ? 'جیمینائی فی الحال دستیاب نہیں۔ آپ کی رپورٹ ڈاکٹر کو بھیج دی گئی ہے، لیکن علامات محفوظ ہونے کی تصدیق نہیں ہوئی۔ شدید یا بڑھتی علامات میں فوری طبی مدد لیں۔'
                            : 'Gemini interpretation is unavailable. Your report needs human review; this does not establish that symptoms are safe. Seek immediate help for severe or worsening symptoms.')
                      : (urdu
                            ? 'آپ کی علامات ڈاکٹر کی عام جانچ کی فہرست میں ہیں۔ اگر حالت خراب ہو تو فوری طبی مدد لیں۔'
                            : 'Your report is in the regular doctor review queue. This does not confirm that symptoms are safe. Seek care promptly if concerned or worsening.')),
          ),
          actions: [
            if (result.urgent)
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: '1122');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Icon(Icons.call),
                label: Text(tr('Call 1122', '۱۱۲۲ پر کال کریں')),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Understood', 'سمجھ گئی')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showProblem(context, 'Report could not be saved: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: urdu ? 'علامات رپورٹ کریں' : 'Report symptoms',
    children: [
      sectionTitle(
        urdu ? 'آپ کی طبیعت کیسی ہے؟' : 'How are you feeling?',
        subtitle: urdu
            ? 'علامات منتخب کریں، لکھیں یا آواز سے بیان کریں'
            : 'Select, type, or dictate your symptoms',
      ),
      Text(
        urdu
            ? 'Gemini علامات کو سمجھنے میں مدد کرتا ہے؛ خطرے کا فیصلہ مقررہ قواعد سے کیا جاتا ہے۔'
            : 'Gemini extracts symptom meaning. Fixed warning-sign rules decide which reports are flagged urgent.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 7,
        runSpacing: 5,
        children: options
            .map(
              (s) => FilterChip(
                label: Text(symptomLabel(s)),
                selected: selected.contains(s),
                onSelected: busy
                    ? null
                    : (v) => setState(() {
                        if (v) {
                          selected.add(s);
                        } else {
                          selected.remove(s);
                        }
                        assessment = null;
                      }),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: description,
        maxLines: 4,
        onChanged: (_) => setState(() => assessment = null),
        decoration: InputDecoration(
          labelText: urdu
              ? 'اپنی علامات لکھیں'
              : 'Describe symptoms in English or Urdu',
          hintText: urdu
              ? 'مثلاً: میرے سر میں شدید درد ہے'
              : 'For example: I have a severe headache and blurred vision',
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: busy ? null : toggleVoice,
        icon: Icon(listening ? Icons.stop_circle_outlined : Icons.mic_none),
        label: Text(
          listening
              ? (urdu ? 'ریکارڈنگ روکیں' : 'Stop listening')
              : (urdu ? 'آواز سے علامات بتائیں' : 'Speak symptoms'),
        ),
      ),
      if (selectedUrgent)
        OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri(scheme: 'tel', path: '1122');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
          icon: const Icon(Icons.call),
          label: Text(
            tr(
              'Call 1122 (Pakistan, where available)',
              '۱۱۲۲ پر کال کریں (جہاں دستیاب ہو)',
            ),
          ),
        ),
      if (selectedUrgent)
        Card(
          color: const Color(0xFFFFE1E3),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              tr(
                'WARNING SIGN: Seek urgent medical attention now. Do not wait for AI processing or a doctor reply. In Pakistan call 1122 where available.',
                'خطرے کی علامت: فوری طبی مدد حاصل کریں۔ ایپ یا ڈاکٹر کے جواب کا انتظار نہ کریں۔ پاکستان میں جہاں دستیاب ہو ۱۱۲۲ پر کال کریں۔',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ),
      if (!selectedUrgent)
        Card(
          color: const Color(0xFFFFF1DB),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              tr(
                'No selected warning sign does not mean symptoms are safe. Severe, unusual, or worsening symptoms require prompt medical attention.',
                'خطرے کی علامت منتخب نہ ہونے کا مطلب یہ نہیں کہ علامات محفوظ ہیں۔ شدید یا بڑھتی علامات پر فوراً طبی مدد لیں۔',
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: busy ? null : processAndSubmit,
        icon: const Icon(Icons.send_outlined),
        label: Text(
          busy
              ? tr(
                  'Processing and saving...',
                  'جائزہ اور محفوظ کیا جا رہا ہے...',
                )
              : (urdu ? 'علامات ڈاکٹر کو بھیجیں' : 'Analyze and submit report'),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        tr(
          'Routine reports appear in the doctor review queue. Urgent reports are visibly flagged. This is not an emergency dispatch service.',
          'عام رپورٹس ڈاکٹر کی فہرست میں اور خطرے والی رپورٹس فوری توجہ کی فہرست میں جاتی ہیں۔ یہ ایمرجنسی سروس نہیں ہے۔',
        ),
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class EducationScreen extends StatelessWidget {
  final String language;
  const EducationScreen({super.key, this.language = 'English'});
  @override
  Widget build(BuildContext context) => PageShell(
    title: language == 'Urdu' ? 'حمل کی احتیاط' : 'Learn & stay aware',
    children: [
      sectionTitle(tr('Pregnancy warning signs', 'حمل میں خطرے کی علامات')),
      Text(
        tr(
          'Most pregnancy questions deserve a conversation with a qualified healthcare professional. Some symptoms need urgent assessment.',
          'حمل کی علامات کے بارے میں صحت کارکن سے مشورہ کریں۔ کچھ علامات فوری توجہ چاہتی ہیں۔',
        ),
      ),
      infoCard(
        icon: Icons.warning_amber_rounded,
        title: tr('Seek emergency care', 'فوری طبی مدد'),
        description: tr(
          'Heavy bleeding, seizures, fainting, severe headache with vision changes, chest pain or difficulty breathing, severe abdominal pain, or markedly reduced baby movements require prompt professional attention.',
          'زیادہ خون بہنا، دورے، بے ہوشی، شدید سر درد، نظر دھندلانا، سینے یا پیٹ میں شدید درد، سانس کی دشواری یا بچے کی حرکت کم ہونا فوری طبی توجہ کا تقاضا کرتے ہیں۔',
        ),
      ),
      infoCard(
        icon: Icons.monitor_heart_outlined,
        title: tr('Understanding GDM', 'حمل کی ذیابیطس'),
        description: tr(
          'Gestational diabetes means blood glucose becomes elevated during pregnancy. Diagnosis and targets must be set by a clinician. A photograph of a meter is not a diagnosis.',
          'حمل کی ذیابیطس میں خون کی شوگر بڑھ سکتی ہے۔ تشخیص اور مطلوبہ حد ڈاکٹر مقرر کرتا ہے۔ میٹر کی تصویر تشخیص نہیں ہے۔',
        ),
      ),
      infoCard(
        icon: Icons.fact_check_outlined,
        title: tr('Record and share', 'محفوظ کریں اور ڈاکٹر کو دکھائیں'),
        description: tr(
          'Keep your prescribed glucose-check schedule, confirm values before saving, and show your record to your healthcare worker.',
          'ڈاکٹر کے بتائے ہوئے وقت پر شوگر چیک کریں۔ ریڈنگ کی تصدیق کریں اور صحت کارکن کو دکھائیں۔',
        ),
      ),
      infoCard(
        icon: Icons.support_agent_outlined,
        title: tr('When uncertain', 'اگر آپ کو شک ہو'),
        description: tr(
          'Contact your assigned healthcare worker or health facility. Do not delay seeking emergency care while waiting for a reply in the app.',
          'اپنے صحت کارکن یا قریبی مرکز صحت سے رابطہ کریں۔ ایپ کے جواب کے انتظار میں فوری طبی مدد لینے میں دیر نہ کریں۔',
        ),
      ),
      const SizedBox(height: 18),
      Text(
        tr(
          'Educational prototype. These explanations cannot replace clinical evaluation.',
          'یہ تعلیمی نمونہ ہے؛ ڈاکٹر کے معائنے کا متبادل نہیں۔',
        ),
        style: const TextStyle(color: Colors.black54),
      ),
    ],
  );
}

class ReportList extends StatelessWidget {
  final String patientId;
  final int? limit;
  final bool canReview;
  final String? urgencyFilter;
  const ReportList({
    super.key,
    required this.patientId,
    this.limit,
    this.canReview = false,
    this.urgencyFilter,
  });
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = db
        .collection('patients')
        .doc(patientId)
        .collection('reports')
        .orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit!);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Text('Unable to load reports: ${snapshot.error}');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        if (snapshot.data!.docs.isEmpty)
          return const Text(
            'No symptom reports yet.',
            style: TextStyle(color: Colors.black54),
          );
        return Column(
          children: snapshot.data!.docs
              .where(
                (doc) =>
                    urgencyFilter == null ||
                    doc.data()['urgency'] == urgencyFilter,
              )
              .map((doc) {
                final d = doc.data();
                final urgent = d['urgency'] == 'urgent';
                final symptoms = (d['symptoms'] as List<dynamic>? ?? [])
                    .map((v) => symptomLabel(v.toString()))
                    .join(', ');
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              urgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.assignment_outlined,
                              color: urgent ? Colors.deepOrange : Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                urgent
                                    ? 'Warning sign reported'
                                    : 'Symptom report',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              (d['status'] as String? ?? 'new').toUpperCase(),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (symptoms.isNotEmpty) Text(symptoms),
                        if ((d['description'] as String? ?? '').isNotEmpty)
                          Text(d['description'] as String),
                        if ((d['aiSummary'] as String? ?? '').isNotEmpty)
                          Text(
                            'AI summary: ${d['aiSummary']}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        if ((d['matchedWarningSigns'] as List? ?? [])
                            .isNotEmpty)
                          Text(
                            'Warning signs: ${(d['matchedWarningSigns'] as List).join(', ')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        if (d['processingStatus'] ==
                            'ai_unavailable_review_needed')
                          const Text(
                            'AI unavailable • needs human review',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        Text(
                          dateLabel(d['createdAt']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        if (canReview)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                try {
                                  await doc.reference.update({
                                    'status': 'reviewed',
                                    'reviewedBy': auth.currentUser!.uid,
                                    'reviewedAt': FieldValue.serverTimestamp(),
                                  });
                                } catch (e) {
                                  if (context.mounted) showProblem(context, e);
                                }
                              },
                              child: const Text('Mark reviewed'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              })
              .toList(),
        );
      },
    );
  }
}

class PatientNotes extends StatelessWidget {
  final String patientId;
  const PatientNotes({super.key, required this.patientId});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('patients')
            .doc(patientId)
            .collection('notes')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, s) {
          if (s.hasError) return Text('Unable to read notes: ${s.error}');
          if (!s.hasData) return const LinearProgressIndicator();
          if (s.data!.docs.isEmpty)
            return const Text('No care-team notes yet.');
          return Column(
            children: s.data!.docs
                .map(
                  (d) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.message_outlined),
                      title: Text(d.data()['text'] as String? ?? ''),
                      subtitle: Text(dateLabel(d.data()['createdAt'])),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
}

class WorkerDashboard extends StatelessWidget {
  final String uid, name;
  const WorkerDashboard({super.key, required this.uid, required this.name});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Healthcare worker',
    signOut: true,
    children: [
      sectionTitle('Welcome, $name', subtitle: 'Patients assigned to you'),
      const Text(
        'Review patient updates. Urgent symptom reports require prompt follow-up; the app is not an emergency-response guarantee.',
      ),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('patients')
            .where('assignedWorkerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Text('Unable to load assigned patients: ${snapshot.error}');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.docs.isEmpty)
            return infoCard(
              icon: Icons.person_search,
              title: 'No assigned patients',
              description:
                  'Ask an administrator to assign a patient to your account.',
            );
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: doc.reference.collection('reports').snapshots(),
                builder: (context, r) {
                  final reports = r.data?.docs ?? [];
                  final urgent = reports
                      .where(
                        (x) =>
                            x.data()['urgency'] == 'urgent' &&
                            x.data()['status'] != 'reviewed',
                      )
                      .length;
                  final regular = reports
                      .where(
                        (x) =>
                            x.data()['urgency'] != 'urgent' &&
                            x.data()['status'] != 'reviewed',
                      )
                      .length;
                  return infoCard(
                    icon: urgent > 0
                        ? Icons.notification_important
                        : Icons.pregnant_woman,
                    title: d['name'] as String? ?? 'Patient',
                    description:
                        '${urgent > 0 ? 'URGENT $urgent • ' : ''}Routine $regular • ${d['pregnancyWeeks'] ?? 0} weeks • GDM ${d['hasGdm'] == true ? 'reported' : 'not reported'}',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientReviewScreen(
                          patientId: doc.id,
                          patientName: d['name'] as String? ?? 'Patient',
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    ],
  );
}

class PatientReviewScreen extends StatefulWidget {
  final String patientId, patientName;
  const PatientReviewScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });
  @override
  State<PatientReviewScreen> createState() => _PatientReviewScreenState();
}

class _PatientReviewScreenState extends State<PatientReviewScreen> {
  final note = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> addNote() async {
    if (note.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await db
          .collection('patients')
          .doc(widget.patientId)
          .collection('notes')
          .add({
            'text': note.text.trim(),
            'workerId': auth.currentUser!.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
      note.clear();
    } catch (e) {
      if (mounted) showProblem(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.patientName,
    children: [
      sectionTitle('Pregnancy profile'),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('patients').doc(widget.patientId).snapshots(),
        builder: (context, s) {
          if (!s.hasData) return const LinearProgressIndicator();
          final d = s.data!.data() ?? {};
          return Text(
            'Weeks: ${d['pregnancyWeeks'] ?? 'Unknown'}   •   GDM: ${d['hasGdm'] == true ? 'Reported' : 'Not reported'}\nPhone: ${d['phone'] ?? 'Not provided'}\nEmergency contact: ${d['emergencyContact'] ?? 'Not provided'}',
          );
        },
      ),
      sectionTitle('Glucose history'),
      ReadingList(patientId: widget.patientId),
      sectionTitle('URGENT CARE • warning signs'),
      ReportList(
        patientId: widget.patientId,
        canReview: true,
        urgencyFilter: 'urgent',
      ),
      sectionTitle('Regular doctor review'),
      ReportList(
        patientId: widget.patientId,
        canReview: true,
        urgencyFilter: 'needs_review',
      ),
      sectionTitle('Healthcare-worker notes'),
      TextField(
        controller: note,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Add an observation or follow-up note',
        ),
      ),
      const SizedBox(height: 9),
      FilledButton(
        onPressed: busy ? null : addNote,
        child: const Text('Save note'),
      ),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('patients')
            .doc(widget.patientId)
            .collection('notes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, s) {
          if (s.hasError) return Text('${s.error}');
          if (!s.hasData) return const LinearProgressIndicator();
          return Column(
            children: s.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  title: Text('${d['text']}'),
                  subtitle: Text(dateLabel(d['createdAt'])),
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Admin • MotherCare',
    signOut: true,
    children: [
      sectionTitle('Healthcare-worker approvals'),
      const Text(
        'Verify healthcare-worker identity and credentials outside the app before granting access.',
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .where('role', isEqualTo: 'worker_pending')
            .snapshots(),
        builder: (context, s) {
          if (s.hasError) return Text('Cannot load workers: ${s.error}');
          if (!s.hasData) return const LinearProgressIndicator();
          if (s.data!.docs.isEmpty) return const Text('No pending requests.');
          return Column(
            children: s.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  title: Text('${d['name']}'),
                  subtitle: Text(
                    '${d['email']} • ${d['hospital'] ?? ''} • ${d['registration'] ?? ''}',
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      TextButton(
                        onPressed: () async {
                          try {
                            await doc.reference.update({
                              'role': 'worker_rejected',
                            });
                          } catch (e) {
                            if (context.mounted) showProblem(context, e);
                          }
                        },
                        child: const Text('Reject'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await doc.reference.update({'role': 'worker'});
                          } catch (e) {
                            if (context.mounted) showProblem(context, e);
                          }
                        },
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      sectionTitle('Assign patients to workers'),
      const Text(
        'Only approved healthcare workers can access assigned patient data.',
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .where('role', isEqualTo: 'worker')
            .snapshots(),
        builder: (context, w) {
          if (w.hasError) return Text('${w.error}');
          if (!w.hasData) return const LinearProgressIndicator();
          final workers = w.data!.docs;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('patients').snapshots(),
            builder: (context, p) {
              if (p.hasError) return Text('${p.error}');
              if (!p.hasData) return const LinearProgressIndicator();
              if (p.data!.docs.isEmpty)
                return const Text('No patients registered yet.');
              return Column(
                children: p.data!.docs.map((patient) {
                  final d = patient.data();
                  final assigned = d['assignedWorkerId'] as String? ?? '';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['name'] as String? ?? patient.id,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey('${patient.id}-$assigned'),
                            initialValue: assigned.isEmpty
                                ? ''
                                : (workers.any((doc) => doc.id == assigned)
                                      ? assigned
                                      : ''),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Assigned worker',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Unassigned'),
                              ),
                              ...workers.map(
                                (doc) => DropdownMenuItem(
                                  value: doc.id,
                                  child: Text('${doc.data()['name']}'),
                                ),
                              ),
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              try {
                                await patient.reference.update({
                                  'assignedWorkerId': v,
                                });
                              } catch (e) {
                                if (context.mounted) showProblem(context, e);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    ],
  );
}
