# frozen_string_literal: true

# name: discourse-jifen-ok
# about: 高度定制化的积分系统插件（每日签到与连续签到奖励）
# version: 0.1.0
# authors: Pandacc
# url: https://github.com/werta666/discourse-jifen-ok
# required_version: 2.7.0

# 站点设置开关（仅中文）
enabled_site_setting :jifen_enabled

# 注册样式表（qd 页面样式）
register_asset "stylesheets/qd-plugin.scss"
register_asset "stylesheets/qd-board.scss"
register_asset "stylesheets/qd-board-neo.scss"

# 插件命名空间（沿用现有 MyPluginModule 以避免大规模重命名）
module ::MyPluginModule
  PLUGIN_NAME = "discourse-jifen-ok"
end

# 加载 Rails Engine
require_relative "lib/my_plugin_module/engine"

# 在 Rails 初始化完成后挂载 Engine，路径为 /qd
after_initialize do
  Discourse::Application.routes.append do
    mount ::MyPluginModule::Engine, at: "/qd"
  end

  # 注册后台任务
  require_relative "app/jobs/my_plugin_module/update_leaderboard_job"
  
  # 监听站点设置变化，动态调整任务间隔
  DiscourseEvent.on(:site_setting_changed) do |name, old_value, new_value|
    if name == :jifen_leaderboard_update_minutes && old_value != new_value
      MyPluginModule::UpdateLeaderboardJob.update_schedule!
    end
  end
  
  # 插件启用时初始化排行榜缓存
  if SiteSetting.jifen_enabled
    Jobs.enqueue(:update_leaderboard, {})
  end
end
