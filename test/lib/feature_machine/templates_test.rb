require "test_helper"

# Every template the engine ships must compile on its own: no host model, no
# host record, nothing loaded from the database. A template that only works
# once the first host's fixtures exist is a template the next host can't render.
class FeatureMachine::TemplatesTest < ActiveSupport::TestCase
  ENGINE_TEMPLATES = Dir[FeatureMachine::Engine.root.join("app/views/feature_machine/**/*.erb")] +
    [ FeatureMachine::Engine.root.join("app/views/layouts/feature_machine.html.erb").to_s ]

  test "the engine ships templates for both public and admin surfaces" do
    relative = ENGINE_TEMPLATES.map { |path| path.delete_prefix("#{FeatureMachine::Engine.root}/") }
    assert_includes relative, "app/views/layouts/feature_machine.html.erb"
    assert relative.any? { |path| path.start_with?("app/views/feature_machine/feature_requests/") }, relative.inspect
    assert relative.any? { |path| path.start_with?("app/views/feature_machine/admin/work_items/") }, relative.inspect
  end

  test "every engine template compiles without touching a host model" do
    ENGINE_TEMPLATES.each do |path|
      source = File.read(path)
      ruby = ActionView::Template::Handlers::ERB::Erubi.new(source).src
      assert RubyVM::InstructionSequence.compile("def _fm_template; #{ruby}\nend", path)
    rescue SyntaxError => e
      flunk "#{path} does not compile: #{e.message}"
    end
  end

  test "the standalone layout asks nothing of the host" do
    source = File.read(FeatureMachine::Engine.root.join("app/views/layouts/feature_machine.html.erb"))
    assert_no_match(/stylesheet_link_tag|javascript_importmap_tags|javascript_include_tag/, source)
    assert_no_match(/\b(Poetry|Article|User)\b/, source)
    assert_match(/FeatureMachine\.config\.product_name/, source)
  end

  # Routes the engine's surface owns even though the host draws them outside
  # the feature_machine controller namespace. Every other named host route is
  # off-limits: a template that links to it breaks in the next host.
  ENGINE_SURFACE_ROUTES = %w[roadmap bug_reports new_bug_report admin_triage admin_root].freeze

  test "no engine template names a host identifier or host route helper" do
    host_helpers = Rails.application.routes.named_routes.to_h.filter_map do |name, route|
      next if ENGINE_SURFACE_ROUTES.include?(name.to_s)
      next if route.defaults[:controller].to_s.delete_prefix("/").start_with?("feature_machine/")
      name.to_s
    end
    helper_call = /(?<![.\w])(#{host_helpers.map { |h| Regexp.escape(h) }.join("|")})_(path|url)\b/

    ENGINE_TEMPLATES.each do |path|
      source = File.read(path)
      assert_no_match(/\bpoetry_\w+/, source, "#{path} names a host identifier")
      assert_no_match(/\bmain_app\./, source, "#{path} reaches into main_app")
      assert_no_match(helper_call, source, "#{path} calls a host route helper")
    end
  end
end
