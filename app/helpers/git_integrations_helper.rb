module GitIntegrationsHelper
  def provider_help_text(provider)
    case provider
    when "github"
      "获取凭据: GitHub → Settings → Developer settings → Personal access tokens → Generate new token (需要 repo 权限)"
    when "gitlab"
      "获取凭据: GitLab → User Settings → Access Tokens → Add new token (需要 write_repository 权限)"
    when "gitea"
      "获取凭据: Gitea → User Settings → Applications → Generate New Token"
    when "codeberg"
      "获取凭据: Codeberg → User Settings → Applications → Generate New Token"
    when "bitbucket"
      "获取凭据: Bitbucket → Personal settings → App passwords → Create app password (需要 repository write 权限)"
    else
      ""
    end
  end

  def token_label(provider)
    case provider
    when "bitbucket"
      "App Password"
    else
      "Access Token"
    end
  end

  def username_label(provider)
    case provider
    when "bitbucket"
      "Username"
    when "gitea", "codeberg"
      "Username (Optional)"
    else
      ""
    end
  end

  def username_placeholder(provider)
    case provider
    when "bitbucket"
      "your-bitbucket-username"
    when "gitea", "codeberg"
      "your-username"
    else
      ""
    end
  end

  def username_help_text(provider)
    case provider
    when "bitbucket"
      "Bitbucket 用户名（用于 App Password 的 Basic Auth）"
    when "gitea", "codeberg"
      "可选：某些服务在 git push 时需要用户名（Token 作为密码）"
    else
      ""
    end
  end

  def token_placeholder(provider)
    case provider
    when "github"
      "ghp_xxxxxxxxxxxx 或 github_pat_xxxxxxxxxxxx"
    when "gitlab"
      "glpat-xxxxxxxxxxxx"
    when "gitea", "codeberg"
      "xxxxxxxxxxxxxxxx"
    when "bitbucket"
      "xxxx-xxxx-xxxx-xxxx"
    else
      ""
    end
  end

  def token_help_text(provider)
    case provider
    when "github"
      "Personal Access Token，需要 repo 权限"
    when "gitlab"
      "Personal Access Token，需要 write_repository 权限"
    when "gitea"
      "Access Token，需要 repository 权限"
    when "codeberg"
      "Access Token，需要 repository 权限"
    when "bitbucket"
      "App Password，需要 repository write 权限"
    else
      ""
    end
  end
end
