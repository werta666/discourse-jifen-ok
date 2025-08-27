# 🔧 Discourse 熊猫插件技术实现指南

本文档详细说明了如何成功实现一个在 Discourse 中可访问的 `/panda` 路由，经过多次调试和优化后的最终解决方案。

## 🎯 最终成功的实现方案

经过多次尝试和调试，最终成功的关键在于使用 **Rails Engine 架构** + **Ember v5.12.0 现代化前端** + **Glimmer Components 渲染**。

## 📋 环境要求

### 必需版本
- **Discourse**: v2.7.0+
- **Ember**: v5.12.0
- **Ruby**: 2.7+
- **Rails**: 6.1+

### 浏览器支持
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

### 开发环境
- Node.js 16+ (用于前端资源编译)
- 支持 ES6+ 语法的现代浏览器

## 🎨 关键技术决策

### 渲染组件选择：Glimmer Components (非 Widget)

**✅ 使用 Glimmer Components 的原因**：
- 符合 Ember v5.12.0 现代标准
- 更好的响应式状态管理 (`@tracked`)
- 现代化的事件处理 (`@action`)
- 更清晰的代码结构和维护性
- 更好的性能和类型安全

**❌ 不使用 Widget 的原因**：
- Widget 是较老的 Discourse 特有方式
- 在 Ember v5.12.0 中不是推荐做法
- 代码复杂度更高，维护困难

## � Rails Engine 最小可用配置

### 完整的最小文件结构（防止 502）

```
discourse-panda-plugin/
├── plugin.rb                                    # 主配置
├── lib/
│   └── panda_plugin_module/
│       └── engine.rb                            # Engine 定义
├── config/
│   ├── routes.rb                                # Engine 路由
│   └── settings.yml                             # 插件设置
└── app/
    └── controllers/
        └── panda_plugin_module/
            └── panda_controller.rb              # 控制器
```

### 最小可用的 plugin.rb 模板

```ruby
# frozen_string_literal: true

# name: discourse-panda-plugin
# about: A Panda-themed plugin
# version: 0.0.1
# authors: Panda_CC
# required_version: 2.7.0

enabled_site_setting :panda_plugin_enabled

module ::PandaPluginModule
  PLUGIN_NAME = "discourse-panda-plugin"
end

require_relative "lib/panda_plugin_module/engine"

after_initialize do
  Discourse::Application.routes.append do
    mount ::PandaPluginModule::Engine, at: "/panda"
  end
end
```

### 最小可用的 engine.rb 模板

```ruby
# frozen_string_literal: true

module ::PandaPluginModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace PandaPluginModule
  end
end
```

### 最小可用的 routes.rb 模板

```ruby
# frozen_string_literal: true

PandaPluginModule::Engine.routes.draw do
  get "/" => "panda#index"
end
```

### 最小可用的控制器模板

```ruby
# frozen_string_literal: true

module ::PandaPluginModule
  class PandaController < ::ApplicationController
    requires_plugin PandaPluginModule::PLUGIN_NAME

    def index
      render plain: "🐼 Panda Plugin Working!"
    end
  end
end
```

## �📋 核心文件结构

### 1. 插件主配置文件 (`plugin.rb`)

```ruby
# frozen_string_literal: true

# name: discourse-panda-plugin
# about: A Panda-themed plugin that adds a custom /panda page with interactive content
# meta_topic_id: TODO
# version: 0.0.1
# authors: Panda_CC
# url: TODO
# required_version: 2.7.0

enabled_site_setting :panda_plugin_enabled

# Register assets for Ember v5.12.0
register_asset "stylesheets/panda-plugin.scss"

module ::PandaPluginModule
  PLUGIN_NAME = "discourse-panda-plugin"
end

require_relative "lib/panda_plugin_module/engine"

after_initialize do
  # 挂载 Engine 到 /panda 路径
  Discourse::Application.routes.append do
    mount ::PandaPluginModule::Engine, at: "/panda"
  end
end
```

**⚠️ 防止 502 错误的关键点**:
- `require_relative "lib/panda_plugin_module/engine"` 必须在 `after_initialize` 之前
- Engine 挂载必须在 `after_initialize` 块内
- 模块名 `::PandaPluginModule` 必须与文件路径匹配
- `PLUGIN_NAME` 必须在模块定义之前声明
- 不要在 `plugin.rb` 中直接定义路由，只挂载 Engine

