module OverlayUtil
  OVERLAY_IDS = ['project-overview', 'dataset-results', 'dataset-details', 'master-overlay-parent', 'granule-search']

  def self.has_visible_overlay_content?(page, id)
    datasets_overlay_visible?(page) && current_overlay_id(page).include?(id)
  end

  def self.datasets_overlay_visible?(page)
    page.has_css?('#datasets-overlay:not(.is-hidden)')
  end

  def self.current_overlay_id(page)
    main_id = page.evaluate_script """
      var $content = $('.master-overlay-main-content');
      var level = parseInt($content.attr('data-level'), 10);
      $content.children(':visible')[level].id
    """
    if page.has_css?('#datasets-overlay:not(.is-master-overlay-secondary-hidden)')
      secondary_id = page.evaluate_script """
        var $content = $('.master-overlay-secondary-content');
        var level = parseInt($content.attr('data-level'), 10);
        $content.children(':visible')[level].id
      """
    else
      secondary_id = nil
    end
    [main_id, secondary_id]
  end

  def self.define_overlay_matchers
    OVERLAY_IDS.each { |id| define_visible_overlay_matcher_for_id(id) }
  end

  private

  def self.expect_visible_overlay_content!(page, id, should)
    page.current_scope.synchronize do
      if has_visible_overlay_content?(page, id) == should
        true
      else
        raise Capybara::ElementNotFound.new("Unable to find #{id} in view")
      end
    end
  end

  def self.define_visible_overlay_matcher_for_id(id)
    RSpec::Matchers.define "have_visible_#{id.underscore}" do
      match_for_should     { |page| OverlayUtil::expect_visible_overlay_content!(page, id, true)  }
      match_for_should_not { |page| OverlayUtil::expect_visible_overlay_content!(page, id, false) }
    end
  end
end


OverlayUtil::define_overlay_matchers()