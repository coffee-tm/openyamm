#include "game/app/OpenYammMain.h"

#include <SDL3/SDL.h>

#if defined(OPENYAMM_SWITCH_ROMFS)
#include <switch.h>
#endif

#include <cstdio>
#include <filesystem>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

#ifndef OPENYAMM_SWITCH_USER_DATA_DIR
#define OPENYAMM_SWITCH_USER_DATA_DIR "sdmc:/switch/openyamm"
#endif

namespace
{
#if defined(OPENYAMM_SWITCH_ROMFS)
bool romfsMounted = false;

bool mountRomfs()
{
    const Result result = romfsInit();

    if (R_FAILED(result))
    {
        std::fprintf(stderr, "romfsInit failed: %08x; falling back to SD-card assets\n", result);
        return false;
    }

    romfsMounted = true;
    return true;
}

void unmountRomfs()
{
    if (romfsMounted)
    {
        romfsExit();
        romfsMounted = false;
    }
}
#else
bool mountRomfs()
{
    return true;
}

void unmountRomfs()
{
}
#endif

bool prepareSwitchUserDataDirectory()
{
    std::error_code error;
    const std::filesystem::path userDataRoot(OPENYAMM_SWITCH_USER_DATA_DIR);

    std::filesystem::create_directories(userDataRoot, error);

    if (error)
    {
        std::fprintf(stderr, "Failed to create Switch user data directory %s: %s\n",
                     userDataRoot.string().c_str(), error.message().c_str());
        return false;
    }

    std::filesystem::current_path(userDataRoot, error);

    if (error)
    {
        std::fprintf(stderr, "Failed to enter Switch user data directory %s: %s\n",
                     userDataRoot.string().c_str(), error.message().c_str());
        return false;
    }

    std::printf("Switch user data directory: %s\n", userDataRoot.string().c_str());
    return true;
}

std::string switchAssetRoot()
{
#if defined(OPENYAMM_SWITCH_ASSET_ROOT)
    return OPENYAMM_SWITCH_ASSET_ROOT;
#else
    return std::string(OPENYAMM_SWITCH_USER_DATA_DIR) + "/assets";
#endif
}

bool hasExplicitAssetRoot(int argc, char **argv)
{
    for (int index = 1; index < argc; ++index)
    {
        if (argv[index] != nullptr && std::string_view(argv[index]) == "--asset-root")
        {
            return true;
        }
    }

    return false;
}

int runWithSwitchArguments(int argc, char **argv)
{
    if (hasExplicitAssetRoot(argc, argv))
    {
        return OpenYAMM::Game::runApplication(argc, argv);
    }

    std::vector<char *> arguments;
    arguments.reserve(static_cast<size_t>(argc) + 2);

    const char *pExecutable = (argc > 0 && argv[0] != nullptr) ? argv[0] : "openyamm";
    arguments.push_back(const_cast<char *>(pExecutable));

    for (int index = 1; index < argc; ++index)
    {
        arguments.push_back(argv[index]);
    }

    // These strings outlive the runApplication call and are read-only to its argument parser.
    std::string assetRootOption = "--asset-root";
    std::string assetRootValue = switchAssetRoot();
    arguments.push_back(assetRootOption.data());
    arguments.push_back(assetRootValue.data());

    std::printf("Switch asset root: %s\n", assetRootValue.c_str());
    return OpenYAMM::Game::runApplication(static_cast<int>(arguments.size()), arguments.data());
}
} // namespace

int main(int argc, char **argv)
{
    SDL_SetAppMetadata("OpenYAMM", nullptr, "io.github.openyamm.OpenYAMM");
    // SDL3 uses positional face buttons; setting the legacy SDL2 hint name as well keeps older SDL3 snapshots that
    // still honour it consistent. GamepadInput swaps that diamond to the console's A/B layout on Switch.
    SDL_SetHint("SDL_GAMECONTROLLER_USE_BUTTON_LABELS", "0");

    const bool romfsReady = mountRomfs();

    if (!prepareSwitchUserDataDirectory())
    {
        unmountRomfs();
        return 2;
    }

#if defined(OPENYAMM_SWITCH_ROMFS)
    if (!romfsReady && switchAssetRoot().starts_with("romfs:"))
    {
        std::fprintf(stderr, "ROMFS assets were requested but are not mounted; check NRO packaging.\n");
        unmountRomfs();
        return 2;
    }
#else
    (void)romfsReady;
#endif

    const int result = runWithSwitchArguments(argc, argv);
    unmountRomfs();
    return result;
}