### 2. Rails Engine 配置 (`lib/panda_plugin_module/engine.rb`)

```ruby
# frozen_string_literal: true

module ::PandaPluginModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace PandaPluginModule
    config.autoload_paths << File.join(config.root, "lib")
  end
end
```

**⚠️ 防止 502 错误的关键点**:
- 文件路径必须精确：`lib/panda_plugin_module/engine.rb`
- 模块名必须与目录名匹配：`PandaPluginModule`
- `engine_name PLUGIN_NAME` 中的 `PLUGIN_NAME` 必须在 `plugin.rb` 中定义
- `isolate_namespace` 防止命名空间冲突
- 不要添加额外的配置，保持最简

### 3. 路由配置 (`config/routes.rb`)

```ruby
# frozen_string_literal: true

PandaPluginModule::Engine.routes.draw do
  get "/" => "panda#index"
end
```

**⚠️ 防止 502 错误的关键点**:
- 路由必须在 Engine 内部定义，不能在 `plugin.rb` 中
- 控制器名 `"panda"` 对应 `PandaController`
- 只定义一个根路由 `"/"`，对应挂载点 `/panda`
- 不要添加其他路由如 `.json` 或 `/test`
- Engine 路由与 Discourse 主路由完全隔离

### 4. 后端控制器 (`app/controllers/panda_plugin_module/panda_controller.rb`)

```ruby
# frozen_string_literal: true

module ::PandaPluginModule
  class PandaController < ::ApplicationController
    requires_plugin PandaPluginModule::PLUGIN_NAME

    def index
      Rails.logger.info "🐼 Panda Controller accessed!"

      # Bootstrap the Ember app for /panda route
      render "default/empty"
    rescue => e
      Rails.logger.error "🐼 Panda Error: #{e.message}"
      render plain: "Error: #{e.message}", status: 500
    end
  end
end
```

**关键点**:
- 继承 `::ApplicationController`
- 使用 `requires_plugin` 确保插件启用
- 渲染 `"default/empty"` 来引导 Ember 应用
- 添加错误处理和日志记录

## 🎨 前端 Ember v5.12.0 实现 (使用 Glimmer Components)

### ⚠️ 重要说明：使用 Glimmer Components 而非 Widget

本插件使用现代化的 **Glimmer Components** 架构，而不是传统的 Discourse Widget 系统。这是关键的技术决策，影响整个前端实现方式。

**Glimmer Components 特征**：
- 使用 `@tracked` 装饰器进行响应式状态管理
- 使用 `@action` 装饰器处理用户交互
- 使用现代 Handlebars 语法：`{{on "click" this.action}}`
- 使用 `<LinkTo @route="...">` 现代组件语法

### 1. 路由映射 (`assets/javascripts/discourse/panda-route-map.js`)

```javascript
// Modern Ember v5+ route mapping
export default function () {
  this.route("panda", { path: "/panda" });
}
```

**关键点**：
- 文件名必须是 `panda-route-map.js`（不是 `route-map.js`）
- 使用函数导出而不是对象
- 路径必须与后端 Engine 挂载路径一致

### 2. 路由处理器 (`assets/javascripts/discourse/routes/panda.js`)

```javascript
import Route from "@ember/routing/route";

export default class PandaRoute extends Route {
  model() {
    return {
      message: "🐼 Panda Paradise",
      status: "working",
      time: new Date().toLocaleString(),
      ember_version: "v5.12.0",
      plugin_version: "0.0.1"
    };
  }
}
```

**关键点**：
- 使用 ES6 class 语法而不是 `Ember.Route.extend`
- 返回静态数据而不是 AJAX 请求（简化实现）
- 文件路径必须是 `routes/panda.js`

### 3. 控制器逻辑 (`assets/javascripts/discourse/controllers/panda.js`)

```javascript
import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class PandaController extends Controller {
  @tracked randomFact = null;

  pandaFacts = [
    "🐼 Pandas spend 14-16 hours a day eating bamboo!",
    "🎋 A panda's digestive system is actually designed for meat, but they evolved to eat bamboo.",
    "🐼 Baby pandas are about the size of a stick of butter when born!",
    "🎋 Pandas have a pseudo-thumb to help them grip bamboo.",
    "🐼 Giant pandas can live up to 20 years in the wild and 30 years in captivity.",
    "🎋 Pandas are excellent swimmers and climbers!",
    "🐼 A panda's black and white coloring helps them blend into their environment.",
    "🎋 Pandas communicate through scent marking and vocalizations."
  ];

  @action
  showRandomFact() {
    const randomIndex = Math.floor(Math.random() * this.pandaFacts.length);
    this.randomFact = this.pandaFacts[randomIndex];
  }
}
```

