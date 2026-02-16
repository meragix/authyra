# 🚀 Guide de Setup - Google OAuth2 (Sans SDK)

## 📋 Prérequis

- Flutter SDK ≥ 3.10.0
- Un projet Google Cloud avec OAuth 2.0 configuré
- Package `app_links` ou `uni_links` pour les deep links

---

## 🔧 Étape 1: Ajouter les Dépendances

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Authyra
  authyra_core:
    path: ../packages/authyra
  
  # Pour OAuth2 (déjà dans authyra_core)
  dio: ^5.4.0
  crypto: ^3.0.3
  url_launcher: ^6.2.4
  
  # Deep links
  app_links: ^3.5.0  # Recommandé
  # OU
  uni_links: ^0.5.1  # Alternative
```

---

## 🌐 Étape 2: Configuration Google Cloud Console

### A. Créer les Credentials OAuth 2.0

1. Aller sur [Google Cloud Console](https://console.cloud.google.com)
2. Sélectionner votre projet (ou en créer un)
3. Aller dans **APIs & Services** → **Credentials**
4. Cliquer **Create Credentials** → **OAuth 2.0 Client ID**

### B. Configurer les Platforms

#### **Android**

1. Type: **Android**
2. Name: `Your App Name (Android)`
3. Package name: `com.example.yourapp` (depuis `android/app/build.gradle`)
4. SHA-1: Obtenir avec:

   ```bash
   # Debug SHA-1
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # Production SHA-1 (depuis votre keystore)
   keytool -list -v -keystore /path/to/your-keystore.jks -alias your-key-alias
   ```

5. Copier le **Client ID** généré

#### **iOS**

1. Type: **iOS**
2. Name: `Your App Name (iOS)`
3. Bundle ID: Depuis `ios/Runner.xcodeproj/project.pbxproj`
4. Copier le **Client ID** généré

#### **Web** (si besoin)

1. Type: **Web application**
2. Authorized redirect URIs:
   - `http://localhost` (pour dev)
   - `https://yourdomain.com/oauth2redirect` (pour prod)

### C. Note Important

Le **Redirect URI** pour mobile sera auto-généré au format:

```bash
com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2redirect
```

---

## 📱 Étape 3: Configuration Android

### A. android/app/build.gradle

```gradle
android {
    defaultConfig {
        applicationId "com.example.yourapp"  // Doit correspondre à Google Console
        // ...
    }
}
```

### B. android/app/src/main/AndroidManifest.xml

```xml
<manifest>
    <application>
        <activity android:name=".MainActivity">
            
            <!-- Vos intent filters existants -->
            
            <!-- OAuth2 Deep Link -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                
                <!-- Format Google: com.googleusercontent.apps.CLIENT_ID:/oauth2redirect -->
                <data
                    android:scheme="com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID"
                    android:host="oauth2redirect" />
            </intent-filter>
            
        </activity>
    </application>
</manifest>
```

⚠️ **IMPORTANT**: Remplacer `YOUR_GOOGLE_CLIENT_ID` par votre vrai Client ID (sans le `.apps.googleusercontent.com`)

---

## 🍎 Étape 4: Configuration iOS

### A. ios/Runner/Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Vos configurations existantes -->
    
    <!-- OAuth2 URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- Format Google -->
                <string>com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID</string>
            </array>
        </dict>
    </array>
    
    <!-- Pour iOS 9+ (ouvrir navigateur) -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>https</string>
        <string>http</string>
    </array>
</dict>
</plist>
```

⚠️ **IMPORTANT**: Remplacer `YOUR_GOOGLE_CLIENT_ID` par votre vrai Client ID

---

## 💻 Étape 5: Code Flutter

### A. Initialiser Authyra (main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:authyra/authyra.dart';
import 'package:authyra/oauth2.dart';
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Authyra
  await Authyra.initialize(
    config: AuthConfig(storage: SecureStorage()),
  );

  // 2. Create Google provider
  const googleClientId = 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  
  final googleProvider = GoogleOAuth2Provider(
    clientId: googleClientId,
    // redirectUri est auto-généré
  );

  // 3. Register provider
  Authyra.instance.registerProvider('google', googleProvider);

  // 4. Register callback handler
  final scheme = 'com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID';
  OAuth2CallbackHandler.registerProvider(scheme, googleProvider);

  runApp(const MyApp());
}
```

### B. Setup Deep Links

```dart
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle initial link (if app was closed)
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) {
      OAuth2CallbackHandler.handleCallback(initialUri);
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        OAuth2CallbackHandler.handleCallback(uri);
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<AuthSession?>(
        stream: Authyra.instance.sessionStream,
        builder: (context, snapshot) {
          final session = snapshot.data;
          return session == null ? LoginPage() : HomePage();
        },
      ),
    );
  }
}
```

### C. Sign In

```dart
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              final user = await Authyra.instance.signIn('google');
              print('✅ Signed in: ${user.email}');
            } catch (e) {
              print('❌ Error: $e');
            }
          },
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
```

---

## 🧪 Étape 6: Tester

### A. Vérifier la Configuration

```bash
# Android
flutter run --debug

# iOS
flutter run --debug

# Vérifier les logs
flutter logs
```

