import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["spinner", "content"]

    connect() {
        this.frameId = this.element.id
        this.observer = null
        
        // 监听链接点击事件
        this.element.addEventListener("click", this.handleLinkClick.bind(this), true)
        
        // 监听 Turbo Frame 加载完成事件
        document.addEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
        document.addEventListener("turbo:frame-missing", this.handleFrameMissing.bind(this))
        
        // 使用 MutationObserver 监听 frame 的 busy 属性变化
        this.setupBusyObserver()
    }

    disconnect() {
        this.element.removeEventListener("click", this.handleLinkClick.bind(this), true)
        document.removeEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
        document.removeEventListener("turbo:frame-missing", this.handleFrameMissing.bind(this))
        this.stopBusyObserver()
    }

    setupBusyObserver() {
        // 监听 frame 元素的属性变化，特别是 busy 属性
        this.observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.type === 'attributes' && mutation.attributeName === 'busy') {
                    if (this.element.hasAttribute('busy')) {
                        // Frame 开始加载
                        this.showLoading()
                    } else {
                        // Frame 加载完成
                        // 延迟一点隐藏，确保内容已渲染
                        setTimeout(() => {
                            this.hideLoading()
                        }, 100)
                    }
                }
            })
        })
        
        this.observer.observe(this.element, {
            attributes: true,
            attributeFilter: ['busy']
        })
    }

    stopBusyObserver() {
        if (this.observer) {
            this.observer.disconnect()
            this.observer = null
        }
    }

    handleLinkClick(event) {
        // 检查点击的是否是链接
        const link = event.target.closest("a")
        if (link && link.href && !link.target) {
            // 立即显示加载状态（Turbo 会在点击后很快添加 busy 属性）
            setTimeout(() => {
                if (this.element.hasAttribute('busy')) {
                    this.showLoading()
                }
            }, 10)
        }
    }

    handleFrameLoad(event) {
        // 检查是否是当前 frame 加载完成
        if (event.target?.id === this.frameId) {
            this.hideLoading()
        }
    }

    handleFrameMissing(event) {
        // 检查是否是当前 frame 缺失
        if (event.target?.id === this.frameId) {
            this.hideLoading()
        }
    }

    showLoading() {
        if (this.hasSpinnerTarget) {
            this.spinnerTarget.style.display = "flex"
        }
        if (this.hasContentTarget) {
            this.contentTarget.style.opacity = "0.5"
            this.contentTarget.style.transition = "opacity 0.3s ease"
        }
    }

    hideLoading() {
        if (this.hasSpinnerTarget) {
            this.spinnerTarget.style.display = "none"
        }
        if (this.hasContentTarget) {
            this.contentTarget.style.opacity = "1"
        }
    }
}

