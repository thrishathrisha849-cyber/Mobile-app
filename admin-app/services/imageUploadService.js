// Image validation, compression, and Storage upload for the AI Content Creation
// Assistant. Reuses the multer-memory-storage + Supabase Storage pattern already
// established by the existing /api/upload route in server.js.

const sharp = require('sharp');

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_RAW_BYTES = 8 * 1024 * 1024; // 8MB
const COMPRESSED_TARGET_BYTES = 2 * 1024 * 1024; // 2MB
const MAX_DIMENSION = 1600; // longest edge

class ImageValidationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function validateImage(file) {
  if (!file) return;
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    throw new ImageValidationError('invalid_image_type', 'Please attach a JPG, PNG, or WEBP image.');
  }
  if (file.size > MAX_RAW_BYTES) {
    throw new ImageValidationError('image_too_large', 'That image is too large. Please attach an image under 8MB.');
  }
}

/**
 * Compresses the image toward the target size/dimension, then uploads the
 * compressed bytes to the `ai-content` bucket and returns both the public URL
 * (for persistence in ai_messages) and the base64 payload (for the immediate
 * Claude vision call, avoiding a second round trip to fetch it back).
 */
async function processAndUploadImage(supabase, { file, userId, conversationId, messageId }) {
  validateImage(file);

  let quality = 80;
  let compressed = await sharp(file.buffer)
    .resize({ width: MAX_DIMENSION, height: MAX_DIMENSION, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality })
    .toBuffer();

  while (compressed.length > COMPRESSED_TARGET_BYTES && quality > 40) {
    quality -= 15;
    compressed = await sharp(file.buffer)
      .resize({ width: MAX_DIMENSION, height: MAX_DIMENSION, fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality })
      .toBuffer();
  }

  const storagePath = `${userId}/${conversationId}/${messageId}.jpg`;
  const { error: uploadError } = await supabase.storage
    .from('ai-content')
    .upload(storagePath, compressed, { contentType: 'image/jpeg', cacheControl: '3600', upsert: true });

  if (uploadError) {
    throw new ImageValidationError('server_error', 'Could not upload the image. Please try again.');
  }

  const { data: publicData } = supabase.storage.from('ai-content').getPublicUrl(storagePath);

  return {
    publicUrl: publicData.publicUrl,
    base64: compressed.toString('base64'),
    mimeType: 'image/jpeg',
  };
}

/** Deletes every object under a conversation's folder (cascade on conversation delete). */
async function deleteConversationImages(supabase, { userId, conversationId }) {
  const folder = `${userId}/${conversationId}`;
  const { data: files } = await supabase.storage.from('ai-content').list(folder);
  if (!files || files.length === 0) return;
  const paths = files.map((f) => `${folder}/${f.name}`);
  await supabase.storage.from('ai-content').remove(paths);
}

module.exports = { validateImage, processAndUploadImage, deleteConversationImages, ImageValidationError };
