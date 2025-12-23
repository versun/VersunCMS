module StaticGeneration
  class Renderer
    def render_static_partial(partial, assigns = {})
      original_annotate = ActionView::Base.annotate_rendered_view_with_filenames
      ActionView::Base.annotate_rendered_view_with_filenames = false

      begin
        controller = StaticRenderController.new
        assigns.each { |key, value| controller.instance_variable_set("@#{key}", value) }

        controller.instance_variable_set(:@static_partial, partial)
        controller.instance_variable_set(:@static_locals, assigns)
        controller.render_to_string(
          template: "static_generator/render",
          layout: "static"
        )
      ensure
        ActionView::Base.annotate_rendered_view_with_filenames = original_annotate
      end
    end

    def render_rss_template(template, assigns = {})
      controller = StaticRenderController.new
      assigns.each { |key, value| controller.instance_variable_set("@#{key}", value) }

      controller.render_to_string(
        template: template,
        formats: [ :rss ],
        layout: false
      )
    end

    def render_xml_template(template, assigns = {})
      controller = StaticRenderController.new
      assigns.each { |key, value| controller.instance_variable_set("@#{key}", value) }

      controller.render_to_string(
        template: template,
        formats: [ :xml ],
        layout: false
      )
    end
  end
end
