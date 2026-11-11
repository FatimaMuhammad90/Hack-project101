# MotherCare Connect — Flutter + Firebase Hackathon Prototype

An AI-assisted maternal-care **prototype**, built on the original `hack_project101` Firebase project. Chrome is the recommended development target. **No Android Studio needed for web development.**

## Features included

- Email/password sign-in and patient/healthcare-worker registration
- Healthcare-worker approval/rejection and patient assignment via administrator dashboard
- Pregnancy profile, GDM diagnosis status, weeks and emergency contact
- Glucose meter photo selection, optional Gemini digit extraction, **required manual confirmation**, reading history and photo storage
- Symptom checkboxes, free-text report, optional Gemini neutral summary, warning-sign escalation message, live reports
- Worker dashboard with assigned patients, readings, symptom review and notes
- General pregnancy-warning-sign education
- Patient-specific security rules for Firestore and Cloud Storage

**Important limits:** This is not a clinical device or an emergency response platform. There is no automatic diagnosis, no medical risk score, no guaranteed healthcare-worker availability, no push notification, and no clinician-validated triage. Emergency sign selection surfaces advice to seek immediate medical care; the user must call for help. Use **fictional demonstration records**.

## Prerequisites (Firebase Console)

Your Firebase project `hack-project101` and `lib/firebase_options.dart` are already configured. **Do not recreate the Firebase project.**

1. Firebase Console > **Authentication** > Sign-in method > enable **Email/Password**.
2. Firebase Console > **Firestore Database** > create database in your preferred region. Publish rules from `firestore.rules` **before using real data**.
3. Firebase Console > **Storage** > initialize a bucket (may require billing). Publish `storage.rules`.
4. Firebase Console > **AI Logic** > enable the **Gemini Developer API** provider. The app uses `gemini-2.5-flash` by default in `lib/services.dart`; change if the model is unavailable in your project. No AI Studio secret key is placed in the client.
5. Set up Firebase **App Check** for the web app, using the supported provider and debug tokens for local development. Test it before enabling enforcement. Firebase AI Logic and Storage may have usage quotas and billing requirements.
6. Deploy security rules using Firebase CLI:

```powershell
firebase login
firebase use hack-project101
firebase deploy --only firestore:rules,storage
```

If Firebase CLI reports that Firestore or Storage has not been initialized, complete its creation in the Console first. Do not use open/test-mode rules for sensitive data.

## Run

```powershell
cd C:\hackathon\flutter-app\hack_project101
flutter pub get
flutter run -d chrome
```

The ZIP contains the **same project folder**, so replace/merge its `lib/`, rules, and README in your checkout or unzip as a new working copy. `firebase_options.dart` is preserved from your upload. Use `flutter analyze` and `flutter test` on your machine.

## First administrator (manual, privileged bootstrap)

The public registration screen **cannot** create admin accounts. This is deliberate. Create a normal account through the app, then in **Firebase Console > Firestore > `users/{uid}`** change `role` to `admin` using your project-owner privileges. Ensure the chosen UID belongs to your own trusted account. Refresh the app; the admin dashboard should appear. Do not hand-edit a patient/worker role in client code.

## Complete end-to-end demo

1. Register your own account and promote it to admin in Firestore Console.
2. Register a second account as a healthcare worker; it starts as `worker_pending`.
3. Sign in as admin and approve that worker **only after checking their identity**.
4. Register a patient account, fill out a pregnancy profile, and submit a test glucose reading and symptom report.
5. Sign in as admin and assign the patient to the approved worker.
6. Sign in as the worker: the patient appears, along with glucose history and reports; mark a report reviewed, add a note.
7. Sign in as patient and confirm the report status and saved reading history update.

## Firestore shape

```text
users/{uid}                            name, email, role, phone
patients/{patientUid}                  profile, assignedWorkerId
patients/{patientUid}/readings/{id}    confirmed value, unit, type, optional photoPath
patients/{patientUid}/reports/{id}     selected warning signs, description, optional AI summary, urgency, status
patients/{patientUid}/notes/{id}       worker note
Storage: patients/{patientUid}/glucose/{readingId}.jpg
```

Roles: `patient`, `worker_pending`, `worker`, `worker_rejected`, `admin`. Workers can only access patients assigned by an administrator. Admins can manage assignments and account roles. Patients cannot self-assign a healthcare worker or upgrade their role.

## Gemini workflow

Photo → Firebase AI Logic → optional suggested numeric reading → **patient verifies manually** → Firestore + optional Storage photo. If AI is unavailable, manual entry still works.

Text/checkboxes → optional Gemini organization → patient checks summary → Firestore report → assigned worker's live dashboard. **Urgency flag only uses selected warning-sign checkboxes**; the app must not be treated as having reliably detected dangers in arbitrary free text. No generative model is trusted to classify emergencies.

