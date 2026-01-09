#ifndef CONFIG_H
#define CONFIG_H

// ============================================================================
// M5Stick Plus2 Network Scanner - Configuration
// ============================================================================

// BLE Configuration - Nordic UART Service (NUS)
#define BLE_DEVICE_NAME "M5Scanner"
#define NUS_SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_RX_CHAR_UUID        "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"  // iPhone writes here
#define NUS_TX_CHAR_UUID        "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"  // M5Stick notifies here

// BLE MTU limit (conservative for iOS compatibility)
#define BLE_MTU_SIZE 180

// WiFi Configuration
#define WIFI_CONNECT_TIMEOUT_MS 15000
#define WIFI_SCAN_TIMEOUT_MS 10000

// Network Scanner Configuration
#define ARP_TIMEOUT_MS 100
#define ARP_RETRIES 2
#define MAX_DEVICES_IN_SCAN 96

// Port Scanner Configuration
#define PORT_CONNECT_TIMEOUT_MS 2000
#define BANNER_READ_TIMEOUT_MS 1000
#define BANNER_MAX_SIZE 256
#define PARALLEL_PORT_SCANS 10
#define DEFAULT_PORT_RANGE_START 20
#define DEFAULT_PORT_RANGE_END 1000

// Common Ports to prioritize
static const uint16_t COMMON_PORTS[] = {
    21,   // FTP
    22,   // SSH
    23,   // Telnet
    25,   // SMTP
    53,   // DNS
    80,   // HTTP
    110,  // POP3
    143,  // IMAP
    443,  // HTTPS
    445,  // SMB
    993,  // IMAPS
    995,  // POP3S
    3306, // MySQL
    3389, // RDP
    5432, // PostgreSQL
    5900, // VNC
    6379, // Redis
    8080, // HTTP-Alt
    8443, // HTTPS-Alt
    27017 // MongoDB
};
#define COMMON_PORTS_COUNT (sizeof(COMMON_PORTS) / sizeof(COMMON_PORTS[0]))

// Display Configuration
#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 135
#define STATUS_BAR_HEIGHT 20
#define PROGRESS_BAR_HEIGHT 10

// Power Management
#define IDLE_TIMEOUT_MS 600000   // 10 minutes auto-off
#define LOW_BATTERY_THRESHOLD 15 // percent

// Serial Debug
#define SERIAL_BAUD_RATE 115200

// Colors (RGB565)
#define COLOR_BG TFT_BLACK
#define COLOR_TEXT TFT_WHITE
#define COLOR_OK TFT_GREEN
#define COLOR_PROGRESS TFT_YELLOW
#define COLOR_ERROR TFT_RED
#define COLOR_WARNING TFT_ORANGE
#define COLOR_INFO TFT_CYAN

// JSON buffer sizes
#define JSON_CMD_BUFFER_SIZE 512
#define JSON_RESP_BUFFER_SIZE 1024

#endif // CONFIG_H
