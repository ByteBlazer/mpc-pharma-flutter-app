import 'package:image_picker/image_picker.dart';

import '../../../utils/platform_device.dart';

Future<bool> probeTicketCameraAvailable(ImagePicker picker) async {
  if (!isMobileDevice) return false;
  return picker.supportsImageSource(ImageSource.camera);
}
