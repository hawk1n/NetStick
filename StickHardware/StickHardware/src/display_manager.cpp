#include "display_manager.h"

// ============================================================================
// Display Manager - Implementation
// ============================================================================

DisplayManager displayManager;

void DisplayManager::init()
{
    M5.Display.setRotation(1); // Landscape
    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
    M5.Display.setTextSize(2);
    clearScreen();
}

void DisplayManager::setLastCommand(const char *cmdLabel)
{
    strncpy(lastCommand, cmdLabel, sizeof(lastCommand) - 1);
    lastCommand[sizeof(lastCommand) - 1] = '\0';
}

void DisplayManager::clearScreen()
{
    M5.Display.startWrite();
    M5.Display.fillScreen(COLOR_BG);
    M5.Display.endWrite();
}

void DisplayManager::drawHeader(const char *title, uint16_t color)
{
    M5.Display.fillRect(0, 0, SCREEN_WIDTH, STATUS_BAR_HEIGHT, color);
    M5.Display.setTextColor(COLOR_BG, color);
    M5.Display.setTextSize(1);
    M5.Display.setCursor(4, 6);
    M5.Display.print(title);

    // Draw last command on the right side of the header
    int16_t labelWidth = strlen(lastCommand) * 6; // approx width at size 1
    constexpr int16_t rightMargin = 40;            // leave space for battery/status icons
    int16_t x = SCREEN_WIDTH - labelWidth - rightMargin;
    if (x < 80)
        x = 80; // avoid colliding with title
    M5.Display.setCursor(x, 6);
    M5.Display.print(lastCommand);

    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
}

void DisplayManager::centerText(const char *text, int y, int size, uint16_t color)
{
    M5.Display.setTextSize(size);
    int16_t x1, y1;
    uint16_t w, h;
    M5.Display.setTextColor(color, COLOR_BG);
    // Approximate centering (6 pixels per char at size 1)
    int charWidth = 6 * size;
    int textLen = strlen(text);
    int x = (SCREEN_WIDTH - (textLen * charWidth)) / 2;
    if (x < 0)
        x = 0;
    M5.Display.setCursor(x, y);
    M5.Display.print(text);
    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
}

void DisplayManager::drawProgressBar(int x, int y, int width, int height, int percent, uint16_t color)
{
    // Border
    M5.Display.drawRect(x, y, width, height, COLOR_TEXT);
    // Fill
    int fillWidth = (width - 2) * percent / 100;
    M5.Display.fillRect(x + 1, y + 1, fillWidth, height - 2, color);
    // Clear rest
    M5.Display.fillRect(x + 1 + fillWidth, y + 1, width - 2 - fillWidth, height - 2, COLOR_BG);
}

void DisplayManager::drawBatteryIcon(int percent)
{
    int x = SCREEN_WIDTH - 30;
    int y = 4;
    // Battery outline
    M5.Display.drawRect(x, y, 24, 12, COLOR_TEXT);
    M5.Display.fillRect(x + 24, y + 3, 3, 6, COLOR_TEXT);
    // Fill
    uint16_t color = percent > 50 ? COLOR_OK : (percent > 20 ? COLOR_PROGRESS : COLOR_ERROR);
    int fillWidth = 22 * percent / 100;
    M5.Display.fillRect(x + 1, y + 1, fillWidth, 10, color);
    M5.Display.fillRect(x + 1 + fillWidth, y + 1, 22 - fillWidth, 10, COLOR_BG);
}

void DisplayManager::showLegalWarning()
{
    currentMode = ScreenMode::LEGAL_WARNING;
    M5.Display.startWrite();
    clearScreen();

    M5.Display.setTextColor(COLOR_WARNING, COLOR_BG);
    centerText("!! LEGAL USE ONLY !!", 20, 2);

    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
    M5.Display.setTextSize(1);
    M5.Display.setCursor(10, 50);
    M5.Display.print("This tool is for authorized");
    M5.Display.setCursor(10, 62);
    M5.Display.print("network testing only.");
    M5.Display.setCursor(10, 80);
    M5.Display.print("Unauthorized access is ILLEGAL.");

    M5.Display.setTextColor(COLOR_OK, COLOR_BG);
    centerText("Press button to continue", 110, 1);

    M5.Display.endWrite();
}

