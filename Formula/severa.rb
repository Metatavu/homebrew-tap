require "download_strategy"

# Installs the Severa CLI from private release assets.
#
# Requires HOMEBREW_GITHUB_API_TOKEN, because the repository is private. Without
# it Homebrew receives a 404 rather than an authentication error, which is
# confusing enough to be worth stating up front:
#
#   export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
class Severa < Formula
  desc "Controlled access to Severa for people, CI and agents"
  homepage "https://github.com/Metatavu/severa-cli"
  version "0.1.0"
  license "UNLICENSED"

  on_macos do
    on_arm do
      url "https://github.com/Metatavu/severa-cli/releases/download/v0.1.0/severa-darwin-arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "4a1d9d5438a5ad3905989a01fffa01a6b57cfd9a1ed77af75e6af0211594f49c"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Metatavu/severa-cli/releases/download/v0.1.0/severa-linux-amd64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "8435d3f5cbd018524a5b2d95f3d0a34883c3755b08a80f1378ab1a5cff95d972"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Metatavu/severa-cli/releases/download/v0.1.0/severa-linux-arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "7b65a7eade27fb7f69280fcb148d892107d7d92cf6fd05f1f525acca05f8cf3b"
    end
  end


  def install
    bin.install "severa"
  end

  def caveats
    <<~EOS
      severa needs a gateway URL and, for anything acting on your behalf, a sign-in:

        export SEVERA_GATEWAY_URL=https://severa-gateway.example.fi
        severa auth login

      Downloads require a GitHub token, since the repository is private:

        export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
    EOS
  end

  test do
    assert_match "severa #{version}", shell_output("#{bin}/severa --version")
    # Exits 3, "authentication required", with no credentials configured.
    shell_output("#{bin}/severa auth status --local", 3)
  end
end
