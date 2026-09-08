#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commdlg.h>

#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr std::uint8_t handshake_request = 0xFFu;
constexpr std::uint8_t handshake_response = 0xFEu;
constexpr std::size_t maximum_program_size = 28u * 1024u;

[[noreturn]] void win32_error(const char *message)
{
    throw std::runtime_error(
        std::string(message) + " (Win32 error " +
        std::to_string(GetLastError()) + ")");
}

std::string select_program()
{
    std::array<char, MAX_PATH> path{};
    const char filter[] = "Raw binary (*.bin)\0*.bin\0All files (*.*)\0*.*\0\0";

    OPENFILENAMEA dialog{};
    dialog.lStructSize = sizeof(dialog);
    dialog.lpstrFilter = filter;
    dialog.lpstrFile = path.data();
    dialog.nMaxFile = static_cast<DWORD>(path.size());
    dialog.lpstrTitle = "Select a RISC-V program image";
    dialog.lpstrDefExt = "bin";
    dialog.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;

    if(GetOpenFileNameA(&dialog) != FALSE) return path.data();
    if(CommDlgExtendedError() != 0u) win32_error("File selection failed");
    return {};
}

std::vector<std::uint8_t> load_program(const std::string &path)
{
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if(!file) throw std::runtime_error("Could not open the selected file");

    const std::streamoff length = file.tellg();
    if(length <= 0) throw std::runtime_error("The selected file is empty");
    if(static_cast<std::uint64_t>(length) > maximum_program_size) {
        throw std::runtime_error("Program exceeds the 28 KiB application region");
    }

    std::vector<std::uint8_t> data(static_cast<std::size_t>(length));
    file.seekg(0);
    file.read(reinterpret_cast<char *>(data.data()), length);
    if(!file) throw std::runtime_error("Could not read the complete program");
    return data;
}

HANDLE open_serial(const std::string &port, DWORD baud_rate)
{
    const char prefix_chars[] = {92, 92, 46, 92, 0};
    const std::string prefix(prefix_chars);
    const std::string path =
        port.rfind(prefix, 0u) == 0u ? port : prefix + port;
    HANDLE serial = CreateFileA(path.c_str(), GENERIC_READ | GENERIC_WRITE,
                                0u, nullptr, OPEN_EXISTING, 0u, nullptr);
    if(serial == INVALID_HANDLE_VALUE) win32_error("Could not open serial port");

    DCB config{};
    config.DCBlength = sizeof(config);
    if(GetCommState(serial, &config) == FALSE) win32_error("GetCommState");
    config.BaudRate = baud_rate;
    config.ByteSize = 8u;
    config.Parity = NOPARITY;
    config.StopBits = ONESTOPBIT;
    config.fBinary = TRUE;
    config.fParity = FALSE;
    config.fOutxCtsFlow = FALSE;
    config.fOutxDsrFlow = FALSE;
    config.fOutX = FALSE;
    config.fInX = FALSE;
    config.fDtrControl = DTR_CONTROL_DISABLE;
    config.fRtsControl = RTS_CONTROL_DISABLE;
    if(SetCommState(serial, &config) == FALSE) win32_error("SetCommState");

    COMMTIMEOUTS timeouts{};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutConstant = 50u;
    timeouts.WriteTotalTimeoutConstant = 2000u;
    if(SetCommTimeouts(serial, &timeouts) == FALSE) win32_error("SetCommTimeouts");
    if(PurgeComm(serial, PURGE_RXCLEAR | PURGE_TXCLEAR) == FALSE) {
        win32_error("PurgeComm");
    }
    return serial;
}

void write_all(HANDLE serial, const std::uint8_t *data, std::size_t size)
{
    std::size_t offset = 0u;
    while(offset < size) {
        const DWORD request = static_cast<DWORD>(
            (size - offset) < 4096u ? (size - offset) : 4096u);
        DWORD written = 0u;
        if(WriteFile(serial, data + offset, request, &written, nullptr) == FALSE) {
            win32_error("Serial write failed");
        }
        if(written == 0u) throw std::runtime_error("Serial write made no progress");
        offset += written;
    }
}

bool wait_for_ack(HANDLE serial)
{
    const ULONGLONG deadline = GetTickCount64() + 5000u;
    while(GetTickCount64() < deadline) {
        std::uint8_t byte = 0u;
        DWORD received = 0u;
        if(ReadFile(serial, &byte, 1u, &received, nullptr) == FALSE) {
            win32_error("Serial read failed");
        }
        if(received == 1u && byte == handshake_response) return true;
    }
    return false;
}

