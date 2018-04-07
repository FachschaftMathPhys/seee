# encoding: utf-8

module TermsHelper
  def datepicker_input form, field
      content_tag :span, :data => {:provide => 'datepicker', 'date-format' => 'yyyy-mm-dd', 'date-autoclose' => 'true'} do
        form.text_field field, class: 'form-control', placeholder: 'YYYY-MM-DD'
      end
    end
end
