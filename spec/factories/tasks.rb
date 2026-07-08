FactoryBot.define do
  factory :task do
    content { 'Buy milk' }
    log_year { 2026 }
    log_month { 7 }
  end
end
