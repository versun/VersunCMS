import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "toggle"]

  connect() {
    // 点击遮罩层关闭侧边栏
    if (this.hasOverlayTarget) {
      this.overlayTarget.addEventListener("click", () => this.close())
    }
    
    // 点击侧边栏链接后关闭菜单（移动端）
    if (this.hasSidebarTarget) {
      const links = this.sidebarTarget.querySelectorAll("a.nav-link")
      links.forEach(link => {
        link.addEventListener("click", () => {
          // 只在移动端关闭（屏幕宽度小于768px）
          if (window.innerWidth < 768) {
            this.close()
          }
        })
      })
    }

    this.syncAria()
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.add("sidebar-open")
      document.body.style.overflow = "hidden"
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("overlay-visible")
    }
    this.syncAria()
  }

  close() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove("sidebar-open")
      document.body.style.overflow = ""
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("overlay-visible")
    }
    this.syncAria()
  }

  isOpen() {
    return this.hasSidebarTarget && this.sidebarTarget.classList.contains("sidebar-open")
  }

  syncAria() {
    if (!this.hasToggleTarget) return

    const expanded = this.isOpen()
    this.toggleTargets.forEach(toggle => {
      toggle.setAttribute("aria-expanded", expanded ? "true" : "false")
    })
  }
}
