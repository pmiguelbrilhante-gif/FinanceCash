import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> salvarArquivo(Uint8List bytes, String nome) async {
  return FilePicker.platform.saveFile(
    dialogTitle: 'Salvar relatório FinanceCash',
    fileName: nome,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    bytes: bytes,
  );
}