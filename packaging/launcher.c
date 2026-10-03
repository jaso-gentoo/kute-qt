#include <windows.h>
#include <shellapi.h>
#include <stdio.h>

int WINAPI wWinMain(HINSTANCE hI, HINSTANCE hP, PWSTR cmd, int nShow) {
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    wchar_t *slash = wcsrchr(exePath, L'\\');
    if (slash) *slash = 0;

    wchar_t tempPath[MAX_PATH];
    GetTempPathW(MAX_PATH, tempPath);

    wchar_t targetDir[MAX_PATH];
    swprintf(targetDir, MAX_PATH, L"%skute_%u", tempPath, GetTickCount());
    CreateDirectoryW(targetDir, NULL);

    wchar_t psCmd[2048];
    swprintf(psCmd, 2048,
        L"powershell -NoProfile -WindowStyle Hidden -Command "
        L"\"Expand-Archive -Path '%s\\dist.zip' -DestinationPath '%s' -Force\"",
        exePath, targetDir);

    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(NULL, psCmd, NULL, NULL, FALSE,
                        CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
        MessageBoxW(NULL, L"Cannot run unpacker", L"kute", MB_ICONERROR);
        return 1;
    }
    WaitForSingleObject(pi.hProcess, 60000);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    wchar_t kuteExe[MAX_PATH];
    swprintf(kuteExe, MAX_PATH, L"%s\\kute.exe", targetDir);

    if (GetFileAttributesW(kuteExe) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(NULL, L"Unpack failed, kute.exe not found", L"kute", MB_ICONERROR);
        return 1;
    }

    ShellExecuteW(NULL, L"open", kuteExe, NULL, targetDir, SW_SHOW);
    return 0;
}
