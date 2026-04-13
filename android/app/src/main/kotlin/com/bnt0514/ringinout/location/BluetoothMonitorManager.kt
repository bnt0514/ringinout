package com.bnt0514.ringinout.location

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * 블루투스 기반 장소 감지 + 독립형 기기 알람 매니저
 *
 * - ACTION_ACL_CONNECTED / ACTION_ACL_DISCONNECTED로 BT 연결/해제 감지
 * - Classic BT + BLE 모두 동작 (ACL은 transport-agnostic)
 * - 연속 시간 기반 디바운스: 15초 연속 끊김 → EXIT / 15초 연속 연결 → ENTER
 * - SmartLocationManager를 통해 Flutter로 신호 전달
 *
 * 두 가지 모드:
 * 1) 장소 종속형: 장소에 등록된 BT 기기 MAC 매칭 → place ENTER/EXIT
 * 2) 독립형 기기 알람: macAddress 기반 connect/disconnect 이벤트 → 개별 기기 알람
 */
class BluetoothMonitorManager(private val context: Context) {

    companion object {
        private const val TAG = "BluetoothMonitorMgr"

        // 디바운스: 15초 연속 끊김/연결 시 EXIT/ENTER 확정
        private const val DEBOUNCE_DURATION_MS = 15000L
    }

    // ========== 콜백 ==========

    /** 장소 종속형: 블루투스 기반 장소 진입/진출 콜백: (placeId, isEnter) */
    var onBluetoothPlaceEvent: ((String, Boolean) -> Unit)? = null

    /** 독립형: 블루투스 기기 연결/해제 콜백: (macAddress, deviceName, isConnected) */
    var onBluetoothDeviceEvent: ((String, String, Boolean) -> Unit)? = null

    // ========== 상태 ==========

    private var isMonitoring = false
    private var alarmPlaces = listOf<AlarmPlace>()

    /** 독립형 기기 알람에서 감시할 MAC 주소 목록 */
    private var deviceAlarmMacAddresses = mutableSetOf<String>()

    /** 현재 연결된 BT MAC → 매칭된 placeId 목록 */
    private val connectedPlaceIds = mutableSetOf<String>()

    /** EXIT 디바운스: placeId → 단일 타이머 Runnable */
    private val mainHandler = Handler(Looper.getMainLooper())
    private val exitDebounceRunnables = mutableMapOf<String, Runnable>()

    /** ENTER 디바운스: placeId → 단일 타이머 Runnable */
    private val enterDebounceRunnables = mutableMapOf<String, Runnable>()

    /** 독립형 기기 EXIT 디바운스: macAddress → Runnable */
    private val deviceExitDebounceRunnables = mutableMapOf<String, Runnable>()

    /** 독립형 기기 ENTER 디바운스: macAddress → Runnable */
    private val deviceEnterDebounceRunnables = mutableMapOf<String, Runnable>()

    /** 현재 연결된 독립형 기기 MAC */
    private val connectedDeviceMacs = mutableSetOf<String>()

    // ========== 시스템 서비스 ==========

