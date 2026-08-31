#include "flutter_window.h"

#include <shellapi.h>

#include <algorithm>
#include <array>
#include <cwctype>
#include <optional>
#include <set>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr wchar_t kApplicationsRegistryKey[] = L"Applications";
constexpr wchar_t kAppPathsRegistryKey[] =
    L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths";
constexpr wchar_t kSupportedProtocolsValue[] = L"SupportedProtocols";
constexpr wchar_t kUseUrlValue[] = L"UseUrl";

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int length = WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  if (length == 0) {
    return "";
  }
  std::string converted(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      converted.data(), length, nullptr, nullptr);
  return converted;
}

std::optional<std::wstring> Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::nullopt;
  }
  const int length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
      nullptr, 0);
  if (length == 0) {
    return std::nullopt;
  }
  std::wstring converted(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), converted.data(), length);
  return converted;
}

std::optional<std::wstring> ReadRegistryString(HKEY root,
                                                const std::wstring& sub_key,
                                                const wchar_t* value_name) {
  DWORD bytes = 0;
  const DWORD flags =
      RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ | RRF_RT_REG_MULTI_SZ;
  LONG status = RegGetValueW(root, sub_key.c_str(), value_name, flags, nullptr,
                             nullptr, &bytes);
  if (status != ERROR_SUCCESS || bytes == 0) {
    return std::nullopt;
  }
  std::wstring value(bytes / sizeof(wchar_t), L'\0');
  status = RegGetValueW(root, sub_key.c_str(), value_name, flags,
                        nullptr, value.data(), &bytes);
  if (status != ERROR_SUCCESS) {
    return std::nullopt;
  }
  while (!value.empty() && value.back() == L'\0') {
    value.pop_back();
  }
  return value.empty() ? std::nullopt
                       : std::optional<std::wstring>(std::move(value));
}

bool ContainsIgnoreCase(std::wstring value, const std::wstring& needle) {
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t character) {
    return static_cast<wchar_t>(std::towlower(character));
  });
  return value.find(needle) != std::wstring::npos;
}

bool IsKnownExternalPlayer(const std::wstring& executable) {
  const size_t separator = executable.find_last_of(L"\\\\/");
  std::wstring file_name = executable.substr(separator + 1);
  std::transform(file_name.begin(), file_name.end(), file_name.begin(),
                 [](wchar_t character) {
                   return static_cast<wchar_t>(std::towlower(character));
                 });
  return file_name == L"vlc.exe" || file_name == L"potplayermini.exe" ||
         file_name == L"potplayermini64.exe" || file_name == L"mpc-hc.exe" ||
         file_name == L"mpc-hc64.exe" || file_name == L"mpc-be.exe" ||
         file_name == L"mpc-be64.exe" || file_name == L"mpv.exe" ||
         file_name == L"mpvnet.exe";
}

std::wstring ExpandEnvironmentVariables(const std::wstring& value) {
  const DWORD size = ExpandEnvironmentStringsW(value.c_str(), nullptr, 0);
  if (size == 0) {
    return value;
  }
  std::wstring expanded(size, L'\0');
  if (ExpandEnvironmentStringsW(value.c_str(), expanded.data(), size) == 0) {
    return value;
  }
  expanded.pop_back();
  return expanded;
}

std::optional<std::wstring> ExtractExecutablePath(const std::wstring& command) {
  if (command.empty()) {
    return std::nullopt;
  }
  const std::wstring expanded = ExpandEnvironmentVariables(command);
  if (expanded.front() == L'\"') {
    const size_t closing_quote = expanded.find(L'\"', 1);
    if (closing_quote == std::wstring::npos) {
      return std::nullopt;
    }
    return expanded.substr(1, closing_quote - 1);
  }
  const size_t separator = expanded.find_first_of(L" \t");
  return expanded.substr(0, separator);
}

bool SupportsM3uPlaylist(const std::wstring& application_key) {
  HKEY supported_types_key = nullptr;
  if (RegOpenKeyExW(HKEY_CLASSES_ROOT,
                    (application_key + L"\\SupportedTypes").c_str(), 0,
                    KEY_READ, &supported_types_key) != ERROR_SUCCESS) {
    return false;
  }

  bool supports_m3u = false;
  for (DWORD index = 0;; ++index) {
    std::array<wchar_t, 128> type_name{};
    DWORD name_length = static_cast<DWORD>(type_name.size());
    const LONG status = RegEnumValueW(supported_types_key, index,
                                      type_name.data(), &name_length, nullptr,
                                      nullptr, nullptr, nullptr);
    if (status == ERROR_NO_MORE_ITEMS) {
      break;
    }
    if (status == ERROR_SUCCESS &&
        ContainsIgnoreCase(std::wstring(type_name.data(), name_length),
                           L".m3u")) {
      supports_m3u = true;
      break;
    }
  }
  RegCloseKey(supported_types_key);
  return supports_m3u;
}

void AppendPlayer(flutter::EncodableList* players,
                  std::set<std::wstring>* known_paths,
                  const std::wstring& executable,
                  const std::wstring& label) {
  if (!IsKnownExternalPlayer(executable) ||
      GetFileAttributesW(executable.c_str()) == INVALID_FILE_ATTRIBUTES ||
      !known_paths->insert(executable).second) {
    return;
  }
  flutter::EncodableMap player;
  player[flutter::EncodableValue("id")] =
      flutter::EncodableValue(WideToUtf8(executable));
  player[flutter::EncodableValue("label")] =
      flutter::EncodableValue(WideToUtf8(label));
  players->emplace_back(std::move(player));
}

