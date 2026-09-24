#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(900, 760);
  if (!window.Create(L"HTTP 延迟测试", origin, size)) {
    return EXIT_FAILURE;
  }

  // 在首次显示前，按窗口实际像素尺寸居中到所在显示器的工作区。
  const HWND handle = window.GetHandle();
  MONITORINFO monitor_info{sizeof(monitor_info)};
  RECT window_rect;
  if (::GetMonitorInfo(::MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST),
                       &monitor_info) &&
      ::GetWindowRect(handle, &window_rect)) {
    const RECT& work_area = monitor_info.rcWork;
    const LONG width = window_rect.right - window_rect.left;
    const LONG height = window_rect.bottom - window_rect.top;
    const LONG x = work_area.left +
                   std::max(0L, (work_area.right - work_area.left - width) / 2);
    const LONG y = work_area.top +
                   std::max(0L, (work_area.bottom - work_area.top - height) / 2);
    ::SetWindowPos(handle, nullptr, x, y, 0, 0,
                   SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
