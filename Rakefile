require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.framework = nil
  t.libs << "test"
  t.libs << "lib"
  t.warning = false
  t.test_globs = ["test/**/*_test.rb"]
end

task { :default => :test }
