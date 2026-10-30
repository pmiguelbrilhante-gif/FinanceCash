// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> salvarArquivo(Uint8List bytes, String nome) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  html.AnchorElement(href: url)
    ..setAttribute('download', nome)
    ..click();
    
  html.Url.revokeObjectUrl(url);
  return 'download_iniciado';
}