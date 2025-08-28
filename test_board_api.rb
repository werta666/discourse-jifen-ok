# 测试排行榜 API 的简单脚本
# 在 Rails console 中运行：load 'test_board_api.rb'

puts "测试排行榜 API..."

begin
  # 测试 JifenService.get_leaderboard 方法
  result = MyPluginModule::JifenService.get_leaderboard(limit: 5)
  puts "✅ 排行榜数据获取成功:"
  puts "  排行榜条目数: #{result[:leaderboard].size}"
  puts "  更新时间: #{result[:updated_at]}"
  
  result[:leaderboard].each do |item|
    puts "  第#{item[:rank]}名: #{item[:username]} (#{item[:points]}分)"
  end
  
rescue => e
  puts "❌ 排行榜数据获取失败: #{e.message}"
  puts "错误详情: #{e.backtrace.first(3).join("\n")}"
end

puts "\n测试完成。"