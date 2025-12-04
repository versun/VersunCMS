import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    // 从localStorage读取保存的主题，如果没有则使用系统偏好
    const savedTheme = localStorage.getItem('theme')
    const currentTheme = document.documentElement.getAttribute('data-theme')
    
    if (savedTheme) {
      this.applyTheme(savedTheme)
    } else if (!currentTheme) {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      this.applyTheme(prefersDark ? 'dark' : 'light')
    } else {
      // 如果已经有主题设置，更新图标
      this.updateIcon(currentTheme)
    }
  }

  toggle() {
    const currentTheme = document.documentElement.getAttribute('data-theme')
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
    this.applyTheme(newTheme)
    localStorage.setItem('theme', newTheme)
  }

  applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme)
    this.updateIcon(theme)
  }

  updateIcon(theme) {
    if (this.hasIconTarget) {
      if (theme === 'dark') {
        this.iconTarget.classList.remove('fa-moon')
        this.iconTarget.classList.add('fa-sun')
      } else {
        this.iconTarget.classList.remove('fa-sun')
        this.iconTarget.classList.add('fa-moon')
      }
    }
  }
}

