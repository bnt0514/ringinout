package com.bnt0514.ringinout.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Wi-Fi 스캔/조회 헬퍼
 *
 * Flutter MethodChannel에서 호출하여:
 * 1. 현재 연결된 Wi-Fi 정보 반환
 * 2. SSID 프리픽스 기반으로 유사 네트워크 목록 반환
 */
class WifiScanHelper(private val context: Context) {

    companion object {
        private const val TAG = "WifiScanHelper"

        /** SSID에서 5G/2G 등 대역 접미사 제거 → 프리픽스 추출 */
        fun extractSsidPrefix(ssid: String): String {
            val suffixes = listOf(
                    "_5G", "_2G", "_5g", "_2g",
                    "-5G", "-2G", "-5g", "-2g",
                    "_5GHz", "_2.4GHz", "_5ghz", "_2.4ghz",
                    "-5GHz", "-2.4GHz", "-5ghz", "-2.4ghz",
                    "_A", "_a", "-A", "-a",
                    "_guest", "_Guest", "-guest", "-Guest",
                    "_GUEST", "-GUEST",
                    "_IoT", "_iot", "-IoT", "-iot",
                    "_EXT", "_ext", "-EXT", "-ext",
            )

            var prefix = ssid
            for (suffix in suffixes) {
                if (prefix.endsWith(suffix)) {
                    prefix = prefix.removeSuffix(suffix)
                    break // 가장 먼저 매칭되는 접미사만 제거
                }
            }
            return prefix
        }
    }

    private val wifiManager by lazy {
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    }
    private val connectivityManager by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    /**
     * 현재 연결된 Wi-Fi 정보 반환
     * @return {ssid: String, bssid: String} 또는 null
     */
    fun getConnectedWifi(): Map<String, String>? {
        // 방법 1: ConnectivityManager (Android 12+)
        try {
            val activeNetwork = connectivityManager.activeNetwork
            val caps = activeNetwork?.let { connectivityManager.getNetworkCapabilities(it) }

            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                val wifiInfo = caps.transportInfo as? WifiInfo
                Log.d(TAG, "📶 ConnectivityManager wifiInfo: ssid=${wifiInfo?.ssid}, bssid=${wifiInfo?.bssid}")

                if (wifiInfo != null && wifiInfo.bssid != null) {
                    val ssid = cleanSsid(wifiInfo.ssid)
                    val bssid = wifiInfo.bssid ?: ""

                    if (ssid.isNotEmpty() && ssid != "<unknown ssid>") {
                        Log.d(TAG, "✅ ConnectivityManager로 Wi-Fi 감지: $ssid ($bssid)")
                        return mapOf(
                                "ssid" to ssid,
                                "bssid" to bssid,
                        )
                    } else {
                        Log.w(TAG, "⚠️ ConnectivityManager SSID=<unknown ssid>, WifiManager 폴백 시도")
                    }
                }
            } else {
                Log.d(TAG, "📶 ConnectivityManager: Wi-Fi transport 없음, WifiManager 폴백 시도")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ ConnectivityManager 조회 실패: ${e.message}")
        }

        // 방법 2: WifiManager 폴백 (더 넓은 호환성)
        try {
            @Suppress("DEPRECATION")
            val wifiInfo = wifiManager.connectionInfo
            Log.d(TAG, "📶 WifiManager wifiInfo: ssid=${wifiInfo?.ssid}, bssid=${wifiInfo?.bssid}, networkId=${wifiInfo?.networkId}")

            if (wifiInfo != null && wifiInfo.networkId != -1 && wifiInfo.bssid != null) {
                val ssid = cleanSsid(wifiInfo.ssid)
                val bssid = wifiInfo.bssid ?: ""

                if (ssid.isNotEmpty() && ssid != "<unknown ssid>") {
                    Log.d(TAG, "✅ WifiManager 폴백으로 Wi-Fi 감지: $ssid ($bssid)")
                    return mapOf(
                            "ssid" to ssid,
                            "bssid" to bssid,
                    )
                } else {
                    Log.w(TAG, "⚠️ WifiManager도 SSID=<unknown ssid> → 위치 권한 또는 NEARBY_WIFI_DEVICES 권한 필요")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ WifiManager 폴백 실패: ${e.message}")
        }

        Log.w(TAG, "❌ Wi-Fi 연결 감지 실패 - 권한 상태: FINE_LOCATION=${hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)}, " +
                "NEARBY_WIFI=${if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES) else "N/A(API<33)"}")
        return null
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 현재 연결된 Wi-Fi + SSID 프리픽스가 유사한 네트워크 목록
     * (Wi-Fi 스캔 결과에서 프리픽스 매칭)
     *
     * @return [{ssid, bssid, isConnected, signalLevel}]
     */
    fun getSimilarNetworks(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val seen = mutableSetOf<String>() // bssid 중복 방지

        // 1. 현재 연결된 Wi-Fi
        val connected = getConnectedWifi()
        if (connected != null) {
            result.add(mapOf(
                    "ssid" to connected["ssid"]!!,
                    "bssid" to connected["bssid"]!!,
                    "isConnected" to true,
                    "signalLevel" to 4,
            ))
            seen.add(connected["bssid"]!!)
        }

        // 2. Wi-Fi 스캔 결과에서 프리픽스 매칭
        if (connected != null) {
            val prefix = extractSsidPrefix(connected["ssid"]!!)

            if (hasWifiScanPermission()) {
                try {
                    @Suppress("DEPRECATION")
                    val scanResults = wifiManager.scanResults

                    for (scanResult in scanResults) {
                        val ssid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            scanResult.wifiSsid?.toString()?.removePrefix("\"")?.removeSuffix("\"") ?: ""
                        } else {
                            @Suppress("DEPRECATION")
                            scanResult.SSID
                        }
                        val bssid = scanResult.BSSID ?: continue

                        if (ssid.isEmpty() || seen.contains(bssid)) continue

                        val scanPrefix = extractSsidPrefix(ssid)
                        if (scanPrefix.equals(prefix, ignoreCase = true)) {
                            val level = WifiManager.calculateSignalLevel(scanResult.level, 5)
                            result.add(mapOf(
                                    "ssid" to ssid,
                                    "bssid" to bssid,
                                    "isConnected" to false,
                                    "signalLevel" to level,
                            ))
                            seen.add(bssid)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "⚠️ Wi-Fi 스캔 실패: ${e.message}")
                }
            }
        }

        Log.d(TAG, "📶 유사 네트워크: ${result.size}개 (connected=${connected != null})")
        return result
    }

    /** Wi-Fi 하드웨어 상태 */
    fun isWifiEnabled(): Boolean = wifiManager.isWifiEnabled

    private fun hasWifiScanPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(
                    context, Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
        }
        return ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun cleanSsid(rawSsid: String?): String {
        if (rawSsid == null) return ""
        return rawSsid.removePrefix("\"").removeSuffix("\"")
    }
}
