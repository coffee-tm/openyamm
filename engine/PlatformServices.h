#pragma once

#include <string>

namespace OpenYAMM::Engine
{
// Opens a URL in the host's browser. Switch homebrew has no browser integration, so this is a no-op there.
bool openExternalUrl(const std::string &url);
}