**关键点**：
- `@tracked` 装饰器使 `randomFact` 响应式
- `@action` 装饰器绑定方法到组件实例
- 使用 ES6 class 语法和现代 JavaScript 特性

### 4. 模板文件 (`assets/javascripts/discourse/templates/panda.hbs`)

```handlebars
<div class="panda-page">
  <div class="panda-header">
    <h1>🐼 {{model.message}}</h1>
    <p>Status: {{model.status}}</p>
  </div>
  
  <div class="panda-content">
    <div class="panda-card">
      <h2>🎋 Welcome to Panda Paradise!</h2>
      
      <button class="btn btn-primary panda-btn" {{on "click" this.showRandomFact}}>
        🐼 Show Random Fact
      </button>
      
      {{#if this.randomFact}}
        <div class="panda-fact">
          {{this.randomFact}}
        </div>
      {{/if}}
    </div>
  </div>
  
  <div class="panda-footer">
    <LinkTo @route="discovery.latest" class="btn btn-default">
      ← Back to Forum
    </LinkTo>
  </div>
</div>
```

### 5. 初始化器 (`assets/javascripts/discourse/initializers/panda-plugin.js`)

```javascript
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "panda-plugin",

  initialize() {
    console.log("🐼 Panda Plugin loaded successfully!");

    withPluginApi("1.0.0", (api) => {
      // Plugin initialization for Ember v5.12.0
      console.log("🐼 Panda Plugin API initialized");
    });
  }
};
```

**关键点**：
- 文件名必须是 `panda-plugin.js`
- 使用 `withPluginApi` 确保 API 可用
- 添加控制台日志便于调试

### 6. 样式文件 (`assets/stylesheets/panda-plugin.scss`)

**关键点**：
- 文件必须在 `plugin.rb` 中注册：`register_asset "stylesheets/panda-plugin.scss"`
- 使用现代 CSS 特性（渐变、动画、响应式）
- 类名使用 `.panda-` 前缀避免冲突

## 📋 完整文件清单

### 必需的后端文件
```
plugin.rb                                    # 主配置文件
lib/panda_plugin_module/engine.rb           # Rails Engine
config/routes.rb                            # 路由配置
config/settings.yml                         # 插件设置
app/controllers/panda_plugin_module/panda_controller.rb  # 控制器
```

### 必需的前端文件
```
assets/javascripts/discourse/panda-route-map.js           # 路由映射
assets/javascripts/discourse/routes/panda.js              # 路由处理器
assets/javascripts/discourse/controllers/panda.js         # 控制器逻辑
assets/javascripts/discourse/templates/panda.hbs          # 模板文件
assets/javascripts/discourse/initializers/panda-plugin.js # 初始化器
assets/stylesheets/panda-plugin.scss                      # 样式文件
```

### 文档文件
```
README.md                                    # 用户文档
TECHNICAL_GUIDE.md                          # 技术文档
```

## � 502 错误专项排查

### 502 错误的常见原因和解决方案

**1. Engine 文件路径错误**
```
❌ 错误：lib/engine.rb
❌ 错误：lib/panda_plugin/engine.rb
✅ 正确：lib/panda_plugin_module/engine.rb
```

**2. 模块命名不匹配**
```ruby
❌ 错误：module PandaPlugin
✅ 正确：module ::PandaPluginModule
```

**3. require_relative 路径错误**
```ruby
❌ 错误：require_relative "lib/engine"
✅ 正确：require_relative "lib/panda_plugin_module/engine"
```

**4. 控制器命名空间错误**
```ruby
❌ 错误：class PandaController < ApplicationController
✅ 正确：module ::PandaPluginModule
           class PandaController < ::ApplicationController
```

**5. Engine 挂载位置错误**
```ruby
❌ 错误：在 plugin.rb 顶层挂载
✅ 正确：在 after_initialize 块内挂载
```

### 502 错误调试步骤

1. **检查 Discourse 日志**
```bash
tail -f /var/discourse/shared/standalone/log/rails/production.log
```