## Known development constraints

- A missing JDK/Android Studio will block native Android builds but **not** `flutter run -d chrome`.
- Photo selection uses the browser picker; the camera action depends on browser/device support and needs testing on real phones.
- Signup is not atomic across Firebase Auth and Firestore. If a Firestore write fails during signup, an Auth account can remain without a profile; resolve it through admin support. The app does not silently invent a new role.
- Gemini provider availability, Storage bucket availability, Firestore rules deployment, and live Firebase permission tests must be performed on your Firebase project.
- Web App Check needs an explicit configuration prior to enforcement; this repository does not initialize a debug provider or embed a reCAPTCHA site key.
- The language preference is stored, but the interface and educational content are currently in English; Urdu localization and voice reporting are future work.
- Medical content needs review by qualified practitioners before any real-world deployment.

## Security and collaboration

Keep the same `firebase_options.dart` in the shared Git repository; it is Firebase client configuration, **not** a private service-account key. Never commit service-account JSON credentials. Both collaborators should be added to **this Firebase project** with only necessary IAM permissions. Share the same Firestore collection and field names.


## November 2026 workflow update

**Recommended run command on this laptop:** `flutter run -d chrome`.
Running plain `flutter run` and selecting Windows invokes the native Windows build,
which requires Windows Developer Mode for Flutter plugin symlinks and Visual Studio
Desktop development with C++. Chrome does not need either. If you intentionally
want Windows desktop, open `start ms-settings:developers`, enable Developer Mode,
and install Visual Studio with C++ desktop workload.

### Exact symptom-routing behavior

1. Patient selects warning signs, types in English/Urdu or dictates with the mic.
2. Local warning-sign checks run immediately (even before AI or without internet).
3. On submit, Gemini attempts to extract **controlled symptom codes**. Gemini does
   not decide urgency. The fixed `SymptomRules.urgentCodes` list determines urgency.
4. Selected/local signals are *merged* with AI findings; Gemini cannot remove
   a locally identified warning sign. If Gemini fails, an uncertainty flag is saved.
5. An urgent match shows a seek-care-now warning and 1122 dial action (where available).
   Its report appears under the doctor's **URGENT CARE** section.
6. Otherwise the report appears under **Regular doctor review**, marked for review,
   not medically cleared. Both queues are Firestore realtime listeners when online.
7. The healthcare worker must be approved and assigned to the patient to read it.
   New reports update the dashboard counters, **not** a guaranteed background push.

Relevant Firestore paths:
- `users/{uid}` with `role`, and worker registration/hospital details for pending approval
- `patients/{uid}` with `hasGdm`, `language`, `assignedWorkerId`
- `patients/{uid}/readings/{id}` confirmed glucose readings (GDM path)
- `patients/{uid}/reports/{id}` with `urgency`, `triageStatus`, `processingStatus`,
  `normalizedSymptoms`, `matchedWarningSigns`, `aiUsed`, `status`
- `patients/{uid}/notes/{id}` worker notes

**Scope notes:** Patient-facing Urdu is provided for key navigation and symptom
reporting; the entire UI and all educational text are not yet professionally
translated. Voice is browser/device-dependent; if the selected locale isn't
available, the app asks the patient to type. Gemini requires configured AI Logic
and internet access. Firestore native/mobile has built-in offline caching; browser
persistent caching is NOT automatically enabled due to privacy risks on shared
machines. Photo upload and AI analysis are not offline. Urgent reports cannot
reach a doctor without connectivity; the app instructs the patient to seek care
independently.

**Important before real-world use:** Clinical governance and testing are required.
The fixed warning-sign codes demonstrate a workflow, not validated diagnostic
triage. Client-side symptom logic could be modified by a malicious client; a
production deployment should recompute classification in a trusted backend
(e.g., Cloud Functions), enforce resulting fields there, and add verified push
notifications, clinical escalation and audit trails. This prototype uses fictional
data only, and do not record real CNICs in the demo database.

## Testing scenarios

- GDM false: symptom and education options shown; glucose recording hidden.
- GDM true: glucose recording shown; photo extraction asks patient to verify.
- Select `Heavy bleeding` while offline: immediate warning displays before submit.
- Submit text `I have severe headache and blurred vision`: normalized warning
  codes include severe_headache and vision_changes, urgent doctor queue.
- Submit Urdu `میرے سر میں شدید درد ہے`: local match remains urgent even if AI fails.
- Submit `I feel tired`: regular review queue, with no assertion of medical safety.
- Disconnect the network: do not assume Gemini works or that doctor received data.
- Doctor assigned to patient: urgent/routine lists update with Firestore changes.
- Unassigned doctor: should not be able to view records.

Official warning-sign reference: https://www.cdc.gov/hearher/maternal-warning-signs/index.html