const char usage_message[] =
    "Usage:\n"
    "  downloader.exe -p <port> -b <baud> [-f <program.bin>]\n\n"
    "Options:\n"
    "  -p, --port    Serial port, for example COM5\n"
    "  -b, --baud    Baud rate, for example 115200\n"
    "  -f, --file    Optional .bin path; otherwise open a file dialog\n"
    "  -h, --help    Show this help\n\n"
    "Examples:\n"
    "  downloader.exe -p COM5 -b 115200\n"
    "  downloader.exe -p COM5 -b 115200 -f program.bin";

void show_usage_dialog()
{
    MessageBoxA(nullptr, usage_message, "RISC-V UART Downloader",
                MB_OK | MB_ICONINFORMATION);
}

DWORD parse_baud_rate(const std::string &text)
{
    std::size_t consumed = 0u;
    const unsigned long value = std::stoul(text, &consumed, 10);
    if(consumed != text.size() || value == 0u) {
        throw std::runtime_error("Invalid baud rate: " + text);
    }
    return static_cast<DWORD>(value);
}

struct arguments {
    std::string port;
    std::string filename;
    DWORD baud_rate = 0u;
    bool help = false;
};

const char *option_value(int &index, int argc, char **argv)
{
    if(index + 1 >= argc) {
        throw std::runtime_error(
            std::string("Missing value for option: ") + argv[index]);
    }
    return argv[++index];
}

arguments parse_arguments(int argc, char **argv)
{
    arguments result;
    for(int index = 1; index < argc; ++index) {
        const std::string option = argv[index];
        if(option == "-p" || option == "--port") {
            result.port = option_value(index, argc, argv);
        }
        else if(option == "-b" || option == "--baud") {
            result.baud_rate = parse_baud_rate(option_value(index, argc, argv));
        }
        else if(option == "-f" || option == "--file") {
            result.filename = option_value(index, argc, argv);
        }
        else if(option == "-h" || option == "--help") {
            result.help = true;
        }
        else {
            throw std::runtime_error("Unknown option: " + option);
        }
    }

    if(!result.help && (result.port.empty() || result.baud_rate == 0u)) {
        throw std::runtime_error("Both --port and --baud are required");
    }
    return result;
}

} // namespace

int main(int argc, char **argv)
{
    std::cout << "RISCV User Program Downloader\n";

    if(argc == 1) {
        show_usage_dialog();
        return EXIT_FAILURE;
    }

    HANDLE serial = INVALID_HANDLE_VALUE;
    try {
        const arguments options = parse_arguments(argc, argv);
        if(options.help) {
            std::cout << usage_message << '\n';
            return EXIT_SUCCESS;
        }

        const std::string filename =
            options.filename.empty() ? select_program() : options.filename;
        if(filename.empty()) {
            std::cout << "Download cancelled.\n";
            return EXIT_SUCCESS;
        }

        const std::vector<std::uint8_t> program = load_program(filename);
        serial = open_serial(options.port, options.baud_rate);

        std::cout << "Connecting to " << options.port << "...\n";
        write_all(serial, &handshake_request, 1u);
        if(!wait_for_ack(serial)) {
            throw std::runtime_error("No 0xFE bootloader response within 5 seconds");
        }

        const std::uint32_t size = static_cast<std::uint32_t>(program.size());
        const std::array<std::uint8_t, 4> encoded_size{
            static_cast<std::uint8_t>(size),
            static_cast<std::uint8_t>(size >> 8u),
            static_cast<std::uint8_t>(size >> 16u),
            static_cast<std::uint8_t>(size >> 24u)
        };
        write_all(serial, encoded_size.data(), encoded_size.size());
        write_all(serial, program.data(), program.size());
        if(FlushFileBuffers(serial) == FALSE) win32_error("FlushFileBuffers");

        CloseHandle(serial);
        std::cout << "Sent " << program.size()
                  << " bytes.\n";
        std::cout << "Flashing done.\n";
        return EXIT_SUCCESS;
    }
    catch(const std::exception &error) {
        if(serial != INVALID_HANDLE_VALUE) CloseHandle(serial);
        std::cerr << "Downloader error: " << error.what() << '\n';
        //std::cerr << usage_message << '\n';
        return EXIT_FAILURE;
    }
}
