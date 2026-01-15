#ifndef BLUETOOTH_HANDLER_H
#define BLUETOOTH_HANDLER_H

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include "config.h"
#include "port_scanner.h"

// ============================================================================
// Bluetooth Handler - Nordic UART Service (NUS) with JSON Protocol
// ============================================================================
// Protocol: M5Stick ↔ iPhone BLE Communication
// Service:  6E400001-B5A3-F393-E0A9-E50E24DCCA9E (NUS)
// RX Char:  6E400002-... (iPhone writes commands here)
// TX Char:  6E400003-... (M5Stick sends responses via notify)
// Format:   JSON UTF-8 strings
// ============================================================================

// Command types received from iPhone
enum class BLECommand
{
    NONE,
    WIFI_SCAN,       // {"cmd":"wifi_scan"}
    NETWORK_SCAN,    // {"cmd":"network_scan"}
    PORT_SCAN,       // {"cmd":"port_scan","target":"192.168.1.10","start":1,"end":1024}
    WIFI_CONNECT,    // {"cmd":"wifi_connect","ssid":"...","password":"..."}
    ADVANCED_SCAN,   // {"cmd":"advanced_scan","target":"192.168.1.10","osDetect":true,"serviceVersion":true}
    ANALYZE,         // {"cmd":"analyze","target":"192.168.1.10"}
    STATUS,          // {"cmd":"status"}
    CANCEL,          // {"cmd":"cancel"}
    UNKNOWN
};

// Structure to hold parsed command data
struct CommandData
{
    BLECommand cmd = BLECommand::NONE;
    
    // WiFi connect params
    char ssid[33] = {0};
    char password[65] = {0};
    
    // Port scan params
    char targetIP[16] = {0};
    uint16_t portStart = DEFAULT_PORT_RANGE_START;
    uint16_t portEnd = DEFAULT_PORT_RANGE_END;
    
    // Advanced scan params
    bool osDetect = false;
    bool serviceVersion = true;
};

// WiFi network info for results
struct WiFiNetworkBLE
{
    char ssid[33];
    char bssid[18];
    int rssi;
    int channel;
    char encryption[8];
};

class BluetoothHandler
{
public:
    void init(const char *deviceName = BLE_DEVICE_NAME);
    void update();

    // Connection state
    bool isConnected() const { return connected; }

    // Command handling
    bool hasCommand() const { return commandPending; }
    CommandData getCommand();
    void clearCommand();
    
    // Check if cancel was requested
    bool isCancelRequested() const { return cancelRequested; }
    void clearCancelFlag() { cancelRequested = false; }

    // ========================================================================
    // Response Methods (New Protocol)
    // ========================================================================
    
    // Acknowledgment: {"type":"ack","cmd":"<command>"}
    void sendAck(const char* cmd);
    
    // WiFi scan results (single message with all networks)
    // {"type":"wifi_results","networks":[...]}
    void sendWifiResults(const WiFiNetworkBLE* networks, int count);
    
    // Network device found (streaming)
    // {"type":"device","ip":"...","mac":"...","vendor":"..."}
    void sendDevice(const char* ip, const char* mac, const char* vendor);
    
    // Network scan complete
    // {"type":"net_done","count":N}
    void sendNetDone(int count);
    
    // Port result (streaming - legacy)
    // {"type":"port_result","port":N,"service":"...","banner":"..."}
    void sendPortResult(uint16_t port, const char* service, const char* banner = nullptr);

    // Raw port data (preferred)
    // {"type":"port_raw","ip":"...","port":N,"protocol":"tcp","service":"...","banner":"...","version":"..."}
    void sendPortRaw(uint16_t port, const char* targetIp, const char* service, const char* banner = nullptr, const char* version = nullptr);
    
    // Port scan complete
    // {"type":"port_done","count":N}
    void sendPortDone(int count);

    // Port summary
    // {"type":"port_summary","target":"...","start":S,"end":E,"os":"unknown","open_ports":[...]}
    void sendPortSummary(uint16_t startPort, uint16_t endPort, const char* targetIp, const char* os, const PortScanner& scanner);
    
    // Progress update (optional)
    // {"type":"progress","stage":"...","operation":"...","current":N,"total":N,"percent":P}
    void sendProgress(const char* operation, int current, int total);
    
    // Cancelled confirmation
    // {"type":"cancelled"}
    void sendCancelled();
    
    // Error message
    // {"type":"error","message":"..."}
    void sendError(const char* message);
    
    // Status update (periodic)
<<<<<<< HEAD
    // {"type":"status","battery":N,"charging":true/false,"bt_connected":bool,"wifi_connected":bool,"ssid":"...","rssi":-65,"operation":"...","progress":P}
    void sendStatus(int battery, bool charging, bool btConnected, bool wifiConnected, const char* ssid, int rssi, const char* operation, int progress);
=======
    // {"type":"status","battery":N,"charging":true/false,"bt_connected":bool,"wifi_connected":bool,"ssid":"...","rssi":-65,"operation":"...","progress":P,"uptime":S}
    void sendStatus(int battery, bool charging, bool btConnected, bool wifiConnected, const char* ssid, int rssi, const char* operation, int progress, unsigned long uptimeSeconds);
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)

    // Raw JSON (for custom messages)
    void sendRaw(const char* json);

    // Callbacks for BLE events
    void onConnect(uint16_t connId);
    void onDisconnect();
    void onDataReceived(const char* data, size_t length);

private:
    BLEServer* server = nullptr;
    BLEService* nusService = nullptr;
    BLECharacteristic* rxCharacteristic = nullptr;  // iPhone writes here
    BLECharacteristic* txCharacteristic = nullptr;  // M5Stick notifies here
    BLE2902* txDescriptor = nullptr;

    bool connected = false;
    uint16_t connectionId = 0;
    bool commandPending = false;
    bool cancelRequested = false;
    CommandData pendingCommand;

    // Buffer for fragmented JSON messages
    char rxBuffer[JSON_CMD_BUFFER_SIZE] = {0};
    size_t rxBufferLen = 0;

    void parseCommand(const char* json);
    bool notificationsEnabled();
    void sendNotification(const char* data);
    
    // Helper to escape strings for JSON
    static void escapeJsonString(const char* input, char* output, size_t maxLen);
};

// Global instance
extern BluetoothHandler bleHandler;

#endif // BLUETOOTH_HANDLER_H
