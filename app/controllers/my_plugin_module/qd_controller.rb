# frozen_string_literal: true

module ::MyPluginModule
  class QdController < ::ApplicationController
    requires_plugin MyPluginModule::PLUGIN_NAME

    before_action :ensure_logged_in, except: [:index]

    # Ember 引导页
    def index
      render "default/empty"
    end

    # 概览数据（/qd 页面所需）
    def summary
      render_json_dump MyPluginModule::JifenService.summary_for(current_user)
    end

    # 签到记录：仅返回最近 7 天（按日期倒序）
    def records
      start_date = Time.zone.today - 6
      recs = MyPluginModule::JifenSignin
        .where(user_id: current_user.id)
        .where("date >= ?", start_date)
        .order(date: :desc)

      render_json_dump(
        records: recs.map do |r|
          {
            date: r.date.to_s,
            signed_at: r.signed_at&.iso8601,
            makeup: r.makeup,
            points: r.points,
            streak_count: r.streak_count
          }
        end
      )
    end

    # 今日签到
    def signin
      render_json_dump MyPluginModule::JifenService.signin!(current_user)
    rescue ActiveRecord::RecordNotUnique
      render_json_error("今日已签到", status: 409)
    rescue => e
      render_json_error(e.message)
    end

    # 补签：仅允许系统启用日（含）之后、且不晚于今日的日期；消耗 1 张补签卡
    def makeup
      summary = MyPluginModule::JifenService.makeup_on_date!(current_user, params[:date])
      render_json_dump(summary)
    rescue StandardError => e
      render_json_error(e.message)
    end

    # 购买补签卡：扣减可用积分并增加卡数，返回最新概览
    def buy_makeup_card
      render_json_dump MyPluginModule::JifenService.purchase_makeup_card!(current_user)
    rescue StandardError => e
      render_json_error(e.message)
    end
  end
end