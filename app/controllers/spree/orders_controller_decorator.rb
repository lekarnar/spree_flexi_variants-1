module Spree
  OrdersController.class_eval do

    include ProductCustomizations
    include AdHocUtils

    # the inbound variant is determined either from products[pid]=vid or variants[master_vid], depending on whether or not the product has_variants, or not
    #
    # Currently, we are assuming the inbound ad_hoc_option_values and customizations apply to the entire inbound product/variant 'group', as more surgery
    # needs to occur in the cart partial for this to be done 'right'
    #
    # Adds a new item to the order (creating a new order if none already exists)
    def populate
      order    = current_order(create_order_if_necessary: true)
      variant  = Spree::Variant.find(params[:variant_id])
      quantity = params[:quantity].to_i
      options  = params[:options] || {}
      limit_reached = false
      # 2,147,483,647 is crazy. See issue #2695.
      if quantity.between?(1, 2_147_483_647)
        begin
          item_count_before = order.contents.order.item_count
          order.contents.add(variant, quantity, options, ad_hoc_option_value_ids, product_customizations)
          item_count_after = order.contents.order.item_count
          limit_reached = true if limit_reached?(variant, quantity, item_count_before, item_count_after)

        rescue ActiveRecord::RecordInvalid => e
          error = e.record.errors.full_messages.join(", ")
        end
      else
        error = Spree.t(:please_enter_reasonable_quantity)
      end

      if error
        flash[:error] = error
        redirect_back_or_default(spree.root_path)
      else
        redirect_back
        if limit_reached
          flash[:error] = "#{variant.product.name} #{variant.product.limit1 ? Spree.t(:limit_one_reached) : Spree.t(:limit_three_reached)}"
        else
          flash[:success] = Spree.t("events.spree.cart.add")
        end
      end
    end

    def limit_reached?(variant, quantity, item_count_before, item_count_after)
      (variant.product.limit1 && quantity > 1) || (variant.product.limit3 && quantity > 3) || (item_count_before == item_count_after)
    end

    def redirect_back
      redirect_to request.env['HTTP_REFERER'] || spree.root_path
    end
  end
end
