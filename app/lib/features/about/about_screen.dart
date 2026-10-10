// features/about/about_screen.dart
// About screen for Zohal Connect according to ZOHAL_SPEC Section 13.6.
// AGPL-3.0 notice, source code link, third-party licenses, credit to Aether.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/persian.dart';
import '../../design/components/sharp_row.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  static const String repoUrl =
      'https://github.com/zohal-connect/zohal-connect';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final textSecondary =
        isDark ? ZohalTokens.darkTextSecondary : ZohalTokens.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          StringsFa.about,
          style: TextStyle(
            fontFamily: ZohalTokens.fontFamily,
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: hairline, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          children: [
            // Name block & Brand mark
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 64.0,
                      height: 64.0,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    StringsFa.appName,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 24.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    StringsFa.appDescription,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32.0),
            Container(height: 1.0, color: hairline),

            // Version Rows
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                final info = snapshot.data;
                final version =
                    info == null ? '—' : '${info.version}+${info.buildNumber}';
                final displayedVersion = Persian.toPersianDigits(version);
                final rowStyle = TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 14.0,
                  color: textPrimary,
                );
                return Column(
                  children: [
                    SharpRow(
                      title: StringsFa.aboutVersion,
                      trailing: Text(displayedVersion, style: rowStyle),
                    ),
                    SharpRow(
                      title: StringsFa.aboutEngineVersion,
                      trailing: Text(displayedVersion, style: rowStyle),
                    ),
                  ],
                );
              },
            ),

            // AGPL Notice
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                StringsFa.aboutAgplNotice,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 13.0,
                  height: 1.6,
                  color: textSecondary,
                ),
              ),
            ),

            Container(height: 1.0, color: hairline),

            // Source code link
            SharpRow(
              title: StringsFa.aboutSourceCode,
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () async {
                final uri = Uri.parse(repoUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),

            // Open Source Licenses
            SharpRow(
              title: StringsFa.aboutOpenSourceLicenses,
              trailing: Icon(
                Icons.arrow_back_ios_new_sharp,
                size: 12.0,
                color: textSecondary,
              ),
              onTap: () async {
                final info = await _packageInfo;
                if (!context.mounted) return;
                showLicensePage(
                  context: context,
                  applicationName: StringsFa.appName,
                  applicationVersion: Persian.toPersianDigits(info.version),
                );
              },
            ),

            const SizedBox(height: 24.0),

            // Upstream Credit Line
            Center(
              child: Text(
                StringsFa.aboutCreditLine,
                style: TextStyle(
                  fontFamily: ZohalTokens.fontFamily,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
