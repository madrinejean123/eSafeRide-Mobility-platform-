package com.example.esaferide

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.esaferide/api_key"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getGoogleMapsApiKey" -> {
					try {
						val ai = applicationContext.packageManager.getApplicationInfo(applicationContext.packageName, PackageManager.GET_META_DATA)
						val bundle = ai.metaData
						val key = bundle?.getString("com.google.android.geo.API_KEY")
						if (key != null) {
							result.success(key)
						} else {
							result.success("")
						}
					} catch (e: Exception) {
						result.success("")
					}
				}
				"getDirectionsFunctionUrl" -> {
					try {
						val ai = applicationContext.packageManager.getApplicationInfo(applicationContext.packageName, PackageManager.GET_META_DATA)
						val bundle = ai.metaData
						val url = bundle?.getString("com.esaferide.directions_url")
						if (url != null) {
							result.success(url)
						} else {
							result.success("")
						}
					} catch (e: Exception) {
						result.success("")
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
