module Spree
  OrderContents.class_eval do
    # Get current line item for variant if exists
    # Add variant qty to line_item

    def initialize(order)
        @order = order
        @currency = order.currency if order.currency
    end

    def add(variant, quantity = 1, options = {}, ad_hoc_option_value_ids = [], product_customizations = [])
      timestamp = Time.now
      line_item = add_to_line_item(variant, quantity, options, ad_hoc_option_value_ids, product_customizations)
      options[:line_item_created] = true if timestamp <= line_item.created_at
      after_add_or_remove(line_item, options)
    end

    private
      def add_to_line_item(variant, quantity, options = {}, ad_hoc_option_value_ids = [], product_customizations = [])
        line_item = grab_line_item_by_variant(variant, false, options, ad_hoc_option_value_ids, product_customizations)

        if line_item #&& part_variants_match?(line_item, variant, quantity, options)
          if line_item.variant.product.limit1 && line_item.quantity >= 1
            line_item.quantity = 1
          elsif line_item.variant.product.limit3 && line_item.quantity >= 3
            line_item.quantity = 3
          else
            line_item.quantity += quantity.to_i
          end

          line_item.currency = currency unless currency.nil?
        else

          opts = ActionController::Parameters.new(options.to_h).
            permit(PermittedAttributes.line_item_attributes).to_h.
            merge( { currency: order.currency } )
            if variant.product.limit1 && quantity > 1
              quantity = 1
            end
            if variant.product.limit3 && quantity > 3
              quantity = 3
            end
            line_item = order.line_items.new(quantity: quantity,
                                             variant: variant,
                                             options: opts)

          line_item.product_customizations = product_customizations
          product_customizations.each {|pc| pc.line_item = line_item}
          product_customizations.map(&:save)
          povs=[]
          ad_hoc_option_value_ids.each do |cid|
            povs << AdHocOptionValue.find(cid)
          end
          line_item.ad_hoc_option_values = povs

          offset_price   = povs.map(&:price_modifier).compact.sum + product_customizations.map {|pc| pc.price(variant)}.sum
          line_item.adjustment_total = offset_price
          if currency
            line_item.currency = currency unless currency.nil?
            line_item.price    = variant.price_in(currency).amount + offset_price
          else
            line_item.price    = variant.price + offset_price
          end
        end
        line_item.target_shipment = options[:shipment] if options.has_key? :shipment
        line_item.save!
        line_item
      end

      def grab_line_item_by_variant(variant, raise_error = false, options = {}, ad_hoc_option_value_ids, product_customizations)
        line_item = order.find_line_item_by_variant(variant, options, ad_hoc_option_value_ids, product_customizations)

        if !line_item.present? && raise_error
          raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
        end

        line_item
    end
  end
end
