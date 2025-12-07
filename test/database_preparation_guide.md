# 测试数据库准备指南

## 问题说明

当运行 `bin/rails test` 时，Rails会准备测试数据库。对于多数据库配置（primary, cache, cable, queue），如果测试数据库是空的，Rails可能会将空的schema写入到schema文件中，导致 `cache_schema.rb`、`cable_schema.rb`、`queue_schema.rb` 等文件被清空。

## 解决方案

已在 `config/environments/test.rb` 中配置：
```ruby
config.active_record.dump_schema_after_migration = false
```

这会防止测试环境在迁移后转储schema，从而避免覆盖开发环境的schema文件。

## 手动准备测试数据库

如果需要手动准备测试数据库，请使用：

```bash
# 准备所有数据库
bin/rails db:test:prepare

# 或者分别准备
RAILS_ENV=test bin/rails db:schema:load
```

## 恢复被清空的Schema文件

如果schema文件已经被清空，可以通过以下方式恢复：

1. **从开发数据库重新生成**：
```bash
RAILS_ENV=development bin/rails db:schema:dump
```

2. **从Git恢复**（如果已提交）：
```bash
git checkout db/cache_schema.rb db/cable_schema.rb db/queue_schema.rb
```

3. **重新运行迁移**：
```bash
RAILS_ENV=development bin/rails db:migrate
```

## 注意事项

- Schema文件应该从开发环境生成，而不是从测试环境
- 测试数据库是临时性的，不应该影响开发环境的schema文件
- 如果需要在测试中修改schema，应该使用迁移文件，而不是直接编辑schema文件

