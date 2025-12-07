# 测试文档

本目录包含VersunCMS的完整测试套件，旨在提高代码功能的可用性和可靠性。

## 测试结构

### 1. 测试配置
- `test_helper.rb` - 测试环境配置和通用辅助方法
- `application_system_test_case.rb` - 系统测试基类配置

### 2. 模型测试 (`test/models/`)
测试所有ActiveRecord模型的核心功能：

- **article_test.rb** - 文章模型测试
  - Slug生成和唯一性验证
  - 状态管理（draft, publish, schedule, trash）
  - 标签关联
  - 搜索功能
  - 关联关系

- **user_test.rb** - 用户模型测试
  - 用户认证
  - 密码加密
  - 用户名规范化
  - 会话管理

- **subscriber_test.rb** - 订阅者模型测试
  - 邮箱验证
  - 确认流程
  - 退订功能
  - 标签订阅

- **tag_test.rb** - 标签模型测试
  - 标签创建和查找
  - Slug生成
  - 文章关联

- **comment_test.rb** - 评论模型测试
  - 评论验证
  - 外部评论（Mastodon, Bluesky, Twitter）
  - 评论层级关系
  - 状态管理

### 3. 控制器测试 (`test/controllers/`)
测试HTTP请求处理和业务逻辑：

- **articles_controller_test.rb** - 文章控制器
  - 公开访问（index, show）
  - 认证访问（create, update, destroy）
  - RSS feed
  - 搜索功能

- **admin/articles_controller_test.rb** - 管理后台文章控制器
  - CRUD操作
  - 批量操作（标签、发布、删除）
  - 状态管理
  - 评论获取

- **sessions_controller_test.rb** - 会话控制器
  - 登录/登出
  - 认证验证

- **subscriptions_controller_test.rb** - 订阅控制器
  - 订阅创建
  - 确认流程
  - 退订流程

### 4. 系统测试 (`test/system/`)
端到端的浏览器测试：

- **articles_test.rb** - 文章系统测试
  - 用户界面交互
  - 表单提交
  - 页面导航

- **sessions_test.rb** - 会话系统测试
  - 登录流程
  - 登出流程

- **subscriptions_test.rb** - 订阅系统测试
  - 订阅表单
  - 确认页面
  - 退订页面

### 5. 集成测试 (`test/integration/`)
测试完整的业务流程：

- **article_workflow_test.rb** - 文章工作流
  - 创建→发布→查看完整流程
  - 定时发布流程
  - 删除流程
  - 搜索流程
  - 标签管理流程

- **subscription_workflow_test.rb** - 订阅工作流
  - 订阅→确认→退订完整流程
  - 标签订阅流程
  - 错误处理

### 6. 测试数据 (`test/fixtures/`)
预定义的测试数据：

- `users.yml` - 用户数据
- `articles.yml` - 文章数据
- `tags.yml` - 标签数据
- `subscribers.yml` - 订阅者数据
- `comments.yml` - 评论数据
- `settings.yml` - 设置数据

## 运行测试

### 运行所有测试
```bash
bin/rails test
```

### 运行特定测试文件
```bash
bin/rails test test/models/article_test.rb
```

### 运行特定测试用例
```bash
bin/rails test test/models/article_test.rb:10
```

### 运行系统测试
```bash
bin/rails test:system
```

### 并行运行测试
测试已配置为并行运行，使用所有可用的CPU核心。

## 测试辅助方法

`test_helper.rb` 提供了以下辅助方法：

- `create_user(user_name:, password:)` - 创建测试用户
- `sign_in(user)` - 模拟用户登录
- `create_published_article(attributes)` - 创建已发布文章
- `create_draft_article(attributes)` - 创建草稿文章
- `create_tag(name:, slug:)` - 创建标签
- `create_subscriber(email:, confirmed:)` - 创建订阅者

## 测试覆盖范围

### 已覆盖功能
- ✅ 用户认证和授权
- ✅ 文章CRUD操作
- ✅ 文章状态管理
- ✅ 标签系统
- ✅ 订阅者管理
- ✅ 评论系统基础功能
- ✅ 搜索功能
- ✅ RSS feed
- ✅ 批量操作

### 待扩展测试
- ⏳ 跨平台发布功能（需要API mocking）
- ⏳ 新闻通讯发送（需要邮件服务mocking）
- ⏳ 定时任务
- ⏳ 文件上传
- ⏳ 重定向功能
- ⏳ 页面管理

## 最佳实践

1. **测试隔离** - 每个测试应该独立运行，不依赖其他测试的状态
2. **使用Fixtures** - 优先使用fixtures而非在测试中创建数据
3. **测试命名** - 使用描述性的测试名称，说明测试的目的
4. **断言清晰** - 使用明确的断言消息
5. **避免测试实现细节** - 测试行为而非实现

## 持续集成

测试套件设计为在CI/CD环境中运行。确保：
- 测试数据库正确配置
- 所有依赖已安装
- 系统测试的浏览器驱动已配置

