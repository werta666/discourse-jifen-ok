# frozen_string_literal: true

require "json"

module ::MyPluginModule
  module JifenService
    module_function

    def rewards_map
      raw = SiteSetting.jifen_consecutive_rewards_json.presence || "{}"
      JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end

    def base_points
      SiteSetting.jifen_base_points_per_signin.to_i
    end

    def signed_today?(user_id)
      MyPluginModule::JifenSignin.exists?(user_id: user_id, date: Time.zone.today)
    end

    def last_signin(user_id)
      MyPluginModule::JifenSignin.where(user_id: user_id).order(date: :desc).first
    end

    def total_points(user_id)
      MyPluginModule::JifenSignin.where(user_id: user_id).sum(:points)
    end

    def today_points(user_id)
      MyPluginModule::JifenSignin.where(user_id: user_id, date: Time.zone.today).sum(:points)
    end

    # 用户自定义字段：已消费积分与补签卡数量
    def spent_points(user)
      (user.custom_fields["jifen_spent"].presence || 0).to_i
    end

    def makeup_cards(user)
      (user.custom_fields["jifen_makeup_cards"].presence || 0).to_i
    end

    def available_total_points(user)
      total_points(user.id) - spent_points(user)
    end

    # 购买补签卡：扣减可用积分、增加补签卡数量，并返回最新概览
    def purchase_makeup_card!(user)
      price = SiteSetting.jifen_makeup_card_price.to_i
      raise StandardError, "积分不足" if available_total_points(user) < price

      user.custom_fields["jifen_makeup_cards"] = makeup_cards(user) + 1
      user.custom_fields["jifen_spent"] = spent_points(user) + price
      user.save_custom_fields(true)

      summary_for(user)
    end

    # 手动调整积分（管理员）：delta>0 增加可用积分，delta<0 减少可用积分
    # 通过调整 jifen_spent 实现，并写入后台操作日志
    def adjust_points!(acting_user, target_user, delta)
      d = delta.to_i
      raise StandardError, "调整值不能为 0" if d == 0

      before_spent = spent_points(target_user)
      before_avail = available_total_points(target_user)

      new_spent = before_spent - d
      total = total_points(target_user.id)

      # 约束：可用积分不为负 => new_spent <= total；且 new_spent >= 0
      new_spent = 0 if new_spent < 0
      new_spent = total if new_spent > total

      target_user.custom_fields["jifen_spent"] = new_spent
      target_user.save_custom_fields(true)

      begin
        StaffActionLogger.new(acting_user).log_custom(
          "jifen_adjust_points",
          target_user_id: target_user.id,
          target_username: target_user.username,
          delta: d,
          before_spent: before_spent,
          after_spent: new_spent,
          before_available: before_avail,
          after_available: available_total_points(target_user)
        )
      rescue StandardError
        # 忽略日志异常
      end

      summary_for(target_user)
    end

    # 重置指定用户“今日签到”状态（删除今日记录），允许重新签到
    def reset_today!(acting_user, target_user)
      removed = MyPluginModule::JifenSignin.where(user_id: target_user.id, date: Time.zone.today).delete_all

      begin
        StaffActionLogger.new(acting_user).log_custom(
          "jifen_reset_today",
          target_user_id: target_user.id,
          target_username: target_user.username,
          removed: removed
        )
      rescue StandardError
        # 忽略日志异常
      end

      removed
    end

    # 用于 summary 展示的连续天数（若今天没签，取到昨日为止的连续天数）
    def compute_streak_on_summary(user_id)
      last = last_signin(user_id)
      return 0 unless last
      if last.date == Time.zone.today
        last.streak_count
      elsif last.date == Time.zone.yesterday
        last.streak_count
      else
        0
      end
    end

    def next_reward_info(streak, rewards)
      return nil if rewards.blank?
      entries = rewards.map { |k, v| [k.to_i, v.to_i] }.sort_by(&:first)
      entries.each do |days, pts|
        if days > streak
          return { days: days, points: pts, remain: days - streak }
        end
      end
      nil
    end

    def recent_records_for(user_id, days: 7)
      start_date = Time.zone.today - (days - 1)
      MyPluginModule::JifenSignin
        .where(user_id: user_id)
        .where("date >= ?", start_date)
        .order(date: :desc)
        .limit(days)
        .map do |r|
          {
            date: r.date.to_s,
            signed_at: r.signed_at&.iso8601,
            makeup: r.makeup,
            points: r.points,
            streak_count: r.streak_count
          }
        end
    end

    def summary_for(user)
      uid = user.id
      signed = signed_today?(uid)
      streak = compute_streak_on_summary(uid)
      total_available = available_total_points(user)
      today = today_points(uid)
      rewards = rewards_map
      next_rw = next_reward_info(streak, rewards)
      install_date = MyPluginModule::JifenSignin.order(:date).limit(1).pluck(:date).first || Time.zone.today
      recent = recent_records_for(uid, days: 7)

      data = {
        user_logged_in: true,
        signed: signed,
        consecutive_days: streak,
        total_score: total_available,
        today_score: today,
        points: base_points,
        makeup_cards: makeup_cards(user),
        makeup_card_price: SiteSetting.jifen_makeup_card_price.to_i,
        install_date: install_date.to_s,
        rewards: rewards,
        recent_records: recent
      }
      data[:next_reward] = next_rw if next_rw
      data
    end

    def signin!(user)
      uid = user.id
      return summary_for(user) if signed_today?(uid)

      rewards = rewards_map
      ActiveRecord::Base.transaction do
        prev = MyPluginModule::JifenSignin.where(user_id: uid).order(date: :desc).lock(true).first
        if prev && prev.date == Time.zone.today
          raise ActiveRecord::RecordNotUnique
        end

        new_streak =
          if prev && prev.date == Time.zone.yesterday
            prev.streak_count + 1
          else
            1
          end

        reward_points = rewards[new_streak.to_s].to_i
        pts = base_points + reward_points

        MyPluginModule::JifenSignin.create!(
          user_id: uid,
          date: Time.zone.today,
          signed_at: Time.zone.now,
          makeup: false,
          points: pts,
          streak_count: new_streak
        )
      end

      summary_for(user)
    end

    # 系统启用日期（用于限制补签下限）：取最早一条签到记录的日期；若无记录，则为今日
    def install_date
      MyPluginModule::JifenSignin.order(:date).limit(1).pluck(:date).first || Time.zone.today
    end

    # 补签指定日期：仅允许系统启用日（含）之后、且不晚于今日的日期；需要消耗 1 张补签卡
    # 返回最新 summary（用于前端刷新）
    def makeup_on_date!(user, date_str)
      raise StandardError, "参数错误" if date_str.blank?
      date = begin
        Date.parse(date_str)
      rescue ArgumentError
        nil
      end
      raise StandardError, "日期格式不正确" unless date

      today = Time.zone.today
      inst = install_date
      raise StandardError, "不能补签未来日期" if date > today
      raise StandardError, "不能补签启用日期之前（#{inst}）" if date < inst

      if MyPluginModule::JifenSignin.exists?(user_id: user.id, date: date)
        raise StandardError, "该日期已存在签到记录"
      end

      cards = makeup_cards(user)
      raise StandardError, "补签卡不足" if cards <= 0

      # 补签得分 = 基础积分 * 比例（0-100%），默认 100%
      ratio = SiteSetting.respond_to?(:jifen_makeup_ratio_percent) ? SiteSetting.jifen_makeup_ratio_percent.to_i : 100
      ratio = 0 if ratio < 0
      ratio = 100 if ratio > 100
      pts = (base_points * ratio / 100)

      ActiveRecord::Base.transaction do
        # 扣 1 张补签卡
        user.custom_fields["jifen_makeup_cards"] = cards - 1
        user.save_custom_fields(true)

        MyPluginModule::JifenSignin.create!(
          user_id: user.id,
          date: date,
          signed_at: Time.zone.now,
          makeup: true,
          points: pts,
          streak_count: 1
        )
      end

      summary_for(user)
    end
  end
end