bool IsUrlCapableAppPath(HKEY root, const std::wstring& application_key) {
  DWORD use_url = 0;
  DWORD bytes = sizeof(use_url);
  const LONG status = RegGetValueW(root, application_key.c_str(),
                                   kUseUrlValue, RRF_RT_REG_DWORD, nullptr,
                                   &use_url, &bytes);
  if (status != ERROR_SUCCESS || use_url == 0) {
    return false;
  }
  const auto protocols =
      ReadRegistryString(root, application_key, kSupportedProtocolsValue);
  return protocols.has_value() && ContainsIgnoreCase(*protocols, L"http");
}

void AppendAppPathsPlayers(HKEY root, flutter::EncodableList* players,
                           std::set<std::wstring>* known_paths) {
  HKEY app_paths_key = nullptr;
  if (RegOpenKeyExW(root, kAppPathsRegistryKey, 0, KEY_READ, &app_paths_key) !=
      ERROR_SUCCESS) {
    return;
  }

  for (DWORD index = 0;; ++index) {
    std::array<wchar_t, 512> application_name{};
    DWORD name_length = static_cast<DWORD>(application_name.size());
    const LONG status = RegEnumKeyExW(
        app_paths_key, index, application_name.data(), &name_length, nullptr,
        nullptr, nullptr, nullptr);
    if (status == ERROR_NO_MORE_ITEMS) {
      break;
    }
    if (status != ERROR_SUCCESS) {
      continue;
    }

    const std::wstring application(application_name.data(), name_length);
    const std::wstring application_key =
        std::wstring(kAppPathsRegistryKey) + L"\\" + application;
    if (!IsUrlCapableAppPath(root, application_key)) {
      continue;
    }
    const auto executable = ReadRegistryString(root, application_key, nullptr);
    if (!executable.has_value()) {
      continue;
    }
    AppendPlayer(players, known_paths,
                 ExpandEnvironmentVariables(*executable), application);
  }

  RegCloseKey(app_paths_key);
}

flutter::EncodableList ListExternalPlayers() {
  HKEY applications_key = nullptr;
  if (RegOpenKeyExW(HKEY_CLASSES_ROOT, kApplicationsRegistryKey, 0, KEY_READ,
                    &applications_key) != ERROR_SUCCESS) {
    return {};
  }

  std::set<std::wstring> known_paths;
  flutter::EncodableList players;
  for (DWORD index = 0;; ++index) {
    std::array<wchar_t, 512> application_name{};
    DWORD name_length = static_cast<DWORD>(application_name.size());
    const LONG status = RegEnumKeyExW(
        applications_key, index, application_name.data(), &name_length, nullptr,
        nullptr, nullptr, nullptr);
    if (status == ERROR_NO_MORE_ITEMS) {
      break;
    }
    if (status != ERROR_SUCCESS) {
      continue;
    }

    const std::wstring application(application_name.data(), name_length);
    const std::wstring application_key =
        std::wstring(kApplicationsRegistryKey) + L"\\" + application;
    if (!SupportsM3uPlaylist(application_key)) {
      continue;
    }
    const auto command = ReadRegistryString(HKEY_CLASSES_ROOT,
        application_key + L"\\shell\\open\\command", nullptr);
    if (!command.has_value()) {
      continue;
    }
    const auto executable = ExtractExecutablePath(*command);
    if (!executable.has_value()) {
      continue;
    }
    AppendPlayer(&players, &known_paths, *executable, application);
  }

  RegCloseKey(applications_key);
  AppendAppPathsPlayers(HKEY_CURRENT_USER, &players, &known_paths);
  AppendAppPathsPlayers(HKEY_LOCAL_MACHINE, &players, &known_paths);
  return players;
}

const std::string* GetStringArgument(const flutter::EncodableMap& arguments,
                                     const char* name) {
  const auto iterator = arguments.find(flutter::EncodableValue(name));
  if (iterator == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&iterator->second);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  external_player_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "sakuramedia/external_player",
          &flutter::StandardMethodCodec::GetInstance());
  external_player_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleExternalPlayerMethodCall(call, std::move(result));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  external_player_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleExternalPlayerMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "listPlayers") {
    result->Success(flutter::EncodableValue(ListExternalPlayers()));
    return;
  }
  if (method_call.method_name() != "launch") {
    result->NotImplemented();
    return;
  }

  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (arguments == nullptr) {
    result->Error("invalid_arguments", "Missing playback arguments");
    return;
  }
  const std::string* player_id = GetStringArgument(*arguments, "playerId");
  const std::string* url = GetStringArgument(*arguments, "url");
  const auto player_path =
      player_id == nullptr ? std::nullopt : Utf8ToWide(*player_id);
  const auto stream_url = url == nullptr ? std::nullopt : Utf8ToWide(*url);
  if (!player_path.has_value() || !stream_url.has_value() ||
      (stream_url->rfind(L"http://", 0) != 0 &&
       stream_url->rfind(L"https://", 0) != 0)) {
    result->Error("invalid_arguments", "Invalid playback arguments");
    return;
  }
  if (GetFileAttributesW(player_path->c_str()) == INVALID_FILE_ATTRIBUTES) {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  SHELLEXECUTEINFOW execute_info{};
  execute_info.cbSize = sizeof(execute_info);
  execute_info.fMask = SEE_MASK_FLAG_NO_UI;
  execute_info.lpVerb = L"open";
  execute_info.lpFile = player_path->c_str();
  execute_info.lpParameters = stream_url->c_str();
  execute_info.nShow = SW_SHOWNORMAL;
  result->Success(flutter::EncodableValue(ShellExecuteExW(&execute_info) != 0));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