void DisplayManager::showIdle()
{
    currentMode = ScreenMode::IDLE;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("M5 Network Scanner", COLOR_INFO);

    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
    centerText("Waiting for", 45, 2);
    centerText("command...", 70, 2);

    M5.Display.setTextColor(TFT_DARKGREY, COLOR_BG);
    centerText("BLE: Ready", 105, 1);

    M5.Display.endWrite();
}

void DisplayManager::showScanningWifi(int foundCount)
{
    currentMode = ScreenMode::SCANNING_WIFI;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("WiFi Scan", COLOR_PROGRESS);

    centerText("Scanning...", 45, 2, COLOR_PROGRESS);

    char buf[32];
    snprintf(buf, sizeof(buf), "%d networks found", foundCount);
    centerText(buf, 80, 2, COLOR_OK);

    M5.Display.endWrite();
}

void DisplayManager::showConnecting(const char *ssid)
{
    currentMode = ScreenMode::CONNECTING;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("Connecting...", COLOR_PROGRESS);

    centerText("SSID:", 40, 1);

    // Truncate SSID if too long
    char truncated[20];
    strncpy(truncated, ssid, 19);
    truncated[19] = '\0';
    centerText(truncated, 55, 2, COLOR_INFO);

    centerText("Please wait...", 90, 1, COLOR_PROGRESS);

    M5.Display.endWrite();
}

void DisplayManager::showConnected(const char *ip, const char *gateway)
{
    currentMode = ScreenMode::CONNECTED;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("Connected", COLOR_OK);

    M5.Display.setTextSize(1);
    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);

    M5.Display.setCursor(10, 30);
    M5.Display.print("IP: ");
    M5.Display.setTextColor(COLOR_OK, COLOR_BG);
    M5.Display.print(ip);

    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
    M5.Display.setCursor(10, 50);
    M5.Display.print("Gateway: ");
    M5.Display.print(gateway);

    M5.Display.setTextColor(TFT_DARKGREY, COLOR_BG);
    M5.Display.setCursor(10, 80);
    M5.Display.print("Ready for network scan");

    M5.Display.endWrite();
}

void DisplayManager::showNetworkScan(const char *subnet, int percent, int devicesFound)
{
    currentMode = ScreenMode::NETWORK_SCAN;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("Network Scan", COLOR_PROGRESS);

    M5.Display.setTextSize(1);
    M5.Display.setCursor(10, 30);
    M5.Display.print("Subnet: ");
    M5.Display.print(subnet);

    char buf[32];
    snprintf(buf, sizeof(buf), "Devices: %d", devicesFound);
    M5.Display.setCursor(10, 50);
    M5.Display.setTextColor(COLOR_OK, COLOR_BG);
    M5.Display.print(buf);
    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);

    // Progress bar
    drawProgressBar(10, 75, SCREEN_WIDTH - 20, 20, percent, COLOR_PROGRESS);

    snprintf(buf, sizeof(buf), "%d%%", percent);
    centerText(buf, 100, 1);

    M5.Display.endWrite();
}

void DisplayManager::showPortScan(const char *ip, int currentPort, int totalPorts, int openCount)
{
    currentMode = ScreenMode::PORT_SCAN;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("Port Scan", COLOR_INFO);

    M5.Display.setTextSize(1);
    M5.Display.setCursor(10, 30);
    M5.Display.print("Target: ");
    M5.Display.print(ip);

    char buf[32];
    snprintf(buf, sizeof(buf), "Open ports: %d", openCount);
    M5.Display.setCursor(10, 50);
    M5.Display.setTextColor(COLOR_OK, COLOR_BG);
    M5.Display.print(buf);
    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);

    int percent = totalPorts > 0 ? (currentPort * 100 / totalPorts) : 0;
    drawProgressBar(10, 75, SCREEN_WIDTH - 20, 20, percent, COLOR_INFO);

    snprintf(buf, sizeof(buf), "%d/%d", currentPort, totalPorts);
    centerText(buf, 100, 1);

    M5.Display.endWrite();
}

void DisplayManager::showVulnerabilities(int count, int severity)
{
    currentMode = ScreenMode::VULNERABILITY;
    M5.Display.startWrite();
    clearScreen();

    uint16_t headerColor = severity >= 7 ? COLOR_ERROR : (severity >= 4 ? COLOR_WARNING : COLOR_PROGRESS);
    drawHeader("Vulnerabilities", headerColor);

    char buf[32];

    if (count == 0)
    {
        centerText("No vulns found", 55, 2, COLOR_OK);
    }
    else
    {
        M5.Display.setTextColor(headerColor, COLOR_BG);
        snprintf(buf, sizeof(buf), "%d found", count);
        centerText(buf, 45, 3);

        M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
        snprintf(buf, sizeof(buf), "Max severity: %d/10", severity);
        centerText(buf, 85, 1);
    }

    M5.Display.endWrite();
}