### B. Flow de Test

1. **Cliquer sur "Sign in with Google"**
   - ✅ Le navigateur s'ouvre avec la page Google
   - ✅ URL contient votre client_id
   - ✅ URL contient code_challenge (PKCE)

2. **Choisir un compte Google**
   - ✅ Écran de consentement s'affiche
   - ✅ Scopes demandés sont visibles

3. **Accepter les permissions**
   - ✅ Redirection vers l'app
   - ✅ Deep link capturé
   - ✅ Token échangé
   - ✅ User info récupéré
   - ✅ Session créée

4. **Vérifier le Résultat**

   ```dart
   final user = await Authyra.instance.getUser();
   print('Name: ${user?.name}');
   print('Email: ${user?.email}');
   print('Avatar: ${user?.avatarUrl}');
   ```

---

## 🐛 Troubleshooting

### Problème 1: "redirect_uri_mismatch"

**Cause**: Le redirect URI ne correspond pas à celui configuré dans Google Console.

**Solution**:

1. Vérifier que le Client ID dans le code correspond à celui de Google Console
2. Le format doit être exactement: `com.googleusercontent.apps.CLIENT_ID:/oauth2redirect`
3. Android: Vérifier le SHA-1 dans Google Console
4. iOS: Vérifier le Bundle ID

### Problème 2: Deep link ne fonctionne pas

**Android**:

```bash
# Tester manuellement le deep link
adb shell am start -W -a android.intent.action.VIEW \
  -d "com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2redirect?code=test"
```

**iOS**:

```bash
# Vérifier que le scheme est enregistré
xcrun simctl openurl booted "com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2redirect?code=test"
```

### Problème 3: "Error 400: invalid_request"

**Cause**: Paramètres OAuth manquants ou invalides.

**Solution**:

1. Activer les logs:

   ```dart
   AuthyraLogger.configure(LoggerConfig(
     enabled: true,
     minLevel: LogLevel.debug,
   ));
   ```

2. Vérifier les logs pour voir la requête complète
3. Comparer avec la [documentation Google OAuth2](https://developers.google.com/identity/protocols/oauth2/native-app)

### Problème 4: Token refresh échoue

**Cause**: `access_type: offline` non configuré ou refresh_token non reçu.

**Solution**:

```dart
GoogleOAuth2Provider(
  clientId: 'YOUR_CLIENT_ID',
  // Ces paramètres forcent l'obtention d'un refresh token
  // (déjà inclus dans GoogleOAuth2Provider par défaut)
);
```

---

## 📊 Logs de Debug

### Activer les Logs Détaillés

```dart
void main() async {
  // Activer le logging avant initialize
  AuthyraLogger.configure(LoggerConfig(
    enabled: true,
    minLevel: LogLevel.debug,
    showTimestamp: true,
  ));

  await Authyra.initialize(
    config: AuthConfig(storage: SecureStorage()),
  );
  
  // ...
}
```

### Logs Attendus

```zsh
✅ Logs de succès:
[14:23:45] 🔍 [DEBUG] [OAuth2Provider] PKCE enabled - code verifier generated
[14:23:45] 🔍 [DEBUG] [OAuth2Provider] Authorization URL built
[14:23:45] 🔍 [DEBUG] [OAuth2Provider] Opening authorization URL...
[14:23:50] 🔍 [DEBUG] [OAuth2Provider] Received callback from OAuth provider
[14:23:50] 🔍 [DEBUG] [OAuth2Provider] State verified successfully
[14:23:50] 🔍 [DEBUG] [OAuth2Provider] Authorization code received
[14:23:51] 🔍 [DEBUG] [OAuth2Provider] Exchanging authorization code for tokens
[14:23:52] 🔍 [DEBUG] [OAuth2Provider] Tokens received from provider
[14:23:52] 🔍 [DEBUG] [OAuth2Provider] Fetching user information
[14:23:53] 🔍 [DEBUG] [OAuth2Provider] User info fetched successfully
[14:23:53] ℹ️ [INFO] [OAuth2Provider] OAuth2 sign in successful for google
```

---

## ✅ Checklist de Validation

- [ ] Client ID obtenu depuis Google Cloud Console
- [ ] Client ID correctement configuré dans le code
- [ ] AndroidManifest.xml mis à jour avec le bon scheme
- [ ] Info.plist (iOS) mis à jour avec le bon scheme
- [ ] Package `app_links` ajouté aux dépendances
- [ ] Deep link handler initialisé dans main.dart
- [ ] Logs de debug activés
- [ ] Test sur Android réussi
- [ ] Test sur iOS réussi
- [ ] User info correctement récupéré
- [ ] Refresh token reçu (si `access_type: offline`)

---

## 🎉 Prochaines Étapes

Une fois Google fonctionnel:

1. ✅ Tester le refresh token
2. ✅ Ajouter GitHub OAuth2
3. ✅ Ajouter Facebook OAuth2
4. ✅ Créer des tests unitaires
5. ✅ Documenter les autres providers

---

**Besoin d'aide ?** Consulter les [exemples complets](../examples/oauth2_example) ou ouvrir une issue sur GitHub.
