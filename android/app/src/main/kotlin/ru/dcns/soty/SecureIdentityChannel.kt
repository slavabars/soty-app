package ru.dcns.soty

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/**
 * Stores the identity seeds encrypted with an AES-256-GCM key held by the
 * Android Keystore. The key material never leaves the keystore; only the
 * ciphertext and its IV are kept in private SharedPreferences.
 *
 * Seeds are the whole identity: copying them means reading and sending as
 * their owner, so they must not sit in a plain SQLite file that a backup or a
 * rooted shell can read.
 */
class SecureIdentityChannel(private val context: Context) {
    companion object {
        const val CHANNEL = "ru.dcns.soty/secure_identity"

        private const val KEY_ALIAS = "soty.identity.v1"
        private const val PREFS = "soty_secure_identity"
        private const val PREF_KEY = "identity"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val TAG_BITS = 128

        /** Exactly one 32-byte seed, lowercase hex. */
        private val SEED = Regex("^[0-9a-f]{64}$")
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "available" -> result.success(true)
                "read" -> result.success(read())
                "write" -> {
                    val ed = call.argument<String>("edSeedHex")
                    val x = call.argument<String>("xSeedHex")
                    if (ed == null || x == null ||
                        !SEED.matches(ed) || !SEED.matches(x)
                    ) {
                        result.error(
                            "bad_seed",
                            "seed must be 64 lowercase hex characters",
                            null,
                        )
                        return
                    }
                    write(ed, x)
                    result.success(null)
                }
                "clear" -> {
                    clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            // Class name only: a message could echo key material.
            result.error("keystore", error.javaClass.simpleName, null)
        }
    }

    private fun read(): Map<String, String>? {
        val blob = prefs().getString(PREF_KEY, null) ?: return null
        val parts = blob.split(':')
        if (parts.size != 2) {
            throw IllegalStateException("corrupt identity blob")
        }
        val iv = Base64.decode(parts[0], Base64.NO_WRAP)
        val data = Base64.decode(parts[1], Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            secretKey(),
            GCMParameterSpec(TAG_BITS, iv),
        )
        val json = JSONObject(String(cipher.doFinal(data), Charsets.UTF_8))
        val ed = json.getString("edSeedHex")
        val x = json.getString("xSeedHex")
        if (!SEED.matches(ed) || !SEED.matches(x)) {
            throw IllegalStateException("corrupt identity payload")
        }
        return mapOf("edSeedHex" to ed, "xSeedHex" to x)
    }

    private fun write(edSeedHex: String, xSeedHex: String) {
        val payload = JSONObject()
            .put("edSeedHex", edSeedHex)
            .put("xSeedHex", xSeedHex)
            .toString()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val data = cipher.doFinal(payload.toByteArray(Charsets.UTF_8))
        val blob = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) +
            ":" + Base64.encodeToString(data, Base64.NO_WRAP)
        // commit(), not apply(): the caller wipes the database copy right
        // after this returns, so the write must already be on disk.
        val written = prefs().edit().putString(PREF_KEY, blob).commit()
        if (!written) {
            throw IllegalStateException("identity prefs not written")
        }
    }

    private fun clear() {
        prefs().edit().remove(PREF_KEY).commit()
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (store.containsAlias(KEY_ALIAS)) {
            store.deleteEntry(KEY_ALIAS)
        }
    }

    private fun prefs() =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun secretKey(): SecretKey {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val existing = store.getEntry(KEY_ALIAS, null)
        if (existing is KeyStore.SecretKeyEntry) {
            return existing.secretKey
        }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE,
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                // The messenger must read the identity on boot, before any
                // user interaction: a per-use auth requirement would make the
                // app unable to decrypt until the phone is unlocked by hand.
                .setUserAuthenticationRequired(false)
                .build(),
        )
        return generator.generateKey()
    }
}
