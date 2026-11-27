#include "engine/PlatformServices.h"

#include <SDL3/SDL.h>

namespace OpenYAMM::Engine
{
bool openExternalUrl(const std::string &url)
{
#if defined(OPENYAMM_SWITCH)
    (void)url;
    return false;
#else
    if (url.empty())
    {
        return false;
    }

    return SDL_OpenURL(url.c_str());
#endif
}
}
