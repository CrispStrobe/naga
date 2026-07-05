import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../generated/l10n.dart';
import '../theme/naga_palette.dart';
import 'naga_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appName = 'Naga';
  static const _email = 'postmaster@crispstro.be';
  static const _provider =
      'Christian Ströbele\nNikolausstr. 5\n70190 Stuttgart\nDeutschland / Germany';
  static const _tagline = 'The Snake Game';

  static const _buildVersion = String.fromEnvironment('APP_VERSION');
  static const _gitCommit = String.fromEnvironment('GIT_COMMIT');
  static const _buildMode = String.fromEnvironment('BUILD_MODE');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: NagaPalette.menuBackground,
      appBar: AppBar(
        title: Text(s.about),
        backgroundColor: NagaPalette.menuBackground,
        foregroundColor: NagaPalette.menuDeepGreen,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AppHeader(),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.business,
            label: s.serviceProvider,
            child: const Text(_provider),
          ),
          _SectionCard(
            icon: Icons.alternate_email,
            label: s.contact,
            child: InkWell(
              onTap: () => _open('mailto:$_email'),
              child: const Text(
                _email,
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          _SectionCard(
            icon: Icons.privacy_tip_outlined,
            label: s.privacy,
            child: Text(s.privacyText),
          ),
          _SectionCard(
            icon: Icons.gavel,
            label: s.disclaimer,
            child: Text(s.disclaimerText),
          ),
          _SectionCard(
            icon: Icons.copyright,
            label: s.license,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.licenseText),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () =>
                      _open('https://www.gnu.org/licenses/agpl-3.0.html'),
                  child: const Text(
                    'https://www.gnu.org/licenses/agpl-3.0.html',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: Text(s.openSourceLicenses),
            onPressed: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              final version = _buildVersion.isNotEmpty
                  ? _buildVersion
                  : '${info.version}+${info.buildNumber}';
              showLicensePage(
                context: context,
                applicationName: _appName,
                applicationVersion: version,
                applicationLegalese:
                    '© ${DateTime.now().year} Christian Ströbele — AGPL-3.0',
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = AboutScreen._buildVersion.isNotEmpty
            ? AboutScreen._buildVersion
            : snap.hasData
                ? '${snap.data!.version} (${snap.data!.buildNumber})'
                : '…';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const NagaLogo(height: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AboutScreen._appName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${S.of(context)!.version} $v',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (AboutScreen._gitCommit.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Build ${AboutScreen._gitCommit.length > 7 ? AboutScreen._gitCommit.substring(0, 7) : AboutScreen._gitCommit}'
                          '${AboutScreen._buildMode.isNotEmpty ? ' (${AboutScreen._buildMode})' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        AboutScreen._tagline,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
