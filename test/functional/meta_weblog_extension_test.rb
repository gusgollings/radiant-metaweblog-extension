require File.dirname(__FILE__) + '/../test_helper'

class MetaWeblogExtensionTest < Test::Unit::TestCase
  
  # Replace this with your real tests.
  def test_this_extension
    flunk
  end
  
  def test_initialization
    assert_equal File.join(File.expand_path(RAILS_ROOT), 'vendor', 'extensions', 'meta_weblog'), MetaWeblogExtension.root
    assert_equal 'Meta Weblog', MetaWeblogExtension.extension_name
  end
  
end
