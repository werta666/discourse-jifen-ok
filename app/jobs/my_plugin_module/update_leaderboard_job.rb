# frozen_string_literal: true

module ::MyPluginModule
  class UpdateLeaderboardJob < ::Jobs::Scheduled
    every 5.minutes  # 默认5分钟，避免启动时读取设置失败

    def execute(args)
      return unless SiteSetting.jifen_enabled

      begin
        # 计算排行榜数据（前10名，比显示的5名多一些作为缓存）
        leaderboard_data = MyPluginModule::JifenService.calculate_leaderboard_uncached(limit: 10)
        
        # 存入缓存，设置较长的过期时间（防止任务失败时缓存丢失）
        cache_key = "jifen_leaderboard_cache"
        Rails.cache.write(cache_key, leaderboard_data, expires_in: 2.hours)
        
        Rails.logger.info "[积分插件] 排行榜缓存已更新，共 #{leaderboard_data[:leaderboard].size} 名用户"
        
      rescue => e
        Rails.logger.error "[积分插件] 更新排行榜缓存失败: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # 获取更新间隔（从站点设置读取，默认5分钟）
    def self.update_interval
      return 5.minutes unless defined?(SiteSetting)
      SiteSetting.jifen_leaderboard_update_minutes&.minutes || 5.minutes
    end
  end
end