void DisplayManager::showError(const char *message)
{
    currentMode = ScreenMode::ERROR;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("ERROR", COLOR_ERROR);

    M5.Display.setTextSize(1);
    M5.Display.setTextColor(COLOR_ERROR, COLOR_BG);

    // Word wrap for error message
    int y = 40;
    int x = 10;
    int maxWidth = SCREEN_WIDTH - 20;

    String msg = message;
    while (msg.length() > 0 && y < SCREEN_HEIGHT - 20)
    {
        int charsPerLine = maxWidth / 6; // ~6px per char
        String line = msg.substring(0, min((int)msg.length(), charsPerLine));
        M5.Display.setCursor(x, y);
        M5.Display.print(line);
        msg = msg.substring(line.length());
        y += 14;
    }

    M5.Display.endWrite();
}

void DisplayManager::showStatus(const char *bleStatus, const char *wifiStatus, int battery)
{
    currentMode = ScreenMode::STATUS;
    M5.Display.startWrite();
    clearScreen();
    drawHeader("Status", COLOR_INFO);
    drawBatteryIcon(battery);

    M5.Display.setTextSize(1);
    M5.Display.setCursor(10, 30);
    M5.Display.print("BLE: ");
    M5.Display.setTextColor(COLOR_OK, COLOR_BG);
    M5.Display.print(bleStatus);

    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
    M5.Display.setCursor(10, 50);
    M5.Display.print("WiFi: ");
    M5.Display.print(wifiStatus);

    M5.Display.setCursor(10, 70);
    M5.Display.print("Battery: ");
    char buf[16];
    snprintf(buf, sizeof(buf), "%d%%", battery);
    uint16_t batColor = battery > 50 ? COLOR_OK : (battery > 20 ? COLOR_PROGRESS : COLOR_ERROR);
    M5.Display.setTextColor(batColor, COLOR_BG);
    M5.Display.print(buf);

    M5.Display.endWrite();
}

void DisplayManager::updateProgress(int percent)
{
    if (percent == lastProgress)
        return;
    lastProgress = percent;

    // Only redraw progress bar area
    drawProgressBar(10, 75, SCREEN_WIDTH - 20, 20, percent,
                    currentMode == ScreenMode::PORT_SCAN ? COLOR_INFO : COLOR_PROGRESS);

    char buf[8];
    snprintf(buf, sizeof(buf), "%d%%", percent);
    M5.Display.fillRect(0, 100, SCREEN_WIDTH, 20, COLOR_BG);
    centerText(buf, 100, 1);
}

void DisplayManager::updateBattery(int percent)
{
    if (percent == lastBattery)
        return;
    lastBattery = percent;
    drawBatteryIcon(percent);
}

void DisplayManager::showMessage(const char *msg, uint16_t color, int durationMs)
{
    strncpy(messageBuffer, msg, sizeof(messageBuffer) - 1);
    messageBuffer[sizeof(messageBuffer) - 1] = '\0';
    messageColor = color;
    messageEndTime = millis() + durationMs;

    // Draw message overlay at bottom
    M5.Display.fillRect(0, SCREEN_HEIGHT - 25, SCREEN_WIDTH, 25, TFT_DARKGREY);
    M5.Display.setTextColor(color, TFT_DARKGREY);
    M5.Display.setTextSize(1);
    int x = (SCREEN_WIDTH - strlen(msg) * 6) / 2;
    M5.Display.setCursor(x > 0 ? x : 5, SCREEN_HEIGHT - 18);
    M5.Display.print(msg);
    M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
}

void DisplayManager::refresh()
{
    // Check if message overlay should be cleared
    if (messageEndTime > 0 && millis() > messageEndTime)
    {
        messageEndTime = 0;
        // Clear only the overlay area to avoid full redraw
        M5.Display.fillRect(0, SCREEN_HEIGHT - 25, SCREEN_WIDTH, 25, COLOR_BG);
        M5.Display.setTextColor(COLOR_TEXT, COLOR_BG);
    }
}
