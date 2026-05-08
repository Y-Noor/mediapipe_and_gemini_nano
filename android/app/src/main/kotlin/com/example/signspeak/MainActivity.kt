package com.example.signspeak

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val channelName = "signspeak/gemini_nano"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var generativeModel: GenerativeModel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        generativeModel = Generation.getClient()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> checkAvailability(result)
                    "completeSentence" -> {
                        val prompt = call.argument<String>("prompt").orEmpty()
                        completeSentence(prompt, result)
                    }
                    "resetContext" -> result.success(null)
                    "close" -> {
                        generativeModel?.close()
                        generativeModel = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkAvailability(result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(ensureNanoReady(downloadIfNeeded = false))
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    private fun completeSentence(prompt: String, result: MethodChannel.Result) {
        if (prompt.isBlank()) {
            result.success("")
            return
        }

        scope.launch {
            try {
                if (!ensureNanoReady(downloadIfNeeded = true)) {
                    result.error(
                        "NANO_UNAVAILABLE",
                        "Gemini Nano is not available on this device.",
                        null
                    )
                    return@launch
                }

                val model = getGenerativeModel()
                val response = model.generateContent(
                    generateContentRequest(TextPart(prompt)) {
                        temperature = 0.2f
                        topK = 10
                        candidateCount = 1
                        maxOutputTokens = 60
                    }
                )
                result.success(response.candidates.firstOrNull()?.text?.trim().orEmpty())
            } catch (e: Exception) {
                result.error("NANO_ERROR", e.message, null)
            }
        }
    }

    private suspend fun ensureNanoReady(downloadIfNeeded: Boolean): Boolean {
        val model = getGenerativeModel()
        return when (model.checkStatus()) {
            FeatureStatus.AVAILABLE -> {
                model.warmup()
                true
            }
            FeatureStatus.DOWNLOADABLE -> {
                if (!downloadIfNeeded) return false
                downloadNano(model) && model.checkStatus() == FeatureStatus.AVAILABLE
            }
            FeatureStatus.DOWNLOADING -> false
            else -> false
        }
    }

    private suspend fun downloadNano(model: GenerativeModel): Boolean {
        var completed = false
        model.download().collect { status ->
            when (status) {
                DownloadStatus.DownloadCompleted -> completed = true
                is DownloadStatus.DownloadFailed -> throw status.e
                else -> Unit
            }
        }
        return completed
    }

    private fun getGenerativeModel(): GenerativeModel {
        val current = generativeModel
        if (current != null) return current

        return Generation.getClient().also {
            generativeModel = it
        }
    }

    override fun onDestroy() {
        generativeModel?.close()
        scope.cancel()
        super.onDestroy()
    }
}
