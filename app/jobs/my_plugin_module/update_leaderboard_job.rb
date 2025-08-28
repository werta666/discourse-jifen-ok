# frozen_string_literal: true

module ::MyPluginModule
  class UpdateLeaderboardJob < ::Jobs::Scheduled
    every 5.minutes  # 默认5分钟，启动后会动态调整

    def execute(args)
      return unless SiteSetting.jifen_enabled

      begin
        # 动态调整执行间隔
        current_interval = (SiteSetting.jifen_leaderboard_update_minutes || 5).minutes
        if self.class.every_duration != current_interval
          self.class.every current_interval
          Rails.logger.info "[积分插件] 排行榜更新间隔已调整为 #{SiteSetting.jifen_leaderboard_update_minutes} 分钟"
        end

        # 计算排行榜数据（根据配置的显示数量决定缓存数量）
        display_count = SiteSetting.jifen_leaderboard_display_count || 30
        cache_limit = [display_count, 100].max # 至少缓存100名，支持大排行榜
        leaderboard_data = MyPluginModule::JifenService.calculate_leaderboard_uncached(limit: cache_limit)
        
        # 存入缓存，包含更新时间
        cache_key = "jifen_leaderboard_cache"
        cache_data = leaderboard_data.merge({
          last_updated: Time.current,
          update_interval_minutes: SiteSetting.jifen_leaderboard_update_minutes || 5
        })
        Rails.cache.write(cache_key, cache_data, expires_in: 2.hours)
        
        Rails.logger.info "[积分插件] 排行榜缓存已更新，共 #{leaderboard_data[:leaderboard].size} 名用户"
        
      rescue => e
        Rails.logger.error "[积分插件] 更新排行榜缓存失败: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # 获取当前执行间隔
    def self.every_duration
      @every_duration ||= 5.minutes
    end

    # 重写 every 方法记录间隔
    def self.every(duration)
      @every_duration = duration
      super(duration)
    end
  end
end