2. **验证文件存在**
```bash
ls -la plugins/discourse-panda-plugin/lib/panda_plugin_module/engine.rb
```

3. **检查语法错误**
```bash
ruby -c plugin.rb
ruby -c lib/panda_plugin_module/engine.rb
```

4. **验证模块加载**
在 `plugin.rb` 中添加调试：
```ruby
Rails.logger.info "🐼 Loading PandaPluginModule"
require_relative "lib/panda_plugin_module/engine"
Rails.logger.info "🐼 Engine loaded successfully"
```

## �🚫 失败的尝试和教训

### 1. 直接路由注册 (❌ 失败)

```ruby
# 这种方式不工作
Discourse::Application.routes.append do
  get '/panda' => 'panda#index'
end
```

**问题**: 控制器无法正确加载，路由无法找到对应的控制器。

### 2. 错误的控制器继承 (❌ 失败)

```ruby
# 错误的继承方式
class PandaController < ActionController::Base
```

**问题**: 缺少 Discourse 的安全检查和上下文，导致渲染失败。

### 3. 复杂的 Rails Engine 配置 (❌ 过度复杂)

最初尝试了过于复杂的 Engine 配置，包括多个路由和不必要的功能，导致调试困难。

## ✅ 成功的关键因素

### 1. 正确的架构选择
- **Rails Engine**: 提供了完整的 MVC 架构支持
- **命名空间隔离**: 避免与 Discourse 核心代码冲突
- **模块化设计**: 便于维护和扩展

### 2. 现代化的 Ember 实现
- **ES6+ 语法**: 使用 class 和装饰器
- **响应式状态管理**: 使用 `@tracked` 装饰器
- **现代模板语法**: 使用 `{{on}}` 和 `<LinkTo>`

### 3. 简洁的设计原则
- **单一职责**: 每个文件只负责一个功能
- **最小化配置**: 只保留必要的配置和路由
- **清晰的错误处理**: 完善的日志记录和错误处理

## 🔍 调试技巧

### 1. 日志记录
```ruby
Rails.logger.info "🐼 Panda Controller accessed!"
```

### 2. 浏览器控制台
```javascript
console.log("🐼 Panda Plugin loaded successfully!");
```

### 3. 路由检查
访问 `/rails/info/routes` 查看所有注册的路由。

## 🎯 最佳实践

1. **使用 Rails Engine** 而不是直接路由注册
2. **正确继承 ApplicationController** 获得完整的 Discourse 上下文
3. **使用现代 Ember 语法** 确保与最新版本兼容
4. **添加完善的错误处理** 便于调试和维护
5. **保持代码简洁** 只实现必要的功能

## 🚀 部署检查清单

### 文件结构检查
- [ ] `plugin.rb` 存在且配置正确
- [ ] `lib/panda_plugin_module/engine.rb` 存在
- [ ] `config/routes.rb` 存在且只有一个路由
- [ ] `config/settings.yml` 存在
- [ ] `app/controllers/panda_plugin_module/panda_controller.rb` 存在
- [ ] 所有前端文件都在正确位置

### 代码检查
- [ ] 控制器继承 `::ApplicationController`
- [ ] 使用 `requires_plugin PandaPluginModule::PLUGIN_NAME`
- [ ] 路由映射文件名为 `panda-route-map.js`
- [ ] 使用 Glimmer Components 语法（`@tracked`, `@action`）
- [ ] 模板使用现代语法（`{{on "click"}}`, `<LinkTo>`）

### 部署步骤
- [ ] 重启 Discourse 服务器
- [ ] 在管理员面板启用插件
- [ ] 检查浏览器控制台是否有错误
- [ ] 访问 `/panda` 测试功能

### 调试检查
- [ ] 浏览器控制台显示 "🐼 Panda Plugin loaded successfully!"
- [ ] Discourse 日志显示 "🐼 Panda Controller accessed!"
- [ ] 页面正确渲染，无 404 错误
- [ ] 交互功能正常工作

## 🔍 常见问题排查

### 1. 404 错误
- 检查 Rails Engine 是否正确挂载
- 确认路由映射文件存在且语法正确
- 验证控制器路径和命名空间

### 2. 页面空白
- 检查浏览器控制台错误
- 确认模板文件存在且语法正确
- 验证控制器和路由是否正确连接

