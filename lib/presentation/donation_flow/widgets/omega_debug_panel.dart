import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/donation_header_data.dart';

class OmegaDebugPanel extends StatelessWidget {
  final String? videoId;
  final String? performerId;
  final DonationHeaderData? headerData;
  final String? error;
  final VoidCallback onClose;

  const OmegaDebugPanel({
    Key? key,
    this.videoId,
    this.performerId,
    this.headerData,
    this.error,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'OMEGA DIAGNOSTICS',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                ],
              ),
              const Divider(color: Colors.greenAccent),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route Arguments
                      _buildSection(
                        'ROUTE ARGUMENTS',
                        [
                          'videoId: ${videoId ?? 'NULL'}',
                          'performerId: ${performerId ?? 'NULL'}',
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Header Data
                      if (headerData != null)
                        _buildSection(
                          'LOADED DATA',
                          [
                            'display_name: ${headerData!.displayName}',
                            'handle: ${headerData!.handle}',
                            'avatar_url: ${headerData!.avatarUrl ?? 'NULL'}',
                            'location: ${headerData!.location ?? 'NULL'}',
                            'thumbnail: ${headerData!.thumbnailUrl ?? 'NULL'}',
                          ],
                        )
                      else
                        _buildSection(
                          'LOADED DATA',
                          ['No data loaded yet'],
                        ),

                      const SizedBox(height: 16),

                      // Error
                      if (error != null)
                        _buildSection(
                          'ERROR',
                          [error!],
                          color: Colors.redAccent,
                        ),

                      const SizedBox(height: 16),

                      // Status
                      _buildSection(
                        'STATUS',
                        [
                          'Args valid: ${videoId != null && performerId != null ? 'YES' : 'NO'}',
                          'Data loaded: ${headerData != null ? 'YES' : 'NO'}',
                          'Has error: ${error != null ? 'YES' : 'NO'}',
                        ],
                        color: _getStatusColor(),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      ElevatedButton.icon(
                        onPressed: () => _copyDiagnostics(context),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Diagnostics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> lines, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color ?? Colors.cyanAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        ...lines.map((line) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                line,
                style: TextStyle(
                  color: color ?? Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            )),
      ],
    );
  }

  Color _getStatusColor() {
    if (error != null) return Colors.redAccent;
    if (headerData != null) return Colors.greenAccent;
    return Colors.orangeAccent;
  }

  void _copyDiagnostics(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('OMEGA DIAGNOSTICS');
    buffer.writeln('================');
    buffer.writeln('');
    buffer.writeln('ROUTE ARGUMENTS:');
    buffer.writeln('  videoId: $videoId');
    buffer.writeln('  performerId: $performerId');
    buffer.writeln('');
    
    if (headerData != null) {
      buffer.writeln('LOADED DATA:');
      buffer.writeln('  display_name: ${headerData!.displayName}');
      buffer.writeln('  handle: ${headerData!.handle}');
      buffer.writeln('  avatar_url: ${headerData!.avatarUrl}');
      buffer.writeln('  location: ${headerData!.location}');
      buffer.writeln('  thumbnail: ${headerData!.thumbnailUrl}');
      buffer.writeln('');
    }
    
    if (error != null) {
      buffer.writeln('ERROR:');
      buffer.writeln('  $error');
      buffer.writeln('');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
