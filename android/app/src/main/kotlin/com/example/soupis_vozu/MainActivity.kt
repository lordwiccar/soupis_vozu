package com.example.soupis_vozu

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.soupis_vozu/email"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendEmail") {
                val to = call.argument<String>("to") ?: ""
                val cc = call.argument<String>("cc") ?: ""
                val subject = call.argument<String>("subject") ?: ""
                val body = call.argument<String>("body") ?: ""

                // Vytvoření nativního Android Intentu pro odeslání e-mailu
                val intent = Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("mailto:") // Omezí výběr pouze na e-mailové klienty
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(to)) // Toto s jistotou vyplní pole "Komu"
                    if (cc.isNotEmpty()) {
                        putExtra(Intent.EXTRA_CC, arrayOf(cc)) // Přidá příjemce do Kopie
                    }
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    putExtra(Intent.EXTRA_TEXT, body)
                }

                try {
                    // Čisté jednosměrné odeslání bez sledování výsledku
                    startActivity(Intent.createChooser(intent, "Odeslat soupis pomocí..."))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Nebyl nalezen žádný e-mailový klient.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}