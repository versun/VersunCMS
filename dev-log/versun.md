# 2025-01-20
准备添加一个sitemap功能，方便搜索引擎爬取，还有添加自定义静态页面，比如robots.txt等

# 2025-01-18
总算大体完成了所有想要的功能了，接下来就是测试，然后上线了

# 2025-01-13
最近重写了备份方式，直接备份sqlite db文件，然后添加了S3配置，备份到S3服务器中。
现在离使用还差最后一步，wordpress的图片导入还有点问题，图片无法关联到对应的content上.
还是不用wp导入，直接使用rss导入吧，其它草稿/页面自己手动导入

# 2024-12-13
删除了所有测试。
添加了static file到设置页面
准备把services文件删除，移到models中，以符合rails的最佳实践

# 2024-12-10
写测试太烦了，等最后阶段在写吧

# 2024-12-07
给文章添加了 description 字段，这样首页可以直接显示description，还有交叉发布时，也是首选description，然后是content

# 2024-12-03
准备开始写功能测试，方便ai重构时能保证功能正常。
写了测试才知道，好多功能耦合度太高了，比如settings，把它改为一个service，降低耦合度

# 2024-11-28
添加了cross post to twitter功能，本来还想加上reddit等平台，但目前我暂时用不到reddit等平台，所以等以后再加吧

# 2024-11-27
添加了cross post功能，完成mastodon的cross post

# 2024-11-20
添加多站点功能，这样就不需要每个站点都部署一个rails应用了。
在admin bar下添加一个sites页面，可以查看和管理站点，可以将某个站点设置为默认，然后创建新站点就是创建一个新的路由，比如“127.0.0.1:3000/blog”
每个站点关联一个setting，一个user，多个article

算了，增加了不少复杂度，后期再弄吧，先上线再说

# 2024-11-18
决定还是把tag功能删掉，因为tag会增加写作负担，至少我自己是这样的，所以就纯粹些，不要tag了
加一个搜索功能，参考：https://www.teloslabs.co/post/full-text-search-with-rails-and-sqlite

# 2024-11-15
使用[mise](https://mise.jdx.dev/)做为ruby的虚拟环境管理挺不错，很好用

# 2024-11-13
这几天一直在折腾replit的ruby和rails环境，replit非常难用，虽然底层用的nix，但nix的包都是replit的维护，然后包更新的非常慢，完全跟不上nix官方的，这就导致你没法用上最新的包。
发邮件给技术客服好多次，没一次解决的，都是回复说“我们会加的”。。。
最后曲线救国，在工作目录安装asdf来管理环境，勉强能用。累人。。replit还不能退款。。。。

# 2024-11-5
使用纯html编写页面，删除了所有css，太烦了调css！！！TMD
接下来，准备写文章预约发布的功能，参考：https://edgeguides.rubyonrails.org/active_job_basics.html

# 2024-11-4
添加了social links图标功能
准备把admin页面单独做个view，否则每一个页面都判断一次admin权限，有点费性能。

# 2024-10-28
将文章的路由绑定到“/blog”下，以保持原来我的博客的链接不失效

# 2024-10-27
使用claude 3.5 sonnet V2重新写了Wordpress Importer，3轮就写的很完美了，不错
接下里，加个git备份附带静态网站，然后加个预约发布，就可以上线了，先自己用吧

# 2024-10-25
在使用Zip Importer时，处理附件时，要使用正则表达式替换2个url和sgid才可以更新content.body中附件的引用
导入zip的逻辑是，删除已有的，然后覆盖

# 2024-10-24
导入时，如果内容有附件，则一直无法将内容里的附件url更新为新的url，有点奇怪，得去看下action_text和active_storage的文档，AI一直解决不了这个问题

# 2024-10-23
重新写了导出和导入逻辑，ai写的有点过于啰嗦麻烦了

# 2024-10-22
给文章列表添加了一些样式，好烦写css
添加了wordpress图片下载导入功能，整个函数都是用claude 3.5 sonnet写的，一次就成，有点牛逼

# 2024-10-21
准备开始写WordPress导入功能

# 2024-10-20
添加了settings页面

# 2024-10-19
才发现rails的action_text自带了trix-editor，所以不需要再额外安装trix-editor了：https://guides.rubyonrails.org/action_text_overview.html
如果内容图片有视频或者pdf，则需要安装第三方软件：https://guides.rubyonrails.org/active_storage_overview.html#requirements
  比如要显示图片，则必须`gem install ruby-vips`, 然后系统上也要安装libvips库
  在Nix系统上，则需要安装`pkgs.rubyPackages_3_3.ruby-vips`
注意，article模型不需要添加content字段，只需在article model中添加has_rich_text :content即可
添加了分页功能

# 2024-10-18
本来想加个多用户功能，但想了想先不加了，赶紧搞出最小可用版本再说

# 2024-10-16
本来想使用css框架来做样式，比如Picnic、Bulma、Pico等，但都好大，还是乖乖自己写吧，没多少
给tags模型添加了is_page属性，这样也可以将tag页的文章做为page

# 2024-10-15
稍微加了些样式，然后手动route / 到 articles，为了防止影响其他模型路径（比如session），需要把article的路径移动到最下方(优先级最低)

# 2024-10-14
给article添加一个is_page字段，可做为页面发布，而不是博文。
由于直接在db/migrate下文件修改，所以还需要删除db/schema.rb，然后再重新migrate生成新的schema文件才可以用

# 2024-10-13
article使用slug作为params，而不是用默认的id

# 2024-10-11
准备做个博客，用刚学的Rails 8.0版本
记录下初始化过程：
1. 添加`gem "rails", "~> 8.0.0.beta1"`到Gemfile中
2. `bundle install`
3. `rails new .`
4. 由于是在云IDE(Replit)上开发，所以还需要修改下面2个文件
   ```
   # File: config/application.rb
   # add below codes in Application class
     config.action_dispatch.default_headers = {
       "X-Frame-Options" => "ALLOWFROM replit.com"
     }
   ```
   ```
     # File: config/environments/development.rb
     # add below code in Rails.application.configure
       config.hosts << /.*\.replit.dev/
     ```
5. 运行`bin/rails server`就能看到Rails的示例页面
6. 一键创建用户认证系统：`bin/rails g authentication`
7. 数据模型写入：`bin/rails db:migrate`
8. `bin/rails g model Articles title:string content:text slug:string:uniq`
9. `bin/rails g model Tags name:string`
10. 由于article和tag是多对多的关系，所以还需要生成join表，运行`bin/rails g migration CreateArticlesTagsJoinTable articles tags`
11. 在创建的迁移文件中，取消index代码的注释
12. `忘记创建status字段了...`bin/rails g migration AddStatusToArticles status:integer`
13. status字段使用enum来定义
    ```
    # File: model/article.rb in Article class
        enum :status, [ :draft, :publish, :schedule, :trash ]
    ```
14. `bin/rails db:migrate`
15. 由于使用了rails 8的新认证系统，省了非常多的步骤
    对于不需要认证的action，只要添加allow_unauthenticated_access即可
    ```
    class ArticlesController < ApplicationController
      allow_unauthenticated_access only: %i[ index ]
      ...
    ```
接下来就是开始写博客逻辑和页面了
