package one.dothings.enerquote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "one.dothings.enerquote/config",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getMicrosoftOAuthClientId") {
                val resId = resources.getIdentifier(
                    "microsoft_oauth_client_id",
                    "string",
                    packageName,
                )
                val id = if (resId != 0) resources.getString(resId).trim() else ""
                result.success(id)
            } else if (call.method == "getMicrosoftOAuthTenant") {
                val resId = resources.getIdentifier(
                    "microsoft_oauth_tenant",
                    "string",
                    packageName,
                )
                val tenant = if (resId != 0) resources.getString(resId).trim() else ""
                result.success(tenant)
            } else {
                result.notImplemented()
            }
        }
    }
}