### 3. 交互功能不工作
- 确认使用 `@tracked` 和 `@action` 装饰器
- 检查模板中的事件绑定语法
- 验证控制器方法是否正确定义

## 🤖 AI 快速实现指南

### 第一步：创建最小可用版本（避免 502）

**严格按此顺序创建文件，每个文件创建后立即测试**：

1. **创建 `config/settings.yml`**
```yaml
panda_plugin:
  panda_plugin_enabled:
    default: true
    client: true
```

2. **创建 `lib/panda_plugin_module/engine.rb`**
```ruby
# frozen_string_literal: true
module ::PandaPluginModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace PandaPluginModule
  end
end
```

3. **创建 `config/routes.rb`**
```ruby
# frozen_string_literal: true
PandaPluginModule::Engine.routes.draw do
  get "/" => "panda#index"
end
```

4. **创建 `app/controllers/panda_plugin_module/panda_controller.rb`**
```ruby
# frozen_string_literal: true
module ::PandaPluginModule
  class PandaController < ::ApplicationController
    requires_plugin PandaPluginModule::PLUGIN_NAME
    def index
      render plain: "🐼 Working!"
    end
  end
end
```

5. **创建 `plugin.rb`**
```ruby
# frozen_string_literal: true
# name: discourse-panda-plugin
# about: A Panda-themed plugin
# version: 0.0.1
# authors: Panda_CC
# required_version: 2.7.0

enabled_site_setting :panda_plugin_enabled

module ::PandaPluginModule
  PLUGIN_NAME = "discourse-panda-plugin"
end

require_relative "lib/panda_plugin_module/engine"

after_initialize do
  Discourse::Application.routes.append do
    mount ::PandaPluginModule::Engine, at: "/panda"
  end
end
```

### 第二步：测试基础功能

1. 重启 Discourse
2. 访问 `/panda` 应该显示 "🐼 Working!"
3. 如果出现 502，检查上述文件路径和命名

### 第三步：添加 Ember 前端（仅在基础版本工作后）

**只有在 `/panda` 返回 "🐼 Working!" 后才继续**

### 关键避错要点

- **文件路径必须精确匹配**
- **模块名必须一致**：`PandaPluginModule`
- **先测试最小版本，再添加功能**
- **每次只改一个文件，立即测试**

---

通过以上的技术实现，最终成功创建了一个完全可用的 `/panda` 路由，提供了完整的 Ember 单页应用体验。关键在于正确使用 Rails Engine 架构、现代化的 Ember v5.12.0 实现，以及 Glimmer Components 渲染系统。

## 📦 数据库迁移（稳定方案·简版）

为兼容不同 Discourse/ActiveRecord 版本并避免重复执行报错，采用如下规范：
- 使用较早时间戳文件，例如：db/migrate/20240101000000_create_xxx.rb
- 迁移基类建议 ActiveRecord::Migration[6.0]（兼容面更广）
- 幂等创建：table_exists? / index_exists? 检查，避免重复建表/索引
- 唯一索引显式命名，便于跨环境排错
- 如存在较新时间戳的同名迁移，保留为空注释文件或重命名类，避免类名冲突
- 业务侧日期判断用 Time.zone.today/Time.zone.yesterday，避免跨时区误判

示例：独立签到表（含唯一索引与查询索引）
```ruby
# db/migrate/20240101000000_create_jifen_signins.rb
# frozen_string_literal: true

class CreateJifenSignins < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:jifen_signins)
      create_table :jifen_signins do |t|
        t.integer  :user_id,      null: false
        t.date     :date,         null: false
        t.datetime :signed_at,    null: false
        t.boolean  :makeup,       null: false, default: false
        t.integer  :points,       null: false, default: 0
        t.integer  :streak_count, null: false, default: 1
        t.timestamps null: false
      end
    end

    unless index_exists?(:jifen_signins, [:user_id, :date], name: "idx_jifen_signins_uid_date")
      add_index :jifen_signins, [:user_id, :date], unique: true, name: "idx_jifen_signins_uid_date"
    end

    unless index_exists?(:jifen_signins, [:user_id, :created_at], name: "idx_jifen_signins_uid_created")
      add_index :jifen_signins, [:user_id, :created_at], name: "idx_jifen_signins_uid_created"
    end
  end

  def down
    drop_table :jifen_signins if table_exists?(:jifen_signins)
  end
end