    private val bluetoothManager by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    }
    private val bluetoothAdapter: BluetoothAdapter? get() = bluetoothManager?.adapter

    // ========== 시작/중지 ==========

    /**
     * BT 모니터링 시작
     * @param places 장소 종속형 알람 장소 목록
     * @param deviceMacAddresses 독립형 기기 알람 MAC 주소 목록
     */
    fun startMonitoring(
        places: List<AlarmPlace>,
        deviceMacAddresses: Set<String> = emptySet()
    ) {
        if (isMonitoring) {
            updatePlaces(places, deviceMacAddresses)
            return
        }

        // BLUETOOTH_CONNECT 권한 체크 (Android 12+)
        if (!hasBluetoothPermission()) {
            Log.w(TAG, "⚠️ BLUETOOTH_CONNECT 권한 없음 — BT 모니터링 건너뜀")
            return
        }

        if (bluetoothAdapter == null) {
            Log.w(TAG, "⚠️ BluetoothAdapter 없음 — BT 모니터링 건너뜀")
            return
        }

        alarmPlaces = places.filter { it.bluetoothDevices.isNotEmpty() }
        deviceAlarmMacAddresses = deviceMacAddresses.map { it.uppercase() }.toMutableSet()

        if (alarmPlaces.isEmpty() && deviceAlarmMacAddresses.isEmpty()) {
            Log.d(TAG, "🔵 BT 등록된 장소/기기 없음 — BT 모니터링 건너뜀")
            return
        }

        Log.d(TAG, "🔵 BT 모니터링 시작: ${alarmPlaces.size}개 장소, ${deviceAlarmMacAddresses.size}개 독립 기기")
        for (place in alarmPlaces) {
            Log.d(TAG, "   - ${place.name}: ${place.bluetoothDevices.map { "${it.name}(${it.macAddress})" }}")
        }
        if (deviceAlarmMacAddresses.isNotEmpty()) {
            Log.d(TAG, "   - 독립 기기: $deviceAlarmMacAddresses")
        }

        isMonitoring = true

        // ACL BroadcastReceiver 등록
        registerAclReceiver()

        // BT 하드웨어 ON/OFF 리시버 등록
        registerBluetoothStateReceiver()

        // 현재 연결된 BT 기기 초기 체크
        checkCurrentConnections()
    }

    fun stopMonitoring() {
        if (!isMonitoring) return

        Log.d(TAG, "🔵 BT 모니터링 중지")
        isMonitoring = false

        try {
            context.unregisterReceiver(aclReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ ACL 리시버 해제 실패: ${e.message}")
        }

        try {
            context.unregisterReceiver(bluetoothStateReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ BT 상태 리시버 해제 실패: ${e.message}")
        }

        cancelAllDebounce()
        connectedPlaceIds.clear()
        connectedDeviceMacs.clear()
    }

    fun updatePlaces(
        places: List<AlarmPlace>,
        deviceMacAddresses: Set<String> = emptySet()
    ) {
        val btPlaces = places.filter { it.bluetoothDevices.isNotEmpty() }
        alarmPlaces = btPlaces
        this.deviceAlarmMacAddresses = deviceMacAddresses.map { it.uppercase() }.toMutableSet()

        if (btPlaces.isEmpty() && deviceAlarmMacAddresses.isEmpty() && isMonitoring) {
            Log.d(TAG, "🔵 BT 장소/기기 없음 → 모니터링 중지")
            stopMonitoring()
            return
        }

        if ((btPlaces.isNotEmpty() || deviceAlarmMacAddresses.isNotEmpty()) && !isMonitoring) {
            startMonitoring(places, deviceMacAddresses)
            return
        }

        Log.d(TAG, "🔵 BT 장소 업데이트: ${btPlaces.size}개, 독립 기기: ${deviceAlarmMacAddresses.size}개")
        checkCurrentConnections()
    }

    // ========== ACL BroadcastReceiver (BT 연결/해제) ==========

    private val aclReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!isMonitoring) return
            if (!hasBluetoothPermission()) return

            val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent?.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent?.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
            }
            if (device == null) return

            val macAddress = device.address?.uppercase() ?: return
            val deviceName = try { device.name ?: macAddress } catch (e: SecurityException) { macAddress }

            when (intent?.action) {
                BluetoothDevice.ACTION_ACL_CONNECTED -> {
                    Log.d(TAG, "🔵 ACL CONNECTED: $deviceName ($macAddress)")
                    mainHandler.post { handleBtConnected(macAddress, deviceName) }
                }
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                    Log.d(TAG, "🔵 ACL DISCONNECTED: $deviceName ($macAddress)")
                    mainHandler.post { handleBtDisconnected(macAddress, deviceName) }
                }
            }
        }
    }

    private fun registerAclReceiver() {
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(aclReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(aclReceiver, filter)
        }
        Log.d(TAG, "✅ ACL BroadcastReceiver 등록 완료")
    }

    // ========== BT 하드웨어 ON/OFF ==========

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothAdapter.ACTION_STATE_CHANGED) return

            val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
            when (state) {
                BluetoothAdapter.STATE_OFF -> {
                    Log.d(TAG, "🔵 BT 하드웨어 OFF → 모든 연결 EXIT 처리")
                    mainHandler.post { handleBtHardwareOff() }
                }
                BluetoothAdapter.STATE_ON -> {
                    Log.d(TAG, "🔵 BT 하드웨어 ON")
                }
            }
        }
    }

    private fun registerBluetoothStateReceiver() {
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(bluetoothStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(bluetoothStateReceiver, filter)
        }
        Log.d(TAG, "✅ BT 상태 리시버 등록 완료")
    }

    // ========== 연결 상태 처리 ==========

    /**
     * 현재 연결된 BT 기기를 프로파일로 확인 (앱 시작 시 초기 상태 설정)
     */
    private fun checkCurrentConnections() {
        if (!hasBluetoothPermission()) return
        val adapter = bluetoothAdapter ?: return

        // 주요 프로파일 체크 (A2DP, HEADSET, HID 등)
        val profilesToCheck = listOf(
            BluetoothProfile.A2DP,
            BluetoothProfile.HEADSET,
        )

        for (profileType in profilesToCheck) {
            try {
                adapter.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
                    override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
                        if (proxy == null) return
                        try {
                            val connectedDevices = proxy.connectedDevices
                            for (device in connectedDevices) {
                                val mac = device.address?.uppercase() ?: continue
                                val name = try { device.name ?: mac } catch (e: SecurityException) { mac }
                                Log.d(TAG, "🔵 현재 연결 중: $name ($mac) [profile=$profile]")
                                mainHandler.post { handleBtConnected(mac, name) }
                            }
                        } catch (e: SecurityException) {
                            Log.w(TAG, "⚠️ 프로파일 기기 조회 실패: ${e.message}")
                        }
                        adapter.closeProfileProxy(profile, proxy)
                    }

                    override fun onServiceDisconnected(profile: Int) {
                        // no-op
                    }
                }, profileType)
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ 프로파일 $profileType 체크 실패: ${e.message}")
            }
        }
    }

    // ========== BT 연결/해제 핸들러 ==========

    private fun handleBtConnected(macAddress: String, deviceName: String) {
        // 1) 장소 종속형: MAC → 장소 매칭
        val matchedPlaces = alarmPlaces.filter { place ->
            place.bluetoothDevices.any { bt ->
                bt.macAddress.equals(macAddress, ignoreCase = true)
            }
        }

        for (place in matchedPlaces) {
            cancelExitDebounce(place.id)

            if (!connectedPlaceIds.contains(place.id)) {
                connectedPlaceIds.add(place.id)

                if (!enterDebounceRunnables.containsKey(place.id)) {
                    Log.d(TAG, "🎯 BT 연결 감지: ${place.name} ($deviceName) → ENTER 15초 타이머 시작")
                    startEnterDebounce(place.id)
                } else {
                    Log.d(TAG, "🔵 BT 재연결: ${place.name} — ENTER 타이머 진행 중")
                }
            }
        }

        // 2) 독립형 기기 알람: MAC 매칭
        if (deviceAlarmMacAddresses.contains(macAddress)) {
            cancelDeviceExitDebounce(macAddress)

            if (!connectedDeviceMacs.contains(macAddress)) {
                connectedDeviceMacs.add(macAddress)

                if (!deviceEnterDebounceRunnables.containsKey(macAddress)) {
                    Log.d(TAG, "🎯 독립 기기 연결: $deviceName ($macAddress) → CONNECT 15초 타이머 시작")
                    startDeviceEnterDebounce(macAddress, deviceName)
                }
            }
        }
    }

    private fun handleBtDisconnected(macAddress: String, deviceName: String) {
        // 1) 장소 종속형
        val matchedPlaces = alarmPlaces.filter { place ->
            place.bluetoothDevices.any { bt ->
                bt.macAddress.equals(macAddress, ignoreCase = true)
            }
        }

        for (place in matchedPlaces) {
            cancelEnterDebounce(place.id)

            if (!exitDebounceRunnables.containsKey(place.id)) {
                startExitDebounce(place.id)
            }
        }

        // 2) 독립형 기기 알람
        if (deviceAlarmMacAddresses.contains(macAddress)) {
            cancelDeviceEnterDebounce(macAddress)

            if (!deviceExitDebounceRunnables.containsKey(macAddress)) {
                startDeviceExitDebounce(macAddress, deviceName)
            }
        }
    }

    private fun handleBtHardwareOff() {
        // BT OFF → 모든 연결에 대해 disconnected 처리
        val placesToCheck = connectedPlaceIds.toSet()
        for (placeId in placesToCheck) {
            cancelEnterDebounce(placeId)
            if (!exitDebounceRunnables.containsKey(placeId)) {
                startExitDebounce(placeId)
            }
        }

        val devicesToCheck = connectedDeviceMacs.toSet()
        for (mac in devicesToCheck) {
            cancelDeviceEnterDebounce(mac)
            if (!deviceExitDebounceRunnables.containsKey(mac)) {
                startDeviceExitDebounce(mac, mac) // deviceName fallback = mac
            }
        }
    }

    // ========== 장소 종속형 디바운스 ==========

    private fun startEnterDebounce(placeId: String) {
        val place = alarmPlaces.find { it.id == placeId }
        Log.d(TAG, "🔵 ENTER 타이머 시작 (${DEBOUNCE_DURATION_MS}ms): ${place?.name ?: placeId}")

        val runnable = Runnable {
            if (!isMonitoring) return@Runnable
            enterDebounceRunnables.remove(placeId)
            val p = alarmPlaces.find { it.id == placeId }
            Log.d(TAG, "🚨 BT ENTER 확정 (${DEBOUNCE_DURATION_MS}ms 연속 연결): ${p?.name ?: placeId}")
            onBluetoothPlaceEvent?.invoke(placeId, true)
        }

        enterDebounceRunnables[placeId] = runnable
        mainHandler.postDelayed(runnable, DEBOUNCE_DURATION_MS)
    }

    private fun cancelEnterDebounce(placeId: String) {
        enterDebounceRunnables[placeId]?.let {
            mainHandler.removeCallbacks(it)
        }
        enterDebounceRunnables.remove(placeId)
    }

    private fun startExitDebounce(placeId: String) {
        val place = alarmPlaces.find { it.id == placeId }
        Log.d(TAG, "🔵 EXIT 타이머 시작 (${DEBOUNCE_DURATION_MS}ms): ${place?.name ?: placeId}")

        val runnable = Runnable {
            if (!isMonitoring) return@Runnable
            connectedPlaceIds.remove(placeId)
            exitDebounceRunnables.remove(placeId)
            val p = alarmPlaces.find { it.id == placeId }
            Log.d(TAG, "🚨 BT EXIT 확정 (${DEBOUNCE_DURATION_MS}ms 연속 끊김): ${p?.name ?: placeId}")
            onBluetoothPlaceEvent?.invoke(placeId, false)
        }

        exitDebounceRunnables[placeId] = runnable
        mainHandler.postDelayed(runnable, DEBOUNCE_DURATION_MS)
    }

    private fun cancelExitDebounce(placeId: String) {
        exitDebounceRunnables[placeId]?.let {
            mainHandler.removeCallbacks(it)
        }
        exitDebounceRunnables.remove(placeId)
    }

    // ========== 독립형 기기 디바운스 ==========

    private fun startDeviceEnterDebounce(macAddress: String, deviceName: String) {
        Log.d(TAG, "🔵 독립 기기 CONNECT 타이머 시작 (${DEBOUNCE_DURATION_MS}ms): $deviceName ($macAddress)")

        val runnable = Runnable {
            if (!isMonitoring) return@Runnable
            deviceEnterDebounceRunnables.remove(macAddress)
            Log.d(TAG, "🚨 독립 기기 CONNECT 확정: $deviceName ($macAddress)")
            onBluetoothDeviceEvent?.invoke(macAddress, deviceName, true)
        }

        deviceEnterDebounceRunnables[macAddress] = runnable
        mainHandler.postDelayed(runnable, DEBOUNCE_DURATION_MS)
    }

    private fun cancelDeviceEnterDebounce(macAddress: String) {
        deviceEnterDebounceRunnables[macAddress]?.let {
            mainHandler.removeCallbacks(it)
        }
        deviceEnterDebounceRunnables.remove(macAddress)
    }

    private fun startDeviceExitDebounce(macAddress: String, deviceName: String) {
        Log.d(TAG, "🔵 독립 기기 DISCONNECT 타이머 시작 (${DEBOUNCE_DURATION_MS}ms): $deviceName ($macAddress)")

        val runnable = Runnable {
            if (!isMonitoring) return@Runnable
            connectedDeviceMacs.remove(macAddress)
            deviceExitDebounceRunnables.remove(macAddress)
            Log.d(TAG, "🚨 독립 기기 DISCONNECT 확정: $deviceName ($macAddress)")
            onBluetoothDeviceEvent?.invoke(macAddress, deviceName, false)
        }

        deviceExitDebounceRunnables[macAddress] = runnable
        mainHandler.postDelayed(runnable, DEBOUNCE_DURATION_MS)
    }

    private fun cancelDeviceExitDebounce(macAddress: String) {
        deviceExitDebounceRunnables[macAddress]?.let {
            mainHandler.removeCallbacks(it)
        }
        deviceExitDebounceRunnables.remove(macAddress)
    }

    // ========== 유틸리티 ==========

    private fun cancelAllDebounce() {
        for ((_, r) in exitDebounceRunnables) mainHandler.removeCallbacks(r)
        exitDebounceRunnables.clear()
        for ((_, r) in enterDebounceRunnables) mainHandler.removeCallbacks(r)
        enterDebounceRunnables.clear()
        for ((_, r) in deviceExitDebounceRunnables) mainHandler.removeCallbacks(r)
        deviceExitDebounceRunnables.clear()
        for ((_, r) in deviceEnterDebounceRunnables) mainHandler.removeCallbacks(r)
        deviceEnterDebounceRunnables.clear()
    }

    /** BLUETOOTH_CONNECT 권한 보유 여부 */
    private fun hasBluetoothPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            // Android 11 이하: BLUETOOTH 권한으로 충분
            true
        }
    }

    /** BT 하드웨어 활성 상태 */
    val isBluetoothEnabled: Boolean get() {
        return try {
            bluetoothAdapter?.isEnabled == true
        } catch (e: SecurityException) {
            false
        }
    }

    /** 상태 정보 */
    fun getStatus(): Map<String, Any?> {
        return mapOf(
            "isMonitoring" to isMonitoring,
            "btPlaceCount" to alarmPlaces.size,
            "deviceAlarmCount" to deviceAlarmMacAddresses.size,
            "connectedPlaceIds" to connectedPlaceIds.toList(),
            "connectedDeviceMacs" to connectedDeviceMacs.toList(),
            "bluetoothEnabled" to isBluetoothEnabled,
            "pendingExitDebounce" to exitDebounceRunnables.keys.toList(),
            "pendingEnterDebounce" to enterDebounceRunnables.keys.toList(),
        )
    }
}
