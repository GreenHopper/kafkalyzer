#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <fstream>
#include <iostream>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::ofstream logFile("startup_log.txt", std::ios::out | std::ios::app);
  logFile << "DEBUG: wWinMain started" << std::endl;

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
  logFile << "DEBUG: Console check passed" << std::endl;

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  logFile << "DEBUG: CoInitializeEx finished" << std::endl;

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  logFile << "DEBUG: Attempting to create window" << std::endl;
  if (!window.Create(L"kafkalyzer", origin, size)) {
    logFile << "ERROR: Failed to create window" << std::endl;
    return EXIT_FAILURE;
  }
  logFile << "DEBUG: Window created successfully" << std::endl;
  window.SetQuitOnClose(true);

  ::MSG msg;
  logFile << "DEBUG: Entering message loop" << std::endl;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
  logFile << "DEBUG: Exiting message loop" << std::endl;

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
