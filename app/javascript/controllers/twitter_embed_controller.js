import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        url: String
    }
    static classes = ["loading"]

    connect() {
        this.loadTweet()
    }

    async loadTweet() {
        if (!this.urlValue) return

        // 添加加载状态
        if (this.hasLoadingClass) {
            this.element.classList.add(...this.loadingClasses)
        }

        try {
            // 调用后端 API 获取推文内容
            const response = await fetch(`/api/twitter/oembed?url=${encodeURIComponent(this.urlValue)}`, {
                method: "GET",
                headers: {
                    "Accept": "application/json",
                    "X-Requested-With": "XMLHttpRequest"
                }
            })

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`)
            }

            const data = await response.json()

            if (data.error) {
                throw new Error(data.error)
            }

            // 渲染推文内容
            this.renderTweet(data)
        } catch (error) {
            console.error("Error loading tweet:", error)
            this.renderError()
        } finally {
            // 移除加载状态
            if (this.hasLoadingClass) {
                this.element.classList.remove(...this.loadingClasses)
            }
        }
    }

    renderTweet(tweetContent) {
        const tweetDiv = document.createElement("div")
        tweetDiv.className = "twitter-tweet-content"

        // 推文文本
        if (tweetContent.text) {
            const textLink = document.createElement("a")
            textLink.href = this.urlValue
            textLink.target = "_blank"
            textLink.rel = "noopener noreferrer"
            textLink.className = "twitter-tweet-content__text-link"

            const textP = document.createElement("p")
            textP.className = "twitter-tweet-content__text"
            textP.textContent = tweetContent.text
            textLink.appendChild(textP)

            tweetDiv.appendChild(textLink)
        }

        // 作者信息
        if (tweetContent.author_display_name || tweetContent.author_username) {
            const authorDiv = document.createElement("div")
            authorDiv.className = "twitter-tweet-content__author"

            const authorLink = document.createElement("a")
            authorLink.href = tweetContent.author_url || this.urlValue
            authorLink.target = "_blank"
            authorLink.rel = "noopener noreferrer"
            authorLink.className = "twitter-tweet-content__author-link"

            // 头像
            if (tweetContent.author_avatar) {
                const avatarImg = document.createElement("img")
                avatarImg.className = "twitter-tweet-content__avatar"
                avatarImg.src = tweetContent.author_avatar
                avatarImg.alt = tweetContent.author_display_name || `@${tweetContent.author_username}`
                authorLink.appendChild(avatarImg)
            }

            // 作者信息容器
            const authorInfo = document.createElement("div")
            authorInfo.className = "twitter-tweet-content__author-info"

            // 显示名称
            if (tweetContent.author_display_name) {
                const displayNameSpan = document.createElement("span")
                displayNameSpan.className = "twitter-tweet-content__author-display-name"
                displayNameSpan.textContent = tweetContent.author_display_name
                authorInfo.appendChild(displayNameSpan)
            }

            // 用户名
            if (tweetContent.author_username) {
                const usernameSpan = document.createElement("span")
                usernameSpan.className = "twitter-tweet-content__author-username"
                usernameSpan.textContent = `@${tweetContent.author_username}`
                authorInfo.appendChild(usernameSpan)
            }

            authorLink.appendChild(authorInfo)
            authorDiv.appendChild(authorLink)
            tweetDiv.appendChild(authorDiv)
        }

        // 替换占位符内容
        this.element.innerHTML = ""
        this.element.appendChild(tweetDiv)
    }

    renderError() {
        const errorDiv = document.createElement("div")
        errorDiv.className = "twitter-tweet-placeholder__error"
        errorDiv.innerHTML = `
            <p>无法加载推文内容，请检查您的网络</p>
            <a href="${this.urlValue}" target="_blank" rel="noopener noreferrer" class="twitter-tweet-placeholder__fallback-link">
                查看原始推文
            </a>
        `
        this.element.innerHTML = ""
        this.element.appendChild(errorDiv)
    }
}
