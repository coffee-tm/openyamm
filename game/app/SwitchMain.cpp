#include "game/app/OpenYammMain.h"

#include <SDL3/SDL.h>

#if defined(OPENYAMM_SWITCH_ROMFS)
#include <switch.h>
#endif

#include <cstdio>
#include <string>
#include <vector>

namespace
{
#if defined(OPENYAMM_SWITCH_ROMFS)
void mountRomfs()
{
    const Result result = romfsInit();
    if (R_FAILED(result))
    {
        std::fprintf(stderr, "romfsInit failed: %08x; continuing without ROMFS\n", result);
    }
}

void unmountRomfs()
{
    romfsExit();
}
#else
void mountRomfs()
{
}

void unmountRomfs()
{
}
#endif

int runWithSwitchArguments(int argc, char **argv)
{
#if defined(OPENYAMM_SWITCH_ROMFS) && defined(OPENYAMM_SWITCH_ASSET_ROOT)
    // The NRO carries its content in ROMFS when OPENYAMM_SWITCH_ROMFS_DIR is configured. Force the game to read it
    // instead of a desktop-style installed asset root.
    std::vector<char *> arguments;
    arguments.reserve(static_cast<size_t>(argc) + 3);

    const char *pExecutable = (argc > 0 && argv[0] != nullptr) ? argv[0] : "openyamm";
    arguments.push_back(const_cast<char *>(pExecutable));
    for (int index = 1; index < argc; ++index)
    {
        arguments.push_back(argv[index]);
    }

    std::string assetRootArgument = "--asset-root";
    std::string assetRootValue = OPENYAMM_SWITCH_ASSET_ROOT;
    arguments.push_back(assetRootArgument.data());
    arguments.push_back(assetRootValue.data());

    return OpenYAMM::Game::runApplication(static_cast<int>(arguments.size()), arguments.data());
#else
    return OpenYAMM::Game::runApplication(argc, argv);
#endif
}
} // namespace

int main(int argc, char **argv)
{
    mountRomfs();
    SDL_SetAppMetadata("OpenYAMM", nullptr, "io.github.openyamm.OpenYAMM");

    const int result = runWithSwitchArguments(argc, argv);
    unmountRomfs();
    return result;
}
