// Gets a Twitch OAuth user token for emulator testing.
//
// Usage: dart run scripts/get_twitch_token.dart
//
// Reads CLIENT_ID and SECRET from .env, env vars, or prompts interactively.
// Opens the Twitch OAuth page in your browser — after you authorize,
// paste the redirect URL back here and the token is printed.
// Then long-press the Anonymous account tile in the app to log in.
import 'dart:convert';
import 'dart:io';

const scopes =
    'chat:read+chat:edit+user:read:follows+user:read:blocked_users+'
    'user:manage:blocked_users+user:manage:chat_color';
const redirectUri = 'https://twitch.tv/login';

void main() async {
  final env = _loadEnvFile();

  final clientId = _resolve('CLIENT_ID', env);
  final secret = _resolve('SECRET', env);

  if (clientId == null || secret == null) {
    stderr.writeln('Error: CLIENT_ID and SECRET are both required.');
    stderr.writeln('Add them to .env or export them in your shell.');
    exit(1);
  }

  final authorizeUrl = 'https://id.twitch.tv/oauth2/authorize'
      '?client_id=$clientId'
      '&redirect_uri=$redirectUri'
      '&response_type=code'
      '&scope=$scopes'
      '&force_verify=true';

  stdout.writeln('Opening Twitch authorization in your browser...');
  await _openUrl(authorizeUrl);

  stdout.writeln();
  stdout.writeln(
    'After authorizing, copy the full URL from the address bar and paste it here:',
  );
  stdout.writeln('(it will look like https://twitch.tv/login?code=...)');
  stdout.writeln();
  stdout.write('> ');

  final redirectUrl = stdin.readLineSync()?.trim();
  if (redirectUrl == null || redirectUrl.isEmpty) {
    stderr.writeln('No URL provided.');
    exit(1);
  }

  final uri = Uri.tryParse(redirectUrl);
  final code = uri?.queryParameters['code'];

  if (code == null || code.isEmpty) {
    stderr.writeln();
    stderr.writeln('Error: could not extract code from that URL.');
    stderr.writeln(
      'Make sure you pasted the full URL including the ?code=... part.',
    );
    exit(1);
  }

  stdout.writeln();
  stdout.writeln('Exchanging code for token...');

  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('https://id.twitch.tv/oauth2/token'),
    );
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    request.write(
      'client_id=$clientId'
      '&client_secret=$secret'
      '&code=$code'
      '&grant_type=authorization_code'
      '&redirect_uri=$redirectUri',
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    final token = json['access_token'] as String?;
    if (token == null || token.isEmpty) {
      stderr.writeln('Error: token exchange failed.');
      stderr.writeln(body);
      exit(1);
    }

    stdout.writeln();
    stdout.writeln('Token: $token');
    stdout.writeln();
    stdout.writeln(
      'Now in the emulator, long-press the Anonymous account tile to log in.',
    );
  } finally {
    client.close();
  }
}

/// Reads a value from env vars first, then .env file, then prompts.
String? _resolve(String name, Map<String, String> envFile) {
  final fromEnv = Platform.environment[name];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  final fromFile = envFile[name];
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;

  stdout.write('$name: ');
  return stdin.readLineSync()?.trim();
}

/// Parses the .env file next to this script's project root.
Map<String, String> _loadEnvFile() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final projectDir = scriptDir.parent;
  final envFile = File('${projectDir.path}/.env');

  if (!envFile.existsSync()) return {};

  final result = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq < 0) continue;
    result[trimmed.substring(0, eq)] = trimmed.substring(eq + 1);
  }
  return result;
}

/// Opens a URL in the default browser across platforms.
Future<void> _openUrl(String url) async {
  final ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('cmd', ['/c', 'start', '', url]);
  } else if (Platform.isMacOS) {
    result = await Process.run('open', [url]);
  } else {
    result = await Process.run('xdg-open', [url]);
  }
  if (result.exitCode != 0) {
    stderr.writeln('Could not open browser. Visit this URL manually:');
    stderr.writeln(url);
  }
}
