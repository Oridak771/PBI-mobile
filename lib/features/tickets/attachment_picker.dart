import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_palette.dart';
import '../../data/models/ticket.dart';

enum AttachmentSource { camera, gallery }

/// Picks an image for a ticket / message attachment (overridden in tests).
abstract class TicketImagePicker {
  /// `null` when the user cancels.
  Future<TicketAttachment?> pick(AttachmentSource source);
}

/// `image_picker`: Android photo picker (no storage permission) or the
/// camera app. Large photos are downscaled / recompressed so they usually fit
/// the 5 MB limit.
class PlatformTicketImagePicker implements TicketImagePicker {
  PlatformTicketImagePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<TicketAttachment?> pick(AttachmentSource source) async {
    final file = await _picker.pickImage(
      source: source == AttachmentSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return TicketAttachment(
      bytes: bytes,
      filename: attachmentFilename(file.name),
    );
  }
}

/// Keeps an image extension the server accepts (Django `ImageField`).
String attachmentFilename(String name) {
  final clean = name.trim().isEmpty ? 'image.jpg' : name.trim();
  final lower = clean.toLowerCase();
  const ok = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];
  return ok.any(lower.endsWith) ? clean : '$clean.jpg';
}

final ticketImagePickerProvider = Provider<TicketImagePicker>(
  (ref) => PlatformTicketImagePicker(),
);

/// "Appareil photo" / "Galerie" bottom sheet.
Future<AttachmentSource?> chooseAttachmentSource(BuildContext context) =>
    showModalBottomSheet<AttachmentSource>(
      context: context,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: palette.primaryText,
                ),
                title: const Text('Appareil photo'),
                onTap: () =>
                    Navigator.pop(sheetContext, AttachmentSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: palette.primaryText,
                ),
                title: const Text('Galerie'),
                onTap: () =>
                    Navigator.pop(sheetContext, AttachmentSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
