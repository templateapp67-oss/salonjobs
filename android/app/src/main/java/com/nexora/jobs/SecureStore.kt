package com.nexora.jobs

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Auth tokens and drafts encrypted using a device-bound Android Keystore key. */
class SecureStore(context: Context) {
 private val prefs = context.getSharedPreferences("nexora.encrypted", Context.MODE_PRIVATE)
 private val alias = "nexora.jobs.session.v1"
 @Synchronized private fun key(): SecretKey {
  val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
  (ks.getKey(alias,null) as? SecretKey)?.let { return it }
  return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {
   init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
  }.generateKey()
 }
 fun read(name: String): String? = runCatching {
  val bytes = Base64.decode(prefs.getString(name,null) ?: return null,Base64.NO_WRAP)
  val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,bytes.copyOfRange(0,12)))
  String(cipher.doFinal(bytes.copyOfRange(12,bytes.size)),Charsets.UTF_8)
 }.getOrNull()
 fun write(name: String, value: String?) {
  if(value==null){prefs.edit().remove(name).apply();return}
  val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key())
  prefs.edit().putString(name,Base64.encodeToString(cipher.iv+cipher.doFinal(value.toByteArray(Charsets.UTF_8)),Base64.NO_WRAP)).apply()
 }
}
