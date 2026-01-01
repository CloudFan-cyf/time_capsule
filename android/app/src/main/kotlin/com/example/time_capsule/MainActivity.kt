package com.example.time_capsule

import android.app.PendingIntent
import android.content.ContentUris
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  private val CHANNEL = "time_capsule/file_ops"
  private val REQ_DELETE = 7011

  private var pendingResult: MethodChannel.Result? = null
  private var pendingUris: List<Uri> = emptyList()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "deleteUris" -> {
            val list = call.argument<List<String>>("uris") ?: emptyList()
            val uris = list.mapNotNull { runCatching { Uri.parse(it) }.getOrNull() }
            deleteUrisInternal(uris, result)
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun deleteUrisInternal(uris: List<Uri>, result: MethodChannel.Result) {
    if (uris.isEmpty()) {
      result.success(emptyMap<String, Boolean>())
      return
    }

    // 1) 先把 media documents 的 document URI 转成 MediaStore 行 URI（带具体ID）
    val normalized = uris.map { u -> normalizeToMediaStoreRowUriIfPossible(u) ?: u }

    // 2) 先尝试直接 delete（有些 URI 直接能删）
    val directMap = linkedMapOf<String, Boolean>()
    val needUserAction = mutableListOf<Uri>()

    for (u in normalized) {
      try {
        val rows = contentResolver.delete(u, null, null)
        val ok = rows > 0
        directMap[u.toString()] = ok
        if (!ok) needUserAction.add(u)
      } catch (se: SecurityException) {
        directMap[u.toString()] = false
        needUserAction.add(u)
      } catch (_: Exception) {
        directMap[u.toString()] = false
      }
    }

    if (needUserAction.isEmpty()) {
      result.success(directMap)
      return
    }

    // 3) API30+ 用 createDeleteRequest，但它必须是“具体ID的 MediaStore 行URI”
    if (Build.VERSION.SDK_INT >= 30) {
      // 只把“确认为 MediaStore 行 URI”的放进去，不是的就别传，否则还是会抛 IllegalArgumentException
      val mediaRowUris = needUserAction.filter { isMediaStoreRowUri(it) }

      if (mediaRowUris.isEmpty()) {
        // 没有可走 createDeleteRequest 的项，直接返回当前结果（表示删不了）
        result.success(directMap)
        return
      }

      if (pendingResult != null) {
        result.error("BUSY", "Another delete request is pending", null)
        return
      }

      pendingResult = result
      pendingUris = mediaRowUris.toList()

      val pi: PendingIntent =
        MediaStore.createDeleteRequest(contentResolver, pendingUris)

      startIntentSenderForResult(
        pi.intentSender,
        REQ_DELETE,
        null,
        0,
        0,
        0,
        null
      )
      return
    }

    // API < 30：先直接返回（如需支持 29 的 RecoverableSecurityException 再补）
    result.success(directMap)
  }

  private fun normalizeToMediaStoreRowUriIfPossible(uri: Uri): Uri? {
    // 只处理 com.android.providers.media.documents 这种 “媒体文档提供者”
    if (!DocumentsContract.isDocumentUri(this, uri)) return null
    if (uri.authority != "com.android.providers.media.documents") return null

    val docId = DocumentsContract.getDocumentId(uri) // e.g. "image:36"
    val parts = docId.split(":")
    if (parts.size != 2) return null

    val type = parts[0] // image / video / audio
    val id = parts[1].toLongOrNull() ?: return null

    val base = when (type) {
      "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
      "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
      "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
      else -> return null
    }

    return ContentUris.withAppendedId(base, id)
  }

  private fun isMediaStoreRowUri(uri: Uri): Boolean {
    // createDeleteRequest 要求 items referenced by specific ID
    // 一般来说：authority == "media" 且 path 含 /images/media/<id> 等
    if (uri.authority != "media") return false
    val seg = uri.pathSegments
    if (seg.isNullOrEmpty()) return false
    // 简单判断最后一段是数字ID
    return seg.lastOrNull()?.toLongOrNull() != null
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)

    if (requestCode != REQ_DELETE) return

    val res = pendingResult ?: return
    val uris = pendingUris
    pendingResult = null
    pendingUris = emptyList()

    val out = linkedMapOf<String, Boolean>()
    val ok = (resultCode == RESULT_OK)

    for (u in uris) {
      if (!ok) {
        out[u.toString()] = false
        continue
      }
      try {
        val rows = contentResolver.delete(u, null, null)
        out[u.toString()] = (rows > 0)
      } catch (_: Exception) {
        out[u.toString()] = true
      }
    }

    res.success(out)
  }
}
