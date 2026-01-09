#ifndef DISPLAY_MANAGER_H
#define DISPLAY_MANAGER_H

#include <M5Unified.h>
#include "config.h"

// ============================================================================
// Display Manager - Screen modes and UI rendering
// ============================================================================

enum class ScreenMode
{
    IDLE,
    LEGAL_WARNING,
    SCANNING_WIFI,
    CONNECTING,
    CONNECTED,
    NETWORK_SCAN,
    PORT_SCAN,
    VULNERABILITY,
    ERROR,
    STATUS
};

class DisplayManager
{
public:
    void init();

    // Last command indicator
    void setLastCommand(const char *cmdLabel);

    // Screen mode setters
    void showLegalWarning();
    void showIdle();
    void showScanningWifi(int foundCount);
    void showConnecting(const char *ssid);
    void showConnected(const char *ip, const char *gateway);
    void showNetworkScan(const char *subnet, int percent, int devicesFound);
    void showPortScan(const char *ip, int currentPort, int totalPorts, int openCount);
    void showVulnerabilities(int count, int severity);
    void showError(const char *message);
    void showStatus(const char *bleStatus, const char *wifiStatus, int battery);

    // Progress bar
    void updateProgress(int percent);

    // Battery indicator
    void updateBattery(int percent);

    // Quick message overlay
    void showMessage(const char *msg, uint16_t color = COLOR_TEXT, int durationMs = 2000);

    // Force refresh
    void refresh();

    // Get current mode
    ScreenMode getMode() const { return currentMode; }

private:
    ScreenMode currentMode = ScreenMode::IDLE;
    int lastProgress = -1;
    int lastBattery = -1;
    unsigned long messageEndTime = 0;
    char messageBuffer[64] = {0};
    uint16_t messageColor = COLOR_TEXT;
    char lastCommand[48] = "Cmd: none";

    void clearScreen();
    void drawHeader(const char *title, uint16_t color = COLOR_TEXT);
    void drawProgressBar(int x, int y, int width, int height, int percent, uint16_t color);
    void drawBatteryIcon(int percent);
    void centerText(const char *text, int y, int size = 2, uint16_t color = COLOR_TEXT);
};

extern DisplayManager displayManager;

#endif // DISPLAY_MANAGER_H
