module Spree
  LineItem.class_eval do
    has_many :ad_hoc_option_values_line_items, :dependent => :destroy
    has_many :ad_hoc_option_values, :through => :ad_hoc_option_values_line_items
    has_many :product_customizations, :dependent => :destroy

    def options_text
      str = Array.new
      unless self.ad_hoc_option_values.empty?

        #TODO: group multi-select options (e.g. toppings)
        str << self.ad_hoc_option_values.each { |pov|
          "#{pov.option_value.option_type.presentation} = #{pov.option_value.presentation}"
        }.join(',')
      end # unless empty?

      unless self.product_customizations.empty?
        self.product_customizations.each do |customization|
          price_adjustment = (customization.price == 0) ? "" : " (#{Spree::Money.new(customization.price).to_s})"
          str << "#{customization.product_customization_type.presentation}#{price_adjustment}"
          customization.customized_product_options.each do |option|
            next if option.empty?

            if option.customization_image?
              str << "#{option.customizable_product_option.presentation} = #{File.basename option.customization_image.url}"
            else
              str << "#{option.customizable_product_option.presentation} = #{option.value}"
            end
          end # each option
        end # each customization
      end # unless empty?

      str.join('\n')
    end

    def cost_price
      (variant.cost_price || 0) + ad_hoc_option_values.map(&:cost_price).inject(0, :+)
    end

    def cost_money
      Spree::Money.new(cost_price, :currency => currency)
    end


    def update_price
      # this was before
      #self.price = variant.price_including_vat_for(tax_zone: tax_zone)

      # we had to override this methode because price wasn't updated for variants on sale
      # we didn't included tax_zone

      offset_price   = self.ad_hoc_option_values.map(&:price_modifier).compact.sum + self.product_customizations.map {|pc| pc.price(variant)}.sum
      self.adjustment_total = offset_price
      if currency
        self.currency = currency unless currency.nil?
        self.price    = variant.price_in(currency).amount + offset_price
      else
        self.price    = variant.price + offset_price
      end


    end
  end
end